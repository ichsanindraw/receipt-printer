import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/address_suggestion.dart';
import '../models/courier.dart';
import '../models/shipping_quote.dart';
import '../services/shipping_rate_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/choice_chips.dart';
import '../widgets/place_autocomplete_field.dart';

/// Cek ongkir — compare courier tariffs between two places.
class ShippingScreen extends StatefulWidget {
  const ShippingScreen({super.key, required this.shippingService});

  final ShippingRateService shippingService;

  @override
  State<ShippingScreen> createState() => _ShippingScreenState();
}

class _ShippingScreenState extends State<ShippingScreen>
    with AutomaticKeepAliveClientMixin {
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _weightController = TextEditingController(text: '1000');

  AddressSuggestion? _origin;
  AddressSuggestion? _destination;
  final Set<String> _selectedCouriers = {...Courier.defaultSelection};

  List<ShippingQuote>? _quotes;
  bool _loading = false;
  String? _error;

  static const List<int> _weightPresets = [500, 1000, 2000, 5000];

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  int get _weightGram => int.tryParse(_weightController.text.trim()) ?? 0;

  Future<void> _check() async {
    FocusScope.of(context).unfocus();

    if (_origin == null || _destination == null) {
      setState(() => _error = 'Pilih asal dan tujuan dari daftar saran.');
      return;
    }
    if (_weightGram <= 0) {
      setState(() => _error = 'Berat harus lebih dari 0 gram.');
      return;
    }
    if (_selectedCouriers.isEmpty) {
      setState(() => _error = 'Pilih minimal satu kurir.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final quotes = await widget.shippingService.quote(
        origin: _origin!,
        destination: _destination!,
        weightGram: _weightGram,
        courierCodes: _selectedCouriers.toList(),
      );
      if (!mounted) return;
      setState(() {
        _quotes = quotes;
        _error = quotes.isEmpty
            ? 'Tidak ada layanan untuk rute dan berat ini.'
            : null;
      });
    } on ShippingRateException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _swap() {
    setState(() {
      final originText = _originController.text;
      _originController.text = _destinationController.text;
      _destinationController.text = originText;

      final origin = _origin;
      _origin = _destination;
      _destination = origin;

      _quotes = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final service = widget.shippingService;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              4,
              AppSpacing.gutter,
              28,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              AppCard(
                title: 'Rute',
                trailing: AppTag(
                  label: service.providerLabel,
                  accent: service.isEstimate,
                ),
                children: [
                  PlaceAutocompleteField(
                    label: 'Asal',
                    hint: 'Kota atau kecamatan asal',
                    controller: _originController,
                    onSearch: service.searchPlaces,
                    onResolve: service.resolvePlace,
                    onSelected: (place) => setState(() {
                      _origin = place;
                      _quotes = null;
                    }),
                    onCleared: () {
                      if (_origin != null) setState(() => _origin = null);
                    },
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: _swap,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.swap_vert_rounded,
                              size: 16,
                              color: AppPalette.of(context).inkMuted,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Tukar',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  PlaceAutocompleteField(
                    label: 'Tujuan',
                    hint: 'Kota atau kecamatan tujuan',
                    controller: _destinationController,
                    onSearch: service.searchPlaces,
                    onResolve: service.resolvePlace,
                    onSelected: (place) => setState(() {
                      _destination = place;
                      _quotes = null;
                    }),
                    onCleared: () {
                      if (_destination != null) {
                        setState(() => _destination = null);
                      }
                    },
                  ),
                ],
              ),
              AppCard(
                title: 'Berat',
                children: [
                  AppTextField(
                    label: 'Berat paket',
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: (_) => setState(() => _quotes = null),
                    suffix: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        'gram',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final preset in _weightPresets)
                        AppChoiceChip(
                          label: preset < 1000
                              ? '$preset g'
                              : '${preset ~/ 1000} kg',
                          selected: _weightGram == preset,
                          onTap: () => setState(() {
                            _weightController.text = '$preset';
                            _quotes = null;
                          }),
                        ),
                    ],
                  ),
                ],
              ),
              AppCard(
                title: 'Kurir',
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final courier in service.couriers)
                        AppChoiceChip(
                          label: courier.name,
                          selected: _selectedCouriers.contains(courier.code),
                          onTap: () => setState(() {
                            if (!_selectedCouriers.remove(courier.code)) {
                              _selectedCouriers.add(courier.code);
                            }
                            _quotes = null;
                          }),
                        ),
                    ],
                  ),
                ],
              ),
              if (_error != null) _errorCard(context, _error!),
              if (_quotes != null && _quotes!.isNotEmpty) _results(context),
            ],
          ),
        ),
        _actionBar(context),
      ],
    );
  }

  Widget _errorCard(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.betweenCards),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 17,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _results(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final quotes = _quotes!;
    final service = widget.shippingService;

    return AppCard(
      title: '${quotes.length} layanan',
      trailing: Text(
        'Termurah dulu',
        style: theme.textTheme.bodySmall?.copyWith(color: palette.inkFaint),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      children: [
        for (var i = 0; i < quotes.length; i++) ...[
          if (i > 0) Divider(height: 1, color: palette.hairline),
          _quoteRow(context, quotes[i], cheapest: i == 0),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                service.isEstimate
                    ? Icons.info_outline_rounded
                    : Icons.verified_outlined,
                size: 14,
                color: palette.inkFaint,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  service.disclaimer,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.inkFaint,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quoteRow(
    BuildContext context,
    ShippingQuote quote, {
    required bool cheapest,
  }) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${quote.courierName} ${quote.service}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    if (cheapest) ...[
                      const SizedBox(width: 8),
                      const AppTag(label: 'TERMURAH', accent: true),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (quote.description.isNotEmpty) quote.description,
                    quote.etd,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            quote.formattedCost,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBar(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: palette.hairline)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          12,
          AppSpacing.gutter,
          12,
        ),
        child: AppButton(
          label: _loading ? 'Menghitung…' : 'Cek ongkir',
          icon: Icons.search_rounded,
          busy: _loading,
          onPressed: _loading ? null : _check,
        ),
      ),
    );
  }
}
