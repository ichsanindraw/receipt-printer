import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_printer/models/receipt.dart';
import 'package:receipt_printer/services/receipt_pdf_service.dart';

void main() {
  const service = ReceiptPdfService();

  Receipt receipt({
    double? lat,
    double? lng,
    List<String> products = const ['Espresso Machine'],
    String notes = '',
    String address = 'Jl. Sudirman No. 1, Jakarta',
  }) => Receipt(
    number: 'RCP-20260909-1432',
    from: 'Ichsan',
    fromPhone: '081234567890',
    to: 'Budi',
    toPhone: '0895 3735 6500',
    products: products,
    address: address,
    notes: notes,
    latitude: lat,
    longitude: lng,
    issuedAt: DateTime(2026, 9, 9, 14, 32),
  );

  test('builds a valid PDF document', () async {
    final bytes = await service.build(receipt());

    expect(bytes.length, greaterThan(500));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test(
    'adds only the coordinates line, not a map QR code, when pinned',
    () async {
      // Regression: a drawn QR code used to be the single biggest thing on the
      // page. Pinning coordinates should now only add the small text footnote
      // — measured at 33 bytes for this fixture — nowhere near a barcode's
      // vector drawing operations.
      final plain = await service.build(receipt());
      final located = await service.build(receipt(lat: -6.2088, lng: 106.8456));

      expect(located.length, greaterThan(plain.length));
      expect(located.length - plain.length, lessThan(200));
    },
  );

  test('a second product line adds real content to the document', () async {
    final oneProduct = await service.build(receipt());
    final twoProducts = await service.build(
      receipt(products: const ['Espresso Machine', 'Milk Frother']),
    );

    expect(twoProducts.length, greaterThan(oneProduct.length));
  });

  test('renders even with an empty product list', () async {
    // Defensive: the form always keeps at least one product row, but the
    // renderer itself should not fall over if that invariant is ever broken.
    final bytes = await service.build(receipt(products: const []));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('a note adds real content to the document', () async {
    final withoutNote = await service.build(receipt());
    final withNote = await service.build(
      receipt(notes: 'Titip di satpam kalau tidak ada orang.'),
    );

    expect(withNote.length, greaterThan(withoutNote.length));
  });

  test('renders a hand-typed multi-line address without error', () async {
    // The address is free text the courier may format across several lines
    // by hand, not only a single autocompleted line.
    final bytes = await service.build(
      receipt(
        address:
            'Klinik Bersalin Putera Jaya\n'
            'Jl Apel Gg. Apel Salam\n'
            'Pontianak Barat, Kota Pontianak\n'
            'Kalimantan Barat',
      ),
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('renders the receipt on 80 mm roll paper', () {
    expect(ReceiptPdfService.pageFormat.width, closeTo(226.77, 0.1));
    expect(ReceiptPdfService.pageFormat.height, double.infinity);
  });
}
