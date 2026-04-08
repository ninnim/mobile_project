import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/glass_input.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  final VoidCallback onGoLogin;
  const RegisterScreen({super.key, required this.onGoLogin});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _nameError, _emailError, _passError, _confirmError;
  bool _loading = false;

  void _validate() {
    setState(() {
      _nameError = _nameCtrl.text.trim().length >= 2 ? null : 'Min 2 characters';
      _emailError = _emailCtrl.text.trim().contains('@') ? null : 'Enter a valid email';
      _passError = _passCtrl.text.length >= 6 ? null : 'Min 6 characters';
      _confirmError = _confirmCtrl.text == _passCtrl.text ? null : 'Passwords do not match';
    });
  }

  Future<void> _register() async {
    _validate();
    if (_nameError != null || _emailError != null || _passError != null || _confirmError != null) return;
    setState(() => _loading = true);
    final ok = await ref.read(authProvider.notifier).register(
      _emailCtrl.text.trim(),
      _passCtrl.text,
      _nameCtrl.text.trim(),
    );
    if (mounted) setState(() => _loading = false);
    if (!ok && mounted) {
      final err = ref.read(authProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? 'Registration failed'),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
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
                ? [const Color(0xFF0B0D21), const Color(0xFF1A1D3D), const Color(0xFF0B0D21)]
                : [const Color(0xFFF0F2FF), const Color(0xFFE8ECFF), const Color(0xFFF0F2FF)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Row(children: [
                  GestureDetector(
                    onTap: widget.onGoLogin,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.primary.withAlpha(80)),
                      ),
                      child: Icon(Icons.arrow_back, color: scheme.primary, size: 20),
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
                Text(
                  'Create Account',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: scheme.onSurface),
                ),
                const SizedBox(height: 4),
                Text('Join the TimeCapsule community', style: TextStyle(color: scheme.onSurface.withAlpha(150), fontSize: 14)),
                const SizedBox(height: 32),
                GlassCard(
                  child: Column(
                    children: [
                      GlassInput(label: 'Display Name', hint: 'Your name', controller: _nameCtrl, textInputAction: TextInputAction.next, errorText: _nameError, onBlur: _validate),
                      const SizedBox(height: 14),
                      GlassInput(label: 'Email', hint: 'your@email.com', controller: _emailCtrl, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, errorText: _emailError, onBlur: _validate),
                      const SizedBox(height: 14),
                      GlassInput(label: 'Password', hint: '••••••••', controller: _passCtrl, obscure: true, textInputAction: TextInputAction.next, errorText: _passError, onBlur: _validate),
                      const SizedBox(height: 14),
                      GlassInput(label: 'Confirm Password', hint: '••••••••', controller: _confirmCtrl, obscure: true, textInputAction: TextInputAction.done, errorText: _confirmError, onBlur: _validate, onSubmitted: _register),
                      const SizedBox(height: 28),
                      GlassButton(title: 'Create Account', onPressed: _register, loading: _loading, width: double.infinity),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Already have an account? ', style: TextStyle(color: scheme.onSurface.withAlpha(150))),
                    GestureDetector(
                      onTap: widget.onGoLogin,
                      child: Text('Sign In', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
