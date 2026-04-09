import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';
import '../models/user_model.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';

final _googleSignIn = GoogleSignIn(
  scopes: ['email', 'profile'],
  serverClientId:
      '695528874164-uhi1sqie4d553ijuckrh0h59ikqi0uqi.apps.googleusercontent.com',
);

final _localAuth = LocalAuthentication();

class AuthState {
  final UserModel? user;
  final bool loading;
  final String? error;
  const AuthState({this.user, this.loading = false, this.error});
  bool get isAuthenticated => user != null;
  AuthState copyWith({
    UserModel? user,
    bool? loading,
    String? error,
    bool clearUser = false,
  }) => AuthState(
    user: clearUser ? null : user ?? this.user,
    loading: loading ?? this.loading,
    error: error,
  );
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _tryRestoreSession();
    return const AuthState(loading: true);
  }

  Future<void> _tryRestoreSession() async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      state = const AuthState();
      return;
    }
    try {
      final res = await dioClient.get('/auth/me');
      state = AuthState(
        user: UserModel.fromJson(res.data as Map<String, dynamic>),
      );
    } catch (_) {
      await SecureStorage.deleteToken();
      state = const AuthState();
    }
  }

  Future<bool> login(
    String email,
    String password, {
    bool rememberMe = false,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await dioClient.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      final auth = AuthResponse.fromJson(res.data as Map<String, dynamic>);
      await SecureStorage.saveToken(auth.token);
      if (rememberMe) {
        // Save / update profile in multi-profile store
        final existing = await SecureStorage.getProfile(email);
        await SecureStorage.saveProfile(
          SavedProfile(
            email: email,
            password: password,
            displayName: auth.user.displayName,
            profilePictureUrl: auth.user.profilePictureUrl,
            biometricEnabled: existing?.biometricEnabled ?? false,
          ),
        );
      }
      state = AuthState(user: auth.user);
      return true;
    } catch (e) {
      final msg = _extractError(e);
      state = AuthState(error: msg);
      return false;
    }
  }

  Future<bool> register(
    String email,
    String password,
    String displayName,
  ) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await dioClient.post(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          'displayName': displayName,
        },
      );
      final auth = AuthResponse.fromJson(res.data as Map<String, dynamic>);
      await SecureStorage.saveToken(auth.token);
      state = AuthState(user: auth.user);
      return true;
    } catch (e) {
      final msg = _extractError(e);
      state = AuthState(error: msg);
      return false;
    }
  }

  Future<void> refreshUser() async {
    try {
      final res = await dioClient.get('/auth/me');
      state = AuthState(
        user: UserModel.fromJson(res.data as Map<String, dynamic>),
      );
    } catch (_) {}
  }

  Future<void> logout({bool clearSavedCredentials = false}) async {
    await SecureStorage.deleteToken();
    if (clearSavedCredentials) {
      await SecureStorage.clearCredentials();
      await SecureStorage.setBiometricEnabled(false);
    }
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    state = const AuthState();
  }

  /// Check if biometric authentication is available on the device
  static Future<bool> canUseBiometric() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Check if biometric quick-login is ready for a specific profile
  static Future<bool> isBiometricReadyFor(String email) async {
    final profile = await SecureStorage.getProfile(email);
    return profile != null && profile.biometricEnabled;
  }

  /// Check if any saved profile has biometric enabled
  static Future<bool> isBiometricReady() async {
    return SecureStorage.hasAnyBiometricProfile();
  }

  /// Authenticate with biometric and auto-login a specific saved profile
  Future<bool> loginWithBiometric({String? email}) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to sign in to TimeCapsule',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      if (!authenticated) {
        state = state.copyWith(loading: false);
        return false;
      }

      SavedProfile? profile;
      if (email != null) {
        profile = await SecureStorage.getProfile(email);
      } else {
        // Fallback: use first profile with biometric enabled
        final profiles = await SecureStorage.getSavedProfiles();
        try {
          profile = profiles.firstWhere((p) => p.biometricEnabled);
        } catch (_) {
          profile = profiles.isNotEmpty ? profiles.first : null;
        }
      }

      if (profile == null) {
        state = AuthState(
          error: 'No saved profile. Please sign in with email and password.',
        );
        return false;
      }

      // Social-login users have empty password — use token restore instead
      if (profile.password.isEmpty) {
        debugPrint('[Biometric] Social-login user, trying session restore...');
        final token = await SecureStorage.getToken();
        if (token != null) {
          try {
            final res = await dioClient.get('/auth/me');
            state = AuthState(
              user: UserModel.fromJson(res.data as Map<String, dynamic>),
            );
            return true;
          } catch (_) {
            state = AuthState(
              error: 'Session expired. Please sign in with Google again.',
            );
            return false;
          }
        }
        state = AuthState(
          error: 'Session expired. Please sign in with Google again.',
        );
        return false;
      }

      final res = await dioClient.post(
        '/auth/login',
        data: {'email': profile.email, 'password': profile.password},
      );
      final auth = AuthResponse.fromJson(res.data as Map<String, dynamic>);
      await SecureStorage.saveToken(auth.token);
      // Update saved profile with latest user info
      await SecureStorage.saveProfile(
        profile.copyWith(
          displayName: auth.user.displayName,
          profilePictureUrl: auth.user.profilePictureUrl,
        ),
      );
      state = AuthState(user: auth.user);
      return true;
    } catch (e) {
      final msg = _extractError(e);
      state = AuthState(error: msg);
      return false;
    }
  }

  /// Enable biometric login for a specific profile.
  /// Creates a stub profile if none exists (e.g. user logged in via Google).
  Future<bool> enableBiometric({String? email}) async {
    try {
      final targetEmail = email ?? state.user?.email;
      if (targetEmail == null) return false;

      // Ensure a profile exists (may not if user logged in via Google/Facebook)
      final existing = await SecureStorage.getProfile(targetEmail);
      if (existing == null) {
        debugPrint(
          '[Biometric] No saved profile for $targetEmail — creating stub',
        );
        await SecureStorage.saveProfile(
          SavedProfile(
            email: targetEmail,
            password: '', // No password for social-login users
            displayName: state.user?.displayName ?? '',
            profilePictureUrl: state.user?.profilePictureUrl,
            biometricEnabled: false,
          ),
        );
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Enable biometric login for TimeCapsule',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      if (authenticated) {
        await SecureStorage.setBiometricForProfile(targetEmail, true);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[Biometric] enableBiometric error: $e');
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    state = state.copyWith(loading: true, error: null);
    try {
      debugPrint('[GoogleSignIn] Starting sign-in flow...');
      await _googleSignIn.signOut();
      final account = await _googleSignIn.signIn();
      if (account == null) {
        debugPrint(
          '[GoogleSignIn] account is null — user cancelled or silent failure',
        );
        state = AuthState(
          error: 'Google sign-in was cancelled. Please try again.',
        );
        return false;
      }
      debugPrint('[GoogleSignIn] Got account: ${account.email}');
      final auth = await account.authentication;
      final idToken = auth.idToken;
      final accessToken = auth.accessToken;
      debugPrint(
        '[GoogleSignIn] idToken=${idToken != null ? "present (${idToken!.length} chars)" : "null"}, accessToken=${accessToken != null ? "present" : "null"}',
      );
      final token = idToken ?? accessToken;
      if (token == null) throw Exception('No token received from Google');
      debugPrint(
        '[GoogleSignIn] Sending ${idToken != null ? "idToken" : "accessToken"} to backend...',
      );
      final res = await dioClient.post(
        '/auth/google',
        data: {'accessToken': token, 'isIdToken': idToken != null},
      );
      final authResp = AuthResponse.fromJson(res.data as Map<String, dynamic>);
      await SecureStorage.saveToken(authResp.token);
      state = AuthState(user: authResp.user);
      debugPrint('[GoogleSignIn] Login success: ${authResp.user.email}');
      return true;
    } catch (e, st) {
      debugPrint('[GoogleSignIn] ERROR: $e');
      debugPrint('[GoogleSignIn] Stack: $st');
      final msg = _extractError(e);
      state = AuthState(error: msg);
      return false;
    }
  }

  Future<bool> loginWithFacebook() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );
      if (result.status != LoginStatus.success || result.accessToken == null) {
        state = state.copyWith(loading: false);
        return false;
      }
      final res = await dioClient.post(
        '/auth/facebook',
        data: {'accessToken': result.accessToken!.tokenString},
      );
      final authResp = AuthResponse.fromJson(res.data as Map<String, dynamic>);
      await SecureStorage.saveToken(authResp.token);
      state = AuthState(user: authResp.user);
      return true;
    } catch (e) {
      state = AuthState(error: _extractError(e));
      return false;
    }
  }

  String _extractError(dynamic e) {
    // Handle DioException specifically for better release-mode diagnostics
    if (e is DioException) {
      // Try to extract backend error message from response body
      final data = e.response?.data;
      if (data is Map && data['error'] != null) return data['error'] as String;

      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          return 'Connection timed out. Server may be starting up — please try again in a moment.';
        case DioExceptionType.sendTimeout:
          return 'Request timed out while sending. Check your internet connection.';
        case DioExceptionType.receiveTimeout:
          return 'Server took too long to respond. Please try again.';
        case DioExceptionType.badCertificate:
          return 'SSL certificate error. Please update the app or try again later.';
        case DioExceptionType.connectionError:
          return 'Cannot connect to server. Check your internet connection.';
        case DioExceptionType.cancel:
          return 'Request was cancelled.';
        case DioExceptionType.badResponse:
          final statusCode = e.response?.statusCode;
          return 'Server error ($statusCode). Please try again.';
        case DioExceptionType.unknown:
          if (e.error.toString().contains('SocketException') ||
              e.error.toString().contains('Connection refused')) {
            return 'Cannot connect to server. Please try again.';
          }
          return 'Network error. Please check your connection and try again.';
      }
    }
    try {
      final data = (e as dynamic).response?.data;
      if (data is Map && data['error'] != null) return data['error'] as String;
    } catch (_) {}
    final msg = e.toString();
    if (msg.contains('PlatformException')) {
      if (msg.contains('sign_in_canceled'))
        return 'Google sign-in was cancelled';
      if (msg.contains('network_error'))
        return 'Network error. Check your internet connection.';
      if (msg.contains('ApiException: 10') || msg.contains('DEVELOPER_ERROR')) {
        return 'Google Sign-In config error (code 10). The release signing key is not registered in Google Cloud Console.';
      }
      if (msg.contains('sign_in_failed')) {
        final m = RegExp(r'ApiException:\s*(\d+)').firstMatch(msg);
        final code = m?.group(1) ?? '?';
        return 'Google sign-in failed (error $code). Check Cloud Console setup.';
      }
      final m = RegExp(
        r'PlatformException\(([^,]+),\s*(.+?)(?:,|\))',
      ).firstMatch(msg);
      if (m != null) return '${m.group(2)?.trim()}';
    }
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'Cannot connect to server. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
