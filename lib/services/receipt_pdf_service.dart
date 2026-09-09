import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config/app_config.dart';
import '../models/receipt.dart';

/// Renders a [Receipt] as an 80 mm thermal-style receipt PDF.
///
/// The page height is unbounded ([PdfPageFormat.roll80]), so the paper grows
/// with the content — the same document prints on a receipt printer, an office
/// printer, or saves to a file.
class ReceiptPdfService {
  const ReceiptPdfService();

  static final PdfPageFormat pageFormat = PdfPageFormat.roll80.copyWith(
    marginLeft: 6 * PdfPageFormat.mm,
    marginRight: 6 * PdfPageFormat.mm,
    marginTop: 8 * PdfPageFormat.mm,
    marginBottom: 8 * PdfPageFormat.mm,
  );

  Future<Uint8List> build(Receipt receipt) async {
    final regular = pw.Font.courier();
    final bold = pw.Font.courierBold();

    final document = pw.Document(
      title: 'Receipt ${receipt.number}',
      author: AppConfig.appName,
    );

    document.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) => pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _header(bold, regular),
            _divider(),
            _row('NO.', receipt.number, regular, bold),
            _row('DATE', receipt.formattedIssuedAt, regular, bold),
            _divider(),
            _block('FROM', receipt.from, regular, bold),
            pw.SizedBox(height: 8),
            _block('TO', receipt.to, regular, bold),
            _block('PHONE', receipt.phone, regular, bold, indent: true),
            _block('ADDRESS', receipt.address, regular, bold, indent: true),
            if (receipt.hasCoordinates)
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 8, top: 2),
                child: pw.Text(
                  receipt.formattedCoordinates,
                  style: pw.TextStyle(
                    font: regular,
                    fontSize: 7,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
            _divider(),
            _block('PRODUCT', receipt.productName, regular, bold),
            _divider(),
            if (receipt.mapsUrl != null) _mapsQr(receipt.mapsUrl!, regular),
            _footer(regular, bold),
          ],
        ),
      ),
    );

    return document.save();
  }

  pw.Widget _header(pw.Font bold, pw.Font regular) {
    return pw.Column(
      children: [
        pw.Text(
          'RECEIPT',
          style: pw.TextStyle(font: bold, fontSize: 16, letterSpacing: 4),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          AppConfig.appName.toUpperCase(),
          style: pw.TextStyle(
            font: regular,
            fontSize: 7,
            letterSpacing: 1.5,
            color: PdfColors.grey700,
          ),
        ),
      ],
    );
  }

  pw.Widget _divider() => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 8),
    child: pw.Divider(height: 0, thickness: 0.7, color: PdfColors.grey500),
  );

  pw.Widget _row(String label, String value, pw.Font regular, pw.Font bold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 52,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                font: regular,
                fontSize: 8,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 9)),
          ),
        ],
      ),
    );
  }

  pw.Widget _block(
    String label,
    String value,
    pw.Font regular,
    pw.Font bold, {
    bool indent = false,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(top: indent ? 4 : 0),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: regular,
              fontSize: 7,
              letterSpacing: 1.2,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 8),
            child: pw.Text(
              value.isEmpty ? '-' : value,
              style: pw.TextStyle(font: bold, fontSize: 9, lineSpacing: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _mapsQr(String url, pw.Font regular) {
    return pw.Column(
      children: [
        pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: url,
          width: 90,
          height: 90,
          drawText: false,
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Scan to open the delivery address',
          style: pw.TextStyle(
            font: regular,
            fontSize: 7,
            color: PdfColors.grey700,
          ),
        ),
        _divider(),
      ],
    );
  }

  pw.Widget _footer(pw.Font regular, pw.Font bold) {
    return pw.Column(
      children: [
        pw.Text(
          'THANK YOU',
          style: pw.TextStyle(font: bold, fontSize: 10, letterSpacing: 2),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          'This receipt was generated automatically.',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            font: regular,
            fontSize: 7,
            color: PdfColors.grey700,
          ),
        ),
      ],
    );
  }
}
