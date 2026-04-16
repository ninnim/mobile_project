import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;
  /// Set to false for cards inside scrolling lists to skip BackdropFilter
  /// and maintain 60-120fps. Use true (default) for static/overlay contexts.
  final bool blur;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 16,
    this.borderColor,
    this.backgroundColor,
    this.blur = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final decoration = BoxDecoration(
      color: backgroundColor ??
          (isDark
              ? const Color(0xF01A1D3D) // opaque enough — no blur needed
              : scheme.surface.withAlpha(245)),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor ?? scheme.primary.withAlpha(77), width: 1),
      boxShadow: [
        BoxShadow(
          color: scheme.primary.withAlpha(22),
          blurRadius: 16,
          spreadRadius: 0,
        ),
      ],
    );

    if (!blur) {
      return Container(
        padding: padding ?? const EdgeInsets.all(16),
        decoration: decoration,
        child: child,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: decoration,
          child: child,
        ),
      ),
    );
  }
}
