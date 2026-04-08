import 'package:flutter/material.dart';

class GlassInput extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? errorText;
  final bool obscure;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onBlur;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final VoidCallback? onSubmitted;

  const GlassInput({
    super.key,
    this.label,
    this.hint,
    this.errorText,
    this.obscure = false,
    this.controller,
    this.onChanged,
    this.onBlur,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  State<GlassInput> createState() => _GlassInputState();
}

class _GlassInputState extends State<GlassInput> {
  bool _obscured = true;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _focused ? scheme.primary : null,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 6),
        ],
        Focus(
          onFocusChange: (focused) {
            setState(() => _focused = focused);
            if (!focused) widget.onBlur?.call();
          },
          child: TextField(
            controller: widget.controller,
            onChanged: widget.onChanged,
            obscureText: widget.obscure && _obscured,
            maxLines: widget.obscure ? 1 : widget.maxLines,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            onSubmitted: widget.onSubmitted != null ? (_) => widget.onSubmitted!() : null,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0B0D21),
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              errorText: widget.errorText,
              suffixIcon: widget.obscure
                  ? IconButton(
                      icon: Icon(
                        _obscured ? Icons.visibility_off : Icons.visibility,
                        color: scheme.primary,
                      ),
                      onPressed: () => setState(() => _obscured = !_obscured),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
