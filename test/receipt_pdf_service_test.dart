import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_printer/models/receipt.dart';
import 'package:receipt_printer/services/receipt_pdf_service.dart';

void main() {
  const service = ReceiptPdfService();

  Receipt receipt({double? lat, double? lng}) => Receipt(
    number: 'RCP-20260909-1432',
    from: 'Ichsan',
    to: 'Budi',
    phone: '081234567890',
    productName: 'Espresso Machine',
    address: 'Jl. Sudirman No. 1, Jakarta',
    latitude: lat,
    longitude: lng,
    issuedAt: DateTime(2026, 9, 9, 14, 32),
  );

  test('builds a valid PDF document', () async {
    final bytes = await service.build(receipt());

    expect(bytes.length, greaterThan(500));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('embeds a map QR code when the address is pinned', () async {
    final plain = await service.build(receipt());
    final withMap = await service.build(receipt(lat: -6.2088, lng: 106.8456));

    // The QR code adds drawing operations, so the located receipt is larger.
    expect(withMap.length, greaterThan(plain.length));
  });

  test('renders the receipt on 80 mm roll paper', () {
    expect(ReceiptPdfService.pageFormat.width, closeTo(226.77, 0.1));
    expect(ReceiptPdfService.pageFormat.height, double.infinity);
  });
}
