import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../services/customer_backup.dart';
import '../services/customer_history_service.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';

/// Export and restore for the customer history, kept on the device.
///
/// Export hands a JSON file to the system share sheet, so it can be saved
/// to Files, Drive or anywhere else. Restore reads such a file back and
/// merges it in; nothing is deleted, so a restore cannot lose current data.
class BackupSheet extends StatefulWidget {
  const BackupSheet({super.key, required this.service});

  final CustomerHistoryService service;

  static Future<void> show(
    BuildContext context,
    CustomerHistoryService service,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BackupSheet(service: service),
    );
  }

  @override
  State<BackupSheet> createState() => _BackupSheetState();
}

class _BackupSheetState extends State<BackupSheet> {
  bool _busy = false;
  String? _status;
  bool _statusIsError = false;

  void _setStatus(String message, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = message;
      _statusIsError = error;
    });
  }

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final customers = await widget.service.all();
      final now = DateTime.now();
      final bytes = utf8.encode(
        CustomerBackup.encode(customers, exportedAt: now),
      );
      final fileName =
          'receipt_printer_backup_${DateFormat('yyyyMMdd_HHmm').format(now)}.json';
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes, mimeType: 'application/json', name: fileName),
          ],
          fileNameOverrides: [fileName],
        ),
      );
      if (result.status == ShareResultStatus.dismissed) {
        _setStatus('Ekspor dibatalkan.');
      } else {
        _setStatus('Cadangan ${customers.length} pelanggan siap disimpan.');
      }
    } catch (error) {
      _setStatus('Gagal mengekspor: $error', error: true);
    }
  }

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (picked.isEmpty) {
        _setStatus('Pemulihan dibatalkan.');
        return;
      }
      final bytes = await picked.single.readAsBytes();
      final customers = CustomerBackup.decode(utf8.decode(bytes));
      final changed = await widget.service.merge(customers);
      _setStatus('$changed pelanggan dipulihkan dari cadangan.');
    } on FormatException catch (error) {
      _setStatus(error.message, error: true);
    } catch (error) {
      _setStatus('Gagal memulihkan: $error', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        10,
        AppSpacing.gutter,
        AppSpacing.gutter,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: palette.hairline,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('Cadangan data', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Riwayat pelanggan disimpan di perangkat ini. Ekspor secara berkala '
            'agar bisa dipulihkan jika data hilang.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Ekspor cadangan',
            icon: Icons.ios_share_rounded,
            busy: _busy,
            onPressed: _busy ? null : _export,
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Pulihkan dari file',
            icon: Icons.file_upload_outlined,
            variant: AppButtonVariant.outlined,
            onPressed: _busy ? null : _restore,
          ),
          if (_status != null) ...[
            const SizedBox(height: 14),
            Text(
              _status!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _statusIsError
                    ? theme.colorScheme.error
                    : palette.accent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
