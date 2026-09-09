import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/printer_settings.dart';
import '../services/image_print_service.dart';
import '../services/thermal_printer_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';

/// Pick a picture from the gallery and print it on the thermal printer.
class PrintImageScreen extends StatefulWidget {
  const PrintImageScreen({
    super.key,
    required this.printerService,
    required this.printerSettings,
  });

  final ThermalPrinterService printerService;
  final PrinterSettings printerSettings;

  @override
  State<PrintImageScreen> createState() => _PrintImageScreenState();
}

class _PrintImageScreenState extends State<PrintImageScreen>
    with AutomaticKeepAliveClientMixin {
  static const _service = ImagePrintService();

  final ImagePicker _picker = ImagePicker();

  PreparedImage? _prepared;
  bool _preparing = false;
  bool _printing = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  Future<void> _pick() async {
    setState(() => _error = null);

    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: ImageSource.gallery,
        // Keep the decode cheap; the print head is only 576 dots wide.
        maxWidth: 2000,
      );
    } catch (error) {
      if (mounted) setState(() => _error = 'Tidak bisa membuka galeri.');
      return;
    }
    if (file == null || !mounted) return;

    setState(() {
      _preparing = true;
      _prepared = null;
    });

    try {
      final prepared = await ImagePrintService.prepare(
        await file.readAsBytes(),
        widget.printerSettings.paperWidth,
      );
      if (!mounted) return;
      setState(() {
        _prepared = prepared;
        _error = prepared == null ? 'Format gambar ini tidak didukung.' : null;
      });
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _print() async {
    final prepared = _prepared;
    final settings = widget.printerSettings;
    if (prepared == null || !settings.hasDevice) return;

    setState(() {
      _printing = true;
      _error = null;
    });
    try {
      final bytes = await _service.build(prepared, cutPaper: settings.cutPaper);
      await widget.printerService.printBytes(
        bytes,
        address: settings.deviceAddress!,
        copies: settings.copies,
      );
      if (mounted) _toast('Gambar dikirim ke printer.');
    } on ThermalPrinterException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on ImagePrintException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final settings = widget.printerSettings;
    final supported = widget.printerService.isSupported;
    final ready = supported && settings.hasDevice;

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
            children: [
              if (!ready)
                _notice(
                  context,
                  supported
                      ? 'Pilih printer dulu di pengaturan printer, lalu '
                            'gambar bisa dicetak dari sini.'
                      : 'Cetak gambar butuh printer Bluetooth, yang tidak '
                            'tersedia di web.',
                ),
              AppCard(
                title: 'Gambar',
                trailing: AppTag(
                  label: '${settings.paperWidth.millimetres} MM',
                ),
                children: [
                  AppButton(
                    label: _preparing
                        ? 'Menyiapkan…'
                        : _prepared == null
                        ? 'Pilih dari galeri'
                        : 'Ganti gambar',
                    icon: Icons.photo_library_outlined,
                    variant: AppButtonVariant.outlined,
                    busy: _preparing,
                    onPressed: _preparing ? null : _pick,
                  ),
                  if (_prepared != null) ...[
                    const SizedBox(height: 10),
                    // The picker hands back a temp UUID filename, which tells
                    // nobody anything; the print size does.
                    Text(
                      '${_prepared!.width} × ${_prepared!.height} titik',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
              if (_prepared != null) _previewCard(context, _prepared!),
            ],
          ),
        ),
        Container(
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
              label: _printing ? 'Mengirim…' : 'Cetak gambar',
              icon: Icons.print_outlined,
              busy: _printing,
              onPressed: ready && _prepared != null && !_printing
                  ? _print
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _previewCard(BuildContext context, PreparedImage prepared) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    return AppCard(
      title: 'Pratinjau',
      trailing: Text(
        '${prepared.millimetresLong.round()} mm kertas',
        style: theme.textTheme.bodySmall?.copyWith(color: palette.inkFaint),
      ),
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.field),
            border: Border.all(color: palette.hairline),
          ),
          width: double.infinity,
          child: Image.memory(
            prepared.pngBytes,
            fit: BoxFit.fitWidth,
            // Nearest neighbour: smoothing would hide the dither pattern the
            // preview exists to show.
            filterQuality: FilterQuality.none,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Printer hanya bisa hitam-putih, jadi gambar diubah jadi pola titik. '
          'Hasil cetak akan persis seperti pratinjau ini.',
          style: theme.textTheme.bodySmall?.copyWith(color: palette.inkFaint),
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
