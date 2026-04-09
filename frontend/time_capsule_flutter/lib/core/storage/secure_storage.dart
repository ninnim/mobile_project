import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A saved user profile for quick re-login (Facebook-style).
class SavedProfile {
  final String email;
  final String password;
  final String displayName;
  final String? profilePictureUrl;
  final bool biometricEnabled;

  const SavedProfile({
    required this.email,
    required this.password,
    required this.displayName,
    this.profilePictureUrl,
    this.biometricEnabled = false,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'displayName': displayName,
    'profilePictureUrl': profilePictureUrl,
    'biometricEnabled': biometricEnabled,
  };

  factory SavedProfile.fromJson(Map<String, dynamic> j) => SavedProfile(
    email: j['email'] as String,
    password: j['password'] as String,
    displayName: j['displayName'] as String? ?? '',
    profilePictureUrl: j['profilePictureUrl'] as String?,
    biometricEnabled: j['biometricEnabled'] as bool? ?? false,
  );

  SavedProfile copyWith({
    String? password,
    String? displayName,
    String? profilePictureUrl,
    bool? biometricEnabled,
  }) => SavedProfile(
    email: email,
    password: password ?? this.password,
    displayName: displayName ?? this.displayName,
    profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
  );
}

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _tokenKey = 'jwt_token';
  static const _profilesKey = 'saved_profiles';

  // ── JWT token ──────────────────────────────────────────────
  static Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);
  static Future<String?> getToken() => _storage.read(key: _tokenKey);
  static Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  // ── Multi-profile storage (Facebook-style) ─────────────────
  static Future<List<SavedProfile>> getSavedProfiles() async {
    final raw = await _storage.read(key: _profilesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => SavedProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Add or update a saved profile. Keeps most recent at the top. Max 5.
  static Future<void> saveProfile(SavedProfile profile) async {
    final profiles = await getSavedProfiles();
    profiles.removeWhere(
      (p) => p.email.toLowerCase() == profile.email.toLowerCase(),
    );
    profiles.insert(0, profile);
    if (profiles.length > 5) profiles.removeLast();
    await _storage.write(
      key: _profilesKey,
      value: jsonEncode(profiles.map((p) => p.toJson()).toList()),
    );
  }

  /// Remove a saved profile by email.
  static Future<void> removeProfile(String email) async {
    final profiles = await getSavedProfiles();
    profiles.removeWhere((p) => p.email.toLowerCase() == email.toLowerCase());
    await _storage.write(
      key: _profilesKey,
      value: jsonEncode(profiles.map((p) => p.toJson()).toList()),
    );
  }

  /// Get a single saved profile by email.
  static Future<SavedProfile?> getProfile(String email) async {
    final profiles = await getSavedProfiles();
    try {
      return profiles.firstWhere(
        (p) => p.email.toLowerCase() == email.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Enable/disable biometric for a specific profile.
  static Future<void> setBiometricForProfile(String email, bool enabled) async {
    final profiles = await getSavedProfiles();
    final idx = profiles.indexWhere(
      (p) => p.email.toLowerCase() == email.toLowerCase(),
    );
    if (idx == -1) return;
    profiles[idx] = profiles[idx].copyWith(biometricEnabled: enabled);
    await _storage.write(
      key: _profilesKey,
      value: jsonEncode(profiles.map((p) => p.toJson()).toList()),
    );
  }

  /// Check if any profile has biometric enabled.
  static Future<bool> hasAnyBiometricProfile() async {
    final profiles = await getSavedProfiles();
    return profiles.any((p) => p.biometricEnabled);
  }

  // ── Legacy compat (used by settings screen) ────────────────
  static Future<void> clearCredentials() async {
    await _storage.delete(key: _profilesKey);
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    // no-op — biometric is now per-profile
  }

  static Future<bool> isBiometricEnabled() async {
    return hasAnyBiometricProfile();
  }

  // Legacy single-credential compat for auth_provider biometric login
  static Future<void> saveCredentials(String email, String password) async {
    // Handled by saveProfile now — this is a no-op
  }

  static Future<Map<String, String>?> getSavedCredentials() async {
    final profiles = await getSavedProfiles();
    if (profiles.isEmpty) return null;
    final p = profiles.first;
    return {'email': p.email, 'password': p.password};
  }
}
