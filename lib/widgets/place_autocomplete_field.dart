import 'dart:async';

import 'package:flutter/material.dart';

import '../models/address_suggestion.dart';
import '../theme/app_theme.dart';
import 'app_text_field.dart';

typedef PlaceSearch = Future<List<AddressSuggestion>> Function(String query);
typedef PlaceResolve =
    Future<AddressSuggestion> Function(AddressSuggestion place);

/// Type-ahead place picker.
///
/// Provider-agnostic on purpose: the receipt tab feeds it a map geocoder, the
/// shipping tab feeds it RajaOngkir's kecamatan database. Keystrokes are
/// debounced and every request supersedes the one before it, so a slow reply
/// can never overwrite a newer one.
class PlaceAutocompleteField extends StatefulWidget {
  const PlaceAutocompleteField({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.onResolve,
    required this.onSelected,
    required this.label,
    this.hint,
    this.helper,
    this.validator,
    this.onCleared,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final PlaceSearch onSearch;
  final PlaceResolve onResolve;

  /// Fires with a place that has coordinates or an id, whichever the provider
  /// supplies.
  final ValueChanged<AddressSuggestion> onSelected;

  /// Fires when the user edits the text again, invalidating the selection.
  final VoidCallback? onCleared;

  final String label;
  final String? hint;
  final String? helper;
  final String? Function(String?)? validator;
  final int maxLines;

  @override
  State<PlaceAutocompleteField> createState() => _PlaceAutocompleteFieldState();
}

class _PlaceAutocompleteFieldState extends State<PlaceAutocompleteField> {
  static const Duration _debounce = Duration(milliseconds: 450);

  Timer? _timer;
  List<AddressSuggestion> _suggestions = const [];
  bool _searching = false;
  bool _resolving = false;
  String? _error;

  /// Guards the change callback fired when we write the text ourselves.
  bool _suppressNextChange = false;

  /// Bumped per request so a stale response is discarded.
  int _requestId = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    if (_suppressNextChange) {
      _suppressNextChange = false;
      return;
    }

    widget.onCleared?.call();
    _timer?.cancel();

    if (value.trim().length < 3) {
      setState(() {
        _suggestions = const [];
        _searching = false;
        _error = null;
      });
      return;
    }

    setState(() => _searching = true);
    _timer = Timer(_debounce, () => _search(value));
  }

  Future<void> _search(String query) async {
    final id = ++_requestId;
    try {
      final results = await widget.onSearch(query);
      if (!mounted || id != _requestId) return;
      setState(() {
        _suggestions = results;
        _searching = false;
        _error = results.isEmpty ? 'Tidak ada hasil untuk "$query".' : null;
      });
    } catch (error) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _suggestions = const [];
        _searching = false;
        _error = '$error';
      });
    }
  }

  Future<void> _select(AddressSuggestion suggestion) async {
    _timer?.cancel();
    _requestId++;

    _setText(suggestion.description);
    setState(() {
      _suggestions = const [];
      _searching = false;
      _error = null;
      _resolving = !suggestion.hasCoordinates && suggestion.placeId != null;
    });
    FocusScope.of(context).unfocus();

    var resolved = suggestion;
    try {
      resolved = await widget.onResolve(suggestion);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }

    if (!mounted) return;
    setState(() => _resolving = false);
    if (resolved.description != widget.controller.text) {
      _setText(resolved.description);
    }
    widget.onSelected(resolved);
  }

  void _setText(String value) {
    _suppressNextChange = true;
    widget.controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _clear() {
    _timer?.cancel();
    _requestId++;
    widget.controller.clear();
    widget.onCleared?.call();
    setState(() {
      _suggestions = const [];
      _searching = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final busy = _searching || _resolving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: widget.label,
          controller: widget.controller,
          hint: widget.hint,
          helper: _error ?? widget.helper,
          validator: widget.validator,
          minLines: 1,
          maxLines: widget.maxLines,
          keyboardType: TextInputType.streetAddress,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          suffix: busy
              ? Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: palette.inkMuted,
                    ),
                  ),
                )
              : widget.controller.text.isEmpty
              ? null
              : GestureDetector(
                  onTap: _clear,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: palette.inkMuted,
                    ),
                  ),
                ),
        ),
        if (_suggestions.isNotEmpty) _suggestionList(context),
      ],
    );
  }

  Widget _suggestionList(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 244),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: palette.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _suggestions.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: palette.hairline),
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          return InkWell(
            onTap: () => _select(suggestion),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.near_me_outlined,
                      size: 16,
                      color: palette.inkFaint,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          suggestion.primaryText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        if (suggestion.secondaryText != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            suggestion.secondaryText!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
