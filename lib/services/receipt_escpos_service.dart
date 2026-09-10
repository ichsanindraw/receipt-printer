import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../models/printer_settings.dart';
import '../models/receipt.dart';

/// Renders a [Receipt] as ESC/POS bytes for a thermal printer.
///
/// This is the counterpart to [ReceiptPdfService]: same receipt, same reading
/// order, but as printer commands rather than a PDF, because thermal printers
/// speak ESC/POS and never see a PDF.
class ReceiptEscPosService {
  const ReceiptEscPosService();

  /// Form values print at double height. Width stays single so a line still
  /// holds 48 characters on 80 mm paper and long addresses do not wrap early.
  /// At single height they came off the printer noticeably too small to read.
  ///
  /// fontA is stated explicitly and must stay that way: the generator only
  /// emits a font command when `fontType` is non-null, so leaving it null let
  /// the value inherit font B from the caption printed just above it and come
  /// out in the small face at double height — taller, but still cramped.
  static const PosStyles _value = PosStyles(
    bold: true,
    height: PosTextSize.size2,
    fontType: PosFontType.fontA,
  );

  /// The receipt number and date, one size down from the field values —
  /// bold enough to find at a glance, but the values below are the content
  /// the recipient actually needs, and should read as more important.
  static const PosStyles _metaValue = PosStyles(
    bold: true,
    fontType: PosFontType.fontA,
  );

  /// Field captions. fontA rather than the condensed font B: B read as too
  /// small and cramped next to double-height values. Not bold, so a caption
  /// never competes with the bold value it introduces.
  static const PosStyles _label = PosStyles(fontType: PosFontType.fontA);

  Future<List<int>> build(
    Receipt receipt, {
    PaperWidth paperWidth = PaperWidth.mm80,
    bool cutPaper = true,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(_paperSize(paperWidth), profile);

    final bytes = <int>[
      ...generator.reset(),
      // No masthead — a name/logo line the recipient doesn't need, and paper
      // is worth saving. The receipt starts straight at its own metadata.
      // The receipt number is optional; skip the line rather than print a dash.
      if (receipt.number.isNotEmpty) ..._pair(generator, 'NO.', receipt.number),
      ..._pair(generator, 'TGL', receipt.formattedIssuedAt),
      ...generator.hr(),
      // A blank line after each name+phone group and after the address, not
      // just at the section dividers — previously only the dividers gave any
      // breathing room. Name and phone stay flush together within a group;
      // the coordinates line stays flush under the address it belongs to.
      ..._block(generator, 'DARI', receipt.from),
      ..._block(generator, 'NO. HP', receipt.fromPhone),
      ...generator.feed(1),
      ..._block(generator, 'KEPADA', receipt.to),
      ..._block(generator, 'NO. HP', receipt.toPhone),
      ...generator.feed(1),
      ..._block(generator, 'ALAMAT', receipt.address),
      if (receipt.hasCoordinates)
        ...generator.text(
          receipt.formattedCoordinates,
          styles: const PosStyles(fontType: PosFontType.fontB),
        ),
      ...generator.feed(1),
      ...generator.hr(),
      ..._productList(generator, 'PRODUK', receipt.products),
      if (receipt.notes.trim().isNotEmpty) ...[
        ...generator.feed(1),
        ...generator.hr(),
        ..._block(generator, 'CATATAN', receipt.notes),
      ],
      ...generator.feed(1),
      ...generator.hr(),
    ];

    // No maps QR code — the QR image itself was the single biggest thing on
    // the paper, and the coordinates already print as a small text line
    // under ALAMAT for anyone who wants to look them up by hand.
    bytes.addAll(
      generator.text(
        'TERIMA KASIH',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          fontType: PosFontType.fontA,
        ),
      ),
    );
    // The receipt number is optional and, when left blank, its row is
    // omitted entirely rather than printed empty — this explains that
    // absence to whoever is holding the paper.
    if (receipt.number.isEmpty) {
      bytes.addAll(
        generator.text(
          'Nomor resi tidak diisi',
          styles: const PosStyles(
            align: PosAlign.center,
            fontType: PosFontType.fontB,
          ),
        ),
      );
    }
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
        styles: _metaValue.copyWith(align: PosAlign.right),
      ),
    ]);
  }

  /// A small caps label with the value on the lines below, so long addresses
  /// wrap across the full paper width instead of being truncated.
  List<int> _block(Generator generator, String label, String value) {
    return [
      ...generator.text(label, styles: _label),
      ...generator.text(value.isEmpty ? '-' : value, styles: _value),
    ];
  }

  /// A caption plus one `* line` per product — a delivery is rarely just one
  /// item, so this is always a list rather than a single value.
  List<int> _productList(
    Generator generator,
    String label,
    List<String> products,
  ) {
    final items = products.where((p) => p.trim().isNotEmpty).toList();
    return [
      ...generator.text(label, styles: _label),
      if (items.isEmpty)
        ...generator.text('-', styles: _value)
      else
        for (final item in items) ...generator.text('* $item', styles: _value),
    ];
  }
}
