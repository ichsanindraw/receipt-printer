import 'dart:async';

import 'package:flutter/material.dart';

import '../models/address_suggestion.dart';
import '../services/address_service.dart';

/// Address field with map-backed autocomplete.
///
/// Keystrokes are debounced, each query supersedes the previous one, and
/// picking a suggestion resolves its coordinates before handing it back.
class AddressAutocompleteField extends StatefulWidget {
  const AddressAutocompleteField({
    super.key,
    required this.controller,
    required this.service,
    required this.onSelected,
    this.onCleared,
  });

  final TextEditingController controller;
  final AddressService service;

  /// Fires with a suggestion that has coordinates whenever possible.
  final ValueChanged<AddressSuggestion> onSelected;

  /// Fires when the user edits the text again, invalidating the pinned point.
  final VoidCallback? onCleared;

  @override
  State<AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  static const Duration _debounce = Duration(milliseconds: 450);

  Timer? _timer;
  List<AddressSuggestion> _suggestions = const [];
  bool _searching = false;
  bool _resolving = false;
  String? _error;

  /// Guards the [TextField.onChanged] callback that fires when we set the text
  /// ourselves after a suggestion is picked.
  bool _suppressNextChange = false;

  /// Incremented per request so late responses from an older query are ignored.
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
      final results = await widget.service.search(query);
      if (!mounted || id != _requestId) return;
      setState(() {
        _suggestions = results;
        _searching = false;
        _error = results.isEmpty ? 'No address found for "$query".' : null;
      });
    } on AddressServiceException catch (error) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _suggestions = const [];
        _searching = false;
        _error = error.message;
      });
    }
  }

  Future<void> _select(AddressSuggestion suggestion) async {
    _timer?.cancel();
    _requestId++;

    _suppressNextChange = true;
    widget.controller.text = suggestion.description;
    widget.controller.selection = TextSelection.collapsed(
      offset: suggestion.description.length,
    );

    setState(() {
      _suggestions = const [];
      _searching = false;
      _error = null;
      _resolving = !suggestion.hasCoordinates;
    });
    FocusScope.of(context).unfocus();

    var resolved = suggestion;
    try {
      resolved = await widget.service.resolve(suggestion);
    } on AddressServiceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }

    if (!mounted) return;
    setState(() => _resolving = false);

    if (resolved.description != widget.controller.text) {
      _suppressNextChange = true;
      widget.controller.text = resolved.description;
    }
    widget.onSelected(resolved);
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
    final theme = Theme.of(context);
    final busy = _searching || _resolving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          onChanged: _onChanged,
          minLines: 1,
          maxLines: 3,
          textInputAction: TextInputAction.search,
          keyboardType: TextInputType.streetAddress,
          decoration: InputDecoration(
            labelText: 'Address',
            hintText: 'Start typing, then pick a suggestion',
            prefixIcon: const Icon(Icons.place_outlined),
            suffixIcon: busy
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : widget.controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear address',
                    onPressed: _clear,
                  ),
          ),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Address is required'
              : null,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 12),
            child: Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        if (_suggestions.isNotEmpty) _suggestionList(theme),
      ],
    );
  }

  Widget _suggestionList(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _suggestions.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.location_on_outlined, size: 20),
            title: Text(
              suggestion.primaryText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: suggestion.secondaryText == null
                ? null
                : Text(
                    suggestion.secondaryText!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
            onTap: () => _select(suggestion),
          );
        },
      ),
    );
  }
}
