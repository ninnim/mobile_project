import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/glass_input.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final VoidCallback onGoRegister;
  const LoginScreen({super.key, required this.onGoRegister});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String? _emailError;
  String? _passError;
  bool _loading = false;
  bool _rememberMe = true;
  bool _canUseBiometric = false;

  /// null = show profiles list, non-null = show login form for that email
  /// empty string = fresh login form (no pre-fill)
  String? _selectedEmail;

  List<SavedProfile> _savedProfiles = [];
  bool _initialLoad = true;

  @override
  void initState() {
    super.initState();
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    final profiles = await SecureStorage.getSavedProfiles();
    final canBio = await AuthNotifier.canUseBiometric();
    if (mounted) {
      setState(() {
        _savedProfiles = profiles;
        _canUseBiometric = canBio;
        _initialLoad = false;
        // If no saved profiles, go straight to login form
        if (profiles.isEmpty) _selectedEmail = '';
      });
    }
  }

  void _selectProfile(SavedProfile profile) {
    setState(() {
      _selectedEmail = profile.email;
      _emailCtrl.text = profile.email;
      _passCtrl.text = profile.password;
      _emailError = null;
      _passError = null;
      _rememberMe = true;
    });
  }

  void _showFreshForm() {
    setState(() {
      _selectedEmail = '';
      _emailCtrl.clear();
      _passCtrl.clear();
      _emailError = null;
      _passError = null;
      _rememberMe = true;
    });
  }

  void _backToProfiles() {
    setState(() {
      _selectedEmail = null;
      _emailCtrl.clear();
      _passCtrl.clear();
      _emailError = null;
      _passError = null;
    });
  }

  void _validate() {
    setState(() {
      final email = _emailCtrl.text.trim();
      if (email.isEmpty) {
        _emailError = 'Email is required';
      } else if (!email.contains('@') || !email.contains('.')) {
        _emailError = 'Enter a valid email address';
      } else {
        _emailError = null;
      }

      final pass = _passCtrl.text;
      if (pass.isEmpty) {
        _passError = 'Password is required';
      } else if (pass.length < 6) {
        _passError = 'Password must be at least 6 characters';
      } else {
        _passError = null;
      }
    });
  }

  Future<void> _login() async {
    _validate();
    if (_emailError != null || _passError != null) return;
    setState(() => _loading = true);
    final ok = await ref
        .read(authProvider.notifier)
        .login(_emailCtrl.text.trim(), _passCtrl.text, rememberMe: _rememberMe);
    if (mounted) setState(() => _loading = false);
    if (!ok && mounted) {
      final err = ref.read(authProvider).error;
      _showError(err ?? 'Invalid email or password. Please try again.');
    } else if (ok && mounted) {
      await _promptBiometricSetup();
    }
  }

  Future<void> _loginProfileWithBiometric(SavedProfile profile) async {
    setState(() => _loading = true);
    final ok = await ref
        .read(authProvider.notifier)
        .loginWithBiometric(email: profile.email);
    if (mounted) setState(() => _loading = false);
    if (!ok && mounted) {
      final err = ref.read(authProvider).error;
      if (err != null) _showError(err);
    }
  }

  Future<void> _loginProfileWithPassword(SavedProfile profile) async {
    setState(() => _loading = true);
    final ok = await ref
        .read(authProvider.notifier)
        .login(profile.email, profile.password, rememberMe: true);
    if (mounted) setState(() => _loading = false);
    if (!ok && mounted) {
      // Password might have changed — go to login form
      _selectProfile(profile);
      _passCtrl.clear();
      final err = ref.read(authProvider).error;
      _showError(err ?? 'Password may have changed. Please re-enter.');
    } else if (ok && mounted) {
      await _promptBiometricSetup();
    }
  }

  Future<void> _removeProfile(SavedProfile profile) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Account?'),
        content: Text(
          'Remove ${profile.displayName} (${profile.email}) from saved accounts?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await SecureStorage.removeProfile(profile.email);
      await _loadSavedState();
    }
  }

  Future<void> _promptBiometricSetup() async {
    if (!_canUseBiometric || !mounted) return;
    final email = ref.read(authProvider).user?.email;
    if (email == null) return;
    final alreadyEnabled = await AuthNotifier.isBiometricReadyFor(email);
    if (alreadyEnabled) return;

    final shouldEnable = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enable Biometric Login?'),
        content: const Text(
          'Use your fingerprint or face to sign in quickly next time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not Now'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
    if (shouldEnable == true) {
      await ref.read(authProvider.notifier).enableBiometric(email: email);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0B0D21),
                    const Color(0xFF1A1D3D),
                    const Color(0xFF0B0D21),
                  ]
                : [
                    const Color(0xFFF0F2FF),
                    const Color(0xFFE8ECFF),
                    const Color(0xFFF0F2FF),
                  ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 50),
                // Logo
                _buildLogo(scheme),
                const SizedBox(height: 36),
                // Content: profiles view or login form
                if (_initialLoad)
                  const Center(child: CircularProgressIndicator())
                else if (_selectedEmail == null && _savedProfiles.isNotEmpty)
                  _buildProfilesList(scheme, isDark)
                else
                  _buildLoginForm(scheme, isDark),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Logo section ─────────────────────────────────────────────
  Widget _buildLogo(ColorScheme scheme) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primary.withAlpha(20),
            border: Border.all(color: scheme.primary.withAlpha(100), width: 2),
            boxShadow: [
              BoxShadow(color: scheme.primary.withAlpha(60), blurRadius: 30),
            ],
          ),
          child: Icon(Icons.archive_rounded, size: 38, color: scheme.primary),
        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: 16),
        Text(
              'TimeCapsule',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: scheme.primary,
                letterSpacing: 1,
                shadows: [
                  Shadow(color: scheme.primary.withAlpha(120), blurRadius: 20),
                ],
              ),
              textAlign: TextAlign.center,
            )
            .animate(onPlay: (c) => c.repeat())
            .shimmer(duration: 2500.ms, color: scheme.primary.withAlpha(180)),
      ],
    );
  }

  // ── Saved profiles list (Facebook-style) ─────────────────────
  Widget _buildProfilesList(ColorScheme scheme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Choose an account',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        // Profile cards
        ..._savedProfiles.map(
          (profile) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ProfileCard(
              profile: profile,
              canUseBiometric: _canUseBiometric,
              loading: _loading,
              onTap: () {
                if (_loading) return;
                if (profile.biometricEnabled && _canUseBiometric) {
                  _loginProfileWithBiometric(profile);
                } else {
                  _loginProfileWithPassword(profile);
                }
              },
              onRemove: () => _removeProfile(profile),
            ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.05),
          ),
        ),
        const SizedBox(height: 8),
        // "Use another account" button
        GestureDetector(
          onTap: _loading ? null : _showFreshForm,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.primary.withAlpha(60)),
              color: scheme.primary.withAlpha(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_add_alt_1_rounded,
                  color: scheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'Use another account',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don't have an account? ",
              style: TextStyle(color: scheme.onSurface.withAlpha(150)),
            ),
            GestureDetector(
              onTap: widget.onGoRegister,
              child: Text(
                'Register',
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Login form ───────────────────────────────────────────────
  Widget _buildLoginForm(ColorScheme scheme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Back button if we have saved profiles
        if (_savedProfiles.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _backToProfiles,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back to saved accounts'),
              style: TextButton.styleFrom(foregroundColor: scheme.primary),
            ),
          ),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sign in to your account',
                style: TextStyle(
                  color: scheme.onSurface.withAlpha(150),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              GlassInput(
                label: 'Email',
                hint: 'your@email.com',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                errorText: _emailError,
                onBlur: _validate,
              ),
              const SizedBox(height: 16),
              GlassInput(
                label: 'Password',
                hint: '••••••••',
                controller: _passCtrl,
                obscure: true,
                textInputAction: TextInputAction.done,
                errorText: _passError,
                onBlur: _validate,
                onSubmitted: _login,
              ),
              const SizedBox(height: 12),
              // Remember me
              Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _rememberMe,
                      onChanged: (v) =>
                          setState(() => _rememberMe = v ?? false),
                      activeColor: scheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      side: BorderSide(color: scheme.onSurface.withAlpha(100)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _rememberMe = !_rememberMe),
                    child: Text(
                      'Remember me',
                      style: TextStyle(
                        color: scheme.onSurface.withAlpha(180),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              GlassButton(
                title: 'Sign In',
                onPressed: _login,
                loading: _loading,
                width: double.infinity,
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.1),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don't have an account? ",
              style: TextStyle(color: scheme.onSurface.withAlpha(150)),
            ),
            GestureDetector(
              onTap: widget.onGoRegister,
              child: Text(
                'Register',
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Social login divider
        Row(
          children: [
            Expanded(child: Divider(color: scheme.onSurface.withAlpha(40))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or continue with',
                style: TextStyle(
                  color: scheme.onSurface.withAlpha(120),
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(child: Divider(color: scheme.onSurface.withAlpha(40))),
          ],
        ),
        const SizedBox(height: 16),
        _SocialButton(
          label: 'Continue with Google',
          icon: Icons.g_mobiledata_rounded,
          color: const Color(0xFFDB4437),
          onTap: () async {
            setState(() => _loading = true);
            final ok = await ref.read(authProvider.notifier).loginWithGoogle();
            if (mounted) setState(() => _loading = false);
            if (!ok && mounted) {
              final err = ref.read(authProvider).error;
              if (err != null) _showError(err);
            }
          },
        ),
        const SizedBox(height: 10),
        _SocialButton(
          label: 'Continue with Facebook',
          icon: Icons.facebook_rounded,
          color: const Color(0xFF1877F2),
          onTap: () async {
            setState(() => _loading = true);
            final ok = await ref
                .read(authProvider.notifier)
                .loginWithFacebook();
            if (mounted) setState(() => _loading = false);
            if (!ok && mounted) {
              final err = ref.read(authProvider).error;
              if (err != null) _showError(err);
            }
          },
        ),
      ],
    );
  }
}

// ── Profile Card (Facebook-style) ────────────────────────────────
class _ProfileCard extends StatelessWidget {
  final SavedProfile profile;
  final bool canUseBiometric;
  final bool loading;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _ProfileCard({
    required this.profile,
    required this.canUseBiometric,
    required this.loading,
    required this.onTap,
    required this.onRemove,
  });

  String _resolveAvatarUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    final base = ApiConstants.baseUrl.replaceAll('/api', '');
    return '$base/$url';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarUrl = _resolveAvatarUrl(profile.profilePictureUrl);

    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D3D).withAlpha(200) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.primary.withAlpha(50)),
          boxShadow: [
            BoxShadow(color: scheme.primary.withAlpha(15), blurRadius: 12),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 26,
              backgroundColor: scheme.primary.withAlpha(30),
              backgroundImage: avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl.isEmpty
                  ? Text(
                      profile.displayName.isNotEmpty
                          ? profile.displayName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 22,
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            // Name & email
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile.email,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurface.withAlpha(120),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Biometric or login indicator
            if (profile.biometricEnabled && canUseBiometric)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primary.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.fingerprint, color: scheme.primary, size: 22),
              )
            else
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: scheme.onSurface.withAlpha(80),
                size: 16,
              ),
            const SizedBox(width: 4),
            // Remove button
            GestureDetector(
              onTap: loading ? null : onRemove,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withAlpha(15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  color: Colors.redAccent.withAlpha(180),
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Social Button ───────────────────────────────────────────────
class _SocialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D3D) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(80)),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 8),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
