import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/glass_input.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _currentPwCtrl;
  late TextEditingController _newPwCtrl;
  late TextEditingController _confirmPwCtrl;
  bool _saving = false;
  bool _changingPw = false;
  bool _showCurrentPw = false;
  bool _showNewPw = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameCtrl = TextEditingController(text: user?.displayName ?? '');
    _bioCtrl = TextEditingController(text: user?.bio ?? '');
    _currentPwCtrl = TextEditingController();
    _newPwCtrl = TextEditingController();
    _confirmPwCtrl = TextEditingController();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final available = await AuthNotifier.canUseBiometric();
    final user = ref.read(authProvider).user;
    bool enabled = false;
    if (user != null) {
      enabled = await AuthNotifier.isBiometricReadyFor(user.email);
    }
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _currentPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    if (name.length < 2) {
      _showSnack('Name must be at least 2 characters', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await dioClient.put(
        '/auth/me',
        data: FormData.fromMap({
          'displayName': name,
          'bio': _bioCtrl.text.trim(),
        }),
      );
      await ref.read(authProvider.notifier).refreshUser();
      _showSnack('Profile updated!');
    } catch (_) {
      _showSnack('Failed to save', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final res = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (res == null) return;
    setState(() => _saving = true);
    try {
      final form = FormData.fromMap({
        'profilePicture': await MultipartFile.fromFile(
          res.path,
          filename: 'avatar.jpg',
        ),
      });
      await dioClient.put('/auth/me', data: form);
      await ref.read(authProvider.notifier).refreshUser();
      _showSnack('Profile picture updated!');
    } catch (_) {
      _showSnack('Failed to update picture', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final current = _currentPwCtrl.text;
    final newPw = _newPwCtrl.text;
    final confirm = _confirmPwCtrl.text;

    if (current.isEmpty) {
      _showSnack('Enter current password', isError: true);
      return;
    }
    if (newPw.length < 6) {
      _showSnack('New password must be at least 6 characters', isError: true);
      return;
    }
    if (newPw != confirm) {
      _showSnack('Passwords do not match', isError: true);
      return;
    }

    setState(() => _changingPw = true);
    try {
      await dioClient.put(
        '/auth/change-password',
        data: {'currentPassword': current, 'newPassword': newPw},
      );
      _currentPwCtrl.clear();
      _newPwCtrl.clear();
      _confirmPwCtrl.clear();
      _showSnack('Password changed successfully!');
    } catch (e) {
      String msg = 'Failed to change password';
      if (e is DioException && e.response?.data is Map) {
        msg = (e.response!.data as Map)['error'] as String? ?? msg;
      }
      _showSnack(msg, isError: true);
    } finally {
      if (mounted) setState(() => _changingPw = false);
    }
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      // Pop settings screen first, then logout
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final themeState = ref.watch(themeProvider);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          // ── Profile Picture ───────────────────────────────────
          _SectionHeader(title: 'Profile Picture'),
          const SizedBox(height: 8),
          Center(
            child: GestureDetector(
              onTap: _saving ? null : _pickAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: scheme.primary.withAlpha(30),
                    backgroundImage: user.profilePictureUrl != null
                        ? NetworkImage(user.profilePictureUrl!)
                        : null,
                    child: user.profilePictureUrl == null
                        ? Text(
                            user.displayName.isNotEmpty
                                ? user.displayName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 32,
                              color: scheme.primary,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surface, width: 2),
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        size: 14,
                        color: isDark ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                  if (_saving)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withAlpha(100),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Edit Profile ──────────────────────────────────────
          _SectionHeader(title: 'Edit Profile'),
          const SizedBox(height: 8),
          GlassCard(
            child: Column(
              children: [
                GlassInput(label: 'Display Name', controller: _nameCtrl),
                const SizedBox(height: 12),
                GlassInput(
                  label: 'Bio',
                  controller: _bioCtrl,
                  maxLines: 3,
                  hint: 'Tell something about yourself...',
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: FilledButton(
                    onPressed: _saving ? null : _saveProfile,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Change Password ───────────────────────────────────
          _SectionHeader(title: 'Change Password'),
          const SizedBox(height: 8),
          GlassCard(
            child: Column(
              children: [
                GlassInput(
                  label: 'Current Password',
                  controller: _currentPwCtrl,
                  obscure: !_showCurrentPw,
                ),
                const SizedBox(height: 12),
                GlassInput(
                  label: 'New Password',
                  controller: _newPwCtrl,
                  obscure: !_showNewPw,
                  hint: 'Min 6 characters',
                ),
                const SizedBox(height: 12),
                GlassInput(
                  label: 'Confirm New Password',
                  controller: _confirmPwCtrl,
                  obscure: !_showNewPw,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _showNewPw,
                        onChanged: (v) => setState(() {
                          _showNewPw = v ?? false;
                          _showCurrentPw = v ?? false;
                        }),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Show passwords',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withAlpha(150),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: OutlinedButton(
                    onPressed: _changingPw ? null : _changePassword,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: scheme.primary.withAlpha(100)),
                    ),
                    child: _changingPw
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.primary,
                            ),
                          )
                        : const Text('Change Password'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Theme ─────────────────────────────────────────────
          _SectionHeader(title: 'Appearance'),
          const SizedBox(height: 8),
          GlassCard(
            child: Column(
              children: [
                Row(
                  children: [
                    _ThemeChip(
                      label: 'System',
                      icon: Icons.brightness_auto_rounded,
                      selected: themeState.mode == ThemeMode.system,
                      onTap: () => ref
                          .read(themeProvider.notifier)
                          .setMode(ThemeMode.system),
                    ),
                    const SizedBox(width: 8),
                    _ThemeChip(
                      label: 'Light',
                      icon: Icons.light_mode_rounded,
                      selected: themeState.mode == ThemeMode.light,
                      onTap: () => ref
                          .read(themeProvider.notifier)
                          .setMode(ThemeMode.light),
                    ),
                    const SizedBox(width: 8),
                    _ThemeChip(
                      label: 'Dark',
                      icon: Icons.dark_mode_rounded,
                      selected: themeState.mode == ThemeMode.dark,
                      onTap: () => ref
                          .read(themeProvider.notifier)
                          .setMode(ThemeMode.dark),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Accent Color',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: accentPresets.map((color) {
                    final isSelected =
                        themeState.accent.toARGB32() == color.toARGB32();
                    return GestureDetector(
                      onTap: () =>
                          ref.read(themeProvider.notifier).setAccent(color),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withAlpha(150),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Security ──────────────────────────────────────────
          if (_biometricAvailable) ...[
            _SectionHeader(title: 'Security'),
            const SizedBox(height: 8),
            GlassCard(
              child: Row(
                children: [
                  Icon(Icons.fingerprint, color: scheme.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Biometric Login',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          'Use fingerprint or face to sign in',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurface.withAlpha(120),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _biometricEnabled,
                    activeColor: scheme.primary,
                    onChanged: (v) async {
                      final userEmail = ref.read(authProvider).user?.email;
                      if (v) {
                        if (userEmail == null) return;
                        // enableBiometric now auto-creates a stub profile if needed
                        final ok = await ref
                            .read(authProvider.notifier)
                            .enableBiometric(email: userEmail);
                        if (ok && mounted) {
                          setState(() => _biometricEnabled = true);
                          _showSnack('Biometric login enabled');
                        }
                      } else {
                        if (userEmail != null) {
                          await SecureStorage.setBiometricForProfile(
                            userEmail,
                            false,
                          );
                        }
                        if (mounted) {
                          setState(() => _biometricEnabled = false);
                          _showSnack('Biometric login disabled');
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Account Info ──────────────────────────────────────
          _SectionHeader(title: 'Account'),
          const SizedBox(height: 8),
          GlassCard(
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: user.email,
                ),
                const Divider(height: 20),
                _InfoRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Member since',
                  value: _formatDate(user.createdAt),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── Sign Out ──────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.onSurface.withAlpha(120)),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: scheme.onSurface.withAlpha(120),
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? scheme.primary.withAlpha(30) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? scheme.primary : scheme.onSurface.withAlpha(40),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? scheme.primary
                    : scheme.onSurface.withAlpha(150),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                  color: selected
                      ? scheme.primary
                      : scheme.onSurface.withAlpha(150),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
