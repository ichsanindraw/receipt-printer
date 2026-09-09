import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Ink-filled action button that dips slightly while pressed. Replaces
/// [FilledButton] so there is no Material ripple or tonal surface tint.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.variant = AppButtonVariant.filled,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;
  final AppButtonVariant variant;

  @override
  State<AppButton> createState() => _AppButtonState();
}

enum AppButtonVariant { filled, outlined }

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final filled = widget.variant == AppButtonVariant.filled;
    final enabled = widget.onPressed != null && !widget.busy;

    final foreground = filled
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;
    final background = filled ? theme.colorScheme.primary : Colors.transparent;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _pressed ? 0.975 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: Container(
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(AppRadius.field),
              border: filled ? null : Border.all(color: palette.hairline),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.busy)
                  SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  )
                else if (widget.icon != null)
                  Icon(widget.icon, size: 19, color: foreground),
                if (widget.busy || widget.icon != null)
                  const SizedBox(width: 10),
                Text(
                  widget.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
