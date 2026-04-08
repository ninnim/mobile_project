import 'package:flutter/material.dart';

enum GlassButtonVariant { primary, secondary, danger }

class GlassButton extends StatefulWidget {
  final String title;
  final VoidCallback? onPressed;
  final GlassButtonVariant variant;
  final bool loading;
  final bool disabled;
  final double? width;

  const GlassButton({
    super.key,
    required this.title,
    this.onPressed,
    this.variant = GlassButtonVariant.primary,
    this.loading = false,
    this.disabled = false,
    this.width,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Color textCol;
    Color? border;

    switch (widget.variant) {
      case GlassButtonVariant.primary:
        bg = scheme.primary;
        textCol = isDark ? const Color(0xFF0B0D21) : Colors.white;
        border = null;
      case GlassButtonVariant.secondary:
        bg = Colors.transparent;
        textCol = scheme.primary;
        border = scheme.primary;
      case GlassButtonVariant.danger:
        bg = scheme.error;
        textCol = Colors.white;
        border = null;
    }

    final isActive = !widget.disabled && !widget.loading;

    return GestureDetector(
      onTapDown: isActive ? (_) => setState(() => _scale = 0.95) : null,
      onTapUp: isActive ? (_) => setState(() => _scale = 1.0) : null,
      onTapCancel: isActive ? () => setState(() => _scale = 1.0) : null,
      onTap: isActive ? widget.onPressed : null,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: SizedBox(
          width: widget.width,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(24),
              border: border != null ? Border.all(color: border) : null,
              boxShadow: widget.variant == GlassButtonVariant.primary
                  ? [BoxShadow(color: scheme.primary.withAlpha(100), blurRadius: 20, spreadRadius: 0)]
                  : null,
            ),
            child: Opacity(
              opacity: isActive ? 1.0 : 0.5,
              child: Center(
                child: widget.loading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(textCol),
                        ),
                      )
                    : Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textCol,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
