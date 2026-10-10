import 'dart:async';

import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../services/customer_history_service.dart';
import '../theme/app_theme.dart';
import 'app_text_field.dart';

/// Modal list of customers who have ordered before, filtered as you type.
/// Tapping a row pops it back to the caller, which applies it to the form —
/// a one-tap reorder.
class CustomerHistorySheet extends StatefulWidget {
  const CustomerHistorySheet({super.key, required this.service});

  final CustomerHistoryService service;

  static Future<Customer?> show(
    BuildContext context,
    CustomerHistoryService service,
  ) {
    return showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomerHistorySheet(service: service),
    );
  }

  @override
  State<CustomerHistorySheet> createState() => _CustomerHistorySheetState();
}

class _CustomerHistorySheetState extends State<CustomerHistorySheet> {
  static const _debounce = Duration(milliseconds: 300);

  final _searchController = TextEditingController();
  Timer? _timer;
  List<Customer> _results = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    // Refresh the suffix icon (search vs. clear) right away; the results
    // list itself waits for the debounce below.
    setState(() {});
    _timer?.cancel();
    _timer = Timer(_debounce, () => _search(value));
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final results = await widget.service.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _loading = false;
        _error = 'Gagal memuat riwayat: $error';
      });
    }
  }

  Future<void> _delete(Customer customer) async {
    setState(
      () => _results = _results.where((c) => c.id != customer.id).toList(),
    );
    await widget.service.delete(customer.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.card),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.hairline,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  16,
                  AppSpacing.gutter,
                  12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Riwayat pelanggan',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ketuk salah satu untuk mengisi formulir.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'Cari',
                      hint: 'Nama atau nomor HP',
                      controller: _searchController,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: _onChanged,
                      suffix: _searchController.text.isEmpty
                          ? Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: palette.inkMuted,
                            )
                          : GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                _onChanged('');
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: palette.inkMuted,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _body(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      final hasQuery = _searchController.text.trim().isNotEmpty;
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: Text(
            hasQuery
                ? 'Tidak ada pelanggan untuk "${_searchController.text.trim()}".'
                : 'Belum ada riwayat pelanggan. Riwayat terisi otomatis '
                      'setelah kamu cetak resi.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        4,
        AppSpacing.gutter,
        20,
      ),
      itemCount: _results.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: palette.hairline),
      itemBuilder: (context, index) {
        final customer = _results[index];
        return InkWell(
          onTap: () => Navigator.of(context).pop(customer),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer.name, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(customer.phone, style: theme.textTheme.bodySmall),
                      if (customer.productSummary.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          customer.productSummary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.inkFaint,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        '${customer.orderCount}× pesanan · '
                        '${customer.formattedLastOrderedAt}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _delete(customer),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: palette.inkFaint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
