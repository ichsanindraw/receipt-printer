import 'package:flutter/material.dart';

import '../models/printer_settings.dart';
import '../models/receipt.dart';
import '../services/receipt_escpos_service.dart';
import '../services/thermal_printer_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/choice_chips.dart';

/// Pair a Bluetooth thermal printer and set how receipts come off it.
class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({
    super.key,
    required this.settings,
    required this.printerService,
    required this.onChanged,
  });

  final PrinterSettings settings;
  final ThermalPrinterService printerService;

  /// Called on every change so the parent can persist immediately — there is
  /// no save button to forget to press.
  final ValueChanged<PrinterSettings> onChanged;

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  late PrinterSettings _settings = widget.settings;

  List<PrinterDevice>? _devices;
  bool _scanning = false;
  bool _testing = false;
  String? _error;

  static const _escPosService = ReceiptEscPosService();

  void _update(PrinterSettings settings) {
    setState(() => _settings = settings);
    widget.onChanged(settings);
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final devices = await widget.printerService.discoverDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _error = devices.isEmpty
            ? 'Tidak ada perangkat ditemukan. Pasangkan printer lewat '
                  'pengaturan Bluetooth, lalu pindai lagi.'
            : null;
      });
    } on ThermalPrinterException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _testPrint() async {
    if (!_settings.hasDevice) return;

    setState(() {
      _testing = true;
      _error = null;
    });
    try {
      final bytes = await _escPosService.build(
        _sampleReceipt(),
        paperWidth: _settings.paperWidth,
        cutPaper: _settings.cutPaper,
      );
      await widget.printerService.printBytes(
        bytes,
        address: _settings.deviceAddress!,
        copies: 1,
      );
      if (mounted) _toast('Tes cetak terkirim.');
    } on ThermalPrinterException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Receipt _sampleReceipt() => Receipt(
    number: Receipt.generateNumber(),
    from: 'Tes Printer',
    fromPhone: '0812 3456 7890',
    to: 'Contoh Penerima',
    toPhone: '0895 3735 6500',
    products: const ['Contoh produk'],
    address: 'Contoh alamat pengiriman, Jakarta',
    issuedAt: DateTime.now(),
  );

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final supported = widget.printerService.isSupported;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Printer', style: theme.textTheme.headlineSmall),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          8,
          AppSpacing.gutter,
          32,
        ),
        children: [
          if (!supported)
            _notice(
              context,
              'Printer Bluetooth hanya tersedia di Android dan iOS. Di web, '
              'resi dicetak lewat dialog cetak browser.',
            ),
          AppCard(
            title: 'Perangkat',
            trailing: _settings.hasDevice
                ? const AppTag(label: 'TERPILIH', accent: true)
                : null,
            children: [
              if (_settings.hasDevice) ...[
                _selectedDevice(context),
                const SizedBox(height: 14),
              ],
              AppButton(
                label: _scanning
                    ? 'Mencari…'
                    : _settings.hasDevice
                    ? 'Pilih printer lain'
                    : 'Cari printer',
                icon: Icons.bluetooth_searching_rounded,
                variant: AppButtonVariant.outlined,
                busy: _scanning,
                onPressed: supported && !_scanning ? _scan : null,
              ),
              if (_devices != null && _devices!.isNotEmpty) ...[
                const SizedBox(height: 14),
                _deviceList(context),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Di Android, pasangkan printer lewat pengaturan Bluetooth '
                'lebih dulu. Di iOS, printer terdekat langsung muncul.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.inkFaint,
                ),
              ),
            ],
          ),
          AppCard(
            title: 'Kertas',
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final width in PaperWidth.values)
                    AppChoiceChip(
                      label: '${width.millimetres} mm',
                      selected: _settings.paperWidth == width,
                      onTap: () =>
                          _update(_settings.copyWith(paperWidth: width)),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text('Jumlah salinan', style: theme.textTheme.labelSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final copies in const [1, 2, 3])
                    AppChoiceChip(
                      label: '$copies',
                      selected: _settings.copies == copies,
                      onTap: () => _update(_settings.copyWith(copies: copies)),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _toggle(
                context,
                label: 'Potong kertas otomatis',
                helper: 'Matikan kalau printer tidak punya pemotong.',
                value: _settings.cutPaper,
                onChanged: (value) =>
                    _update(_settings.copyWith(cutPaper: value)),
              ),
            ],
          ),
          AppButton(
            label: _testing ? 'Mengirim…' : 'Tes cetak',
            icon: Icons.print_outlined,
            busy: _testing,
            onPressed: supported && _settings.hasDevice && !_testing
                ? _testPrint
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            _settings.hasDevice
                ? 'Resi akan dicetak langsung ke printer ini. Tanpa printer '
                      'terpilih, aplikasi memakai dialog cetak sistem.'
                : 'Belum ada printer. Resi dicetak lewat dialog cetak sistem '
                      '(AirPrint / Android Print).',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: palette.inkFaint),
          ),
        ],
      ),
    );
  }

  Widget _selectedDevice(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: palette.hairline),
      ),
      child: Row(
        children: [
          Icon(Icons.print_rounded, size: 18, color: palette.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _settings.deviceName ?? 'Printer',
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _settings.deviceAddress ?? '',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _update(_settings.withoutDevice()),
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
        ],
      ),
    );
  }

  Widget _deviceList(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: palette.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < _devices!.length; i++) ...[
            if (i > 0) Divider(height: 1, color: palette.hairline),
            InkWell(
              onTap: () {
                final device = _devices![i];
                _update(
                  _settings.copyWith(
                    deviceName: device.displayName,
                    deviceAddress: device.address,
                  ),
                );
                setState(() => _devices = null);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.bluetooth_rounded,
                      size: 17,
                      color: palette.inkFaint,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _devices![i].displayName,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _devices![i].address,
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _toggle(
    BuildContext context, {
    required String label,
    required String helper,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                helper,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.inkFaint,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeTrackColor: theme.colorScheme.primary,
        ),
      ],
    );
  }

  Widget _notice(BuildContext context, String message) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.betweenCards),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: palette.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 17, color: palette.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: palette.accent),
            ),
          ),
        ],
      ),
    );
  }
}
