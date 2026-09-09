import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../config/app_config.dart';
import '../models/printer_settings.dart';
import '../models/receipt.dart';

/// Renders a [Receipt] as ESC/POS bytes for a thermal printer.
///
/// This is the counterpart to [ReceiptPdfService]: same receipt, same reading
/// order, but as printer commands rather than a PDF, because thermal printers
/// speak ESC/POS and never see a PDF.
class ReceiptEscPosService {
  const ReceiptEscPosService();

  Future<List<int>> build(
    Receipt receipt, {
    PaperWidth paperWidth = PaperWidth.mm80,
    bool cutPaper = true,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(_paperSize(paperWidth), profile);

    final bytes = <int>[
      ...generator.reset(),
      ...generator.text(
        'RECEIPT',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
      ...generator.text(
        AppConfig.appName.toUpperCase(),
        styles: const PosStyles(align: PosAlign.center),
      ),
      ...generator.hr(),
      ..._pair(generator, 'NO.', receipt.number),
      ..._pair(generator, 'TGL', receipt.formattedIssuedAt),
      ...generator.hr(),
      ..._block(generator, 'DARI', receipt.from),
      ...generator.feed(1),
      ..._block(generator, 'KEPADA', receipt.to),
      ..._block(generator, 'TELEPON', receipt.phone),
      ..._block(generator, 'ALAMAT', receipt.address),
      if (receipt.hasCoordinates)
        ...generator.text(
          receipt.formattedCoordinates,
          styles: const PosStyles(fontType: PosFontType.fontB),
        ),
      ...generator.hr(),
      ..._block(generator, 'PRODUK', receipt.productName),
      ...generator.hr(),
    ];

    final mapsUrl = receipt.mapsUrl;
    if (mapsUrl != null) {
      bytes.addAll(generator.qrcode(mapsUrl, size: QRSize.size6));
      bytes.addAll(
        generator.text(
          'Scan untuk buka alamat',
          styles: const PosStyles(
            align: PosAlign.center,
            fontType: PosFontType.fontB,
          ),
        ),
      );
      bytes.addAll(generator.hr());
    }

    bytes.addAll(
      generator.text(
        'TERIMA KASIH',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
    bytes.addAll(generator.feed(2));
    if (cutPaper) bytes.addAll(generator.cut());

    return bytes;
  }

  static PaperSize _paperSize(PaperWidth width) =>
      width == PaperWidth.mm58 ? PaperSize.mm58 : PaperSize.mm80;

  /// A label/value line, label left and value right.
  List<int> _pair(Generator generator, String label, String value) {
    return generator.row([
      PosColumn(text: label, width: 3),
      PosColumn(
        text: value,
        width: 9,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);
  }

  /// A small caps label with the value on the lines below, so long addresses
  /// wrap across the full paper width instead of being truncated.
  List<int> _block(Generator generator, String label, String value) {
    return [
      ...generator.text(
        label,
        styles: const PosStyles(fontType: PosFontType.fontB),
      ),
      ...generator.text(
        value.isEmpty ? '-' : value,
        styles: const PosStyles(bold: true),
      ),
    ];
  }
}
