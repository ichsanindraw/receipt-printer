import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_printer/models/receipt.dart';

void main() {
  Receipt sample({double? lat, double? lng}) => Receipt(
    number: 'RCP-20260909-1432',
    from: 'Ichsan',
    to: 'Budi',
    phone: '+62 812 3456 7890',
    productName: 'Espresso Machine',
    address: 'Jl. Sudirman No. 1, Jakarta',
    latitude: lat,
    longitude: lng,
    issuedAt: DateTime(2026, 9, 9, 14, 32),
  );

  group('Receipt', () {
    test('generateNumber uses the RCP-yyyyMMdd-HHmm pattern', () {
      final number = Receipt.generateNumber(DateTime(2026, 9, 9, 14, 32));
      expect(number, 'RCP-20260909-1432');
    });

    test('formats the issue date for the printed receipt', () {
      expect(sample().formattedIssuedAt, '09 Sep 2026, 14:32');
    });

    test('file label falls back to the date when there is no number', () {
      expect(sample().fileLabel, 'receipt-RCP-20260909-1432');

      final unnumbered = Receipt(
        number: '',
        from: 'Ichsan',
        to: 'Budi',
        phone: '0812',
        productName: 'Kopi',
        address: 'Jakarta',
        issuedAt: DateTime(2026, 9, 9, 14, 32),
      );
      expect(unnumbered.fileLabel, 'receipt-20260909-1432');
    });

    test('exposes a maps deep link only when coordinates are known', () {
      expect(sample().mapsUrl, isNull);
      expect(sample().hasCoordinates, isFalse);

      final located = sample(lat: -6.2088, lng: 106.8456);
      expect(located.hasCoordinates, isTrue);
      expect(
        located.mapsUrl,
        'https://www.google.com/maps/search/?api=1&query=-6.2088,106.8456',
      );
      expect(located.formattedCoordinates, '-6.208800, 106.845600');
    });
  });
}
