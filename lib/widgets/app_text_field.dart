import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Text field with the label sitting *above* the box rather than floating
/// inside it. Removes the notched-outline look that makes stock Material
/// forms recognisable at a glance.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.suffix,
    this.helper,
    this.validator,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.inputFormatters,
    this.minLines = 1,
    this.maxLines = 1,
    this.onChanged,
    this.autofocus = false,
    this.trailingLabel,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final Widget? suffix;

  /// Small hint under the field, replaced by the error text when invalid.
  final String? helper;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  /// Optional widget aligned opposite the label, e.g. a unit or an action.
  final Widget? trailingLabel;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<FormFieldState<String>> _fieldKey = GlobalKey();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focused != _focusNode.hasFocus) {
        setState(() => _focused = _focusNode.hasFocus);
      }
    });
    widget.controller?.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChanged);
    _focusNode.dispose();
    super.dispose();
  }

  /// The controller is also written to programmatically — by the address
  /// autocomplete, by "use this address", by the clear button. Re-run the
  /// validator so a stale error does not sit under a field that is now valid.
  void _onControllerChanged() {
    final field = _fieldKey.currentState;
    if (field != null && field.hasError) field.validate();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    return FormField<String>(
      key: _fieldKey,
      initialValue: widget.controller?.text ?? '',
      // Always validate the live controller text: `state.value` only tracks
      // typing, and these fields are written to programmatically too.
      validator: (_) => widget.validator?.call(widget.controller?.text ?? ''),
      builder: (state) {
        final hasError = state.hasError;
        final borderColor = hasError
            ? theme.colorScheme.error
            : _focused
            ? theme.colorScheme.primary
            : palette.hairline;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.label, style: theme.textTheme.labelSmall),
                ),
                ?widget.trailingLabel,
              ],
            ),
            const SizedBox(height: 7),
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: palette.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.field),
                border: Border.all(
                  color: borderColor,
                  width: _focused || hasError ? 1.5 : 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      autofocus: widget.autofocus,
                      minLines: widget.minLines,
                      maxLines: widget.maxLines,
                      keyboardType: widget.keyboardType,
                      textCapitalization: widget.textCapitalization,
                      textInputAction: widget.textInputAction,
                      inputFormatters: widget.inputFormatters,
                      style: theme.textTheme.bodyLarge,
                      cursorColor: theme.colorScheme.primary,
                      cursorWidth: 1.6,
                      cursorRadius: const Radius.circular(2),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        hintText: widget.hint,
                        hintStyle: theme.textTheme.bodyLarge?.copyWith(
                          color: palette.inkFaint,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      onChanged: (value) {
                        state.didChange(value);
                        // Clear a stale error as soon as the user types.
                        if (state.hasError) state.validate();
                        widget.onChanged?.call(value);
                      },
                    ),
                  ),
                  ?widget.suffix,
                ],
              ),
            ),
            if (hasError || widget.helper != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 2),
                child: Text(
                  hasError ? state.errorText! : widget.helper!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: hasError
                        ? theme.colorScheme.error
                        : palette.inkFaint,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
