import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models/receipt.dart';
import '../services/receipt_pdf_service.dart';

/// Full-screen preview with the platform print and share actions built in.
class ReceiptPreviewScreen extends StatelessWidget {
  const ReceiptPreviewScreen({super.key, required this.receipt});

  final Receipt receipt;

  @override
  Widget build(BuildContext context) {
    const service = ReceiptPdfService();

    return Scaffold(
      appBar: AppBar(title: Text('Receipt ${receipt.number}')),
      body: PdfPreview(
        build: (format) => service.build(receipt),
        initialPageFormat: ReceiptPdfService.pageFormat,
        pdfFileName: 'receipt-${receipt.number}.pdf',
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        useActions: true,
      ),
    );
  }
}
