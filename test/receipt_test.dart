import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_printer/models/receipt.dart';

void main() {
  Receipt sample({double? lat, double? lng}) => Receipt(
    number: 'RCP-20260909-1432',
    from: 'Ichsan',
    fromPhone: '+62 812 3456 7890',
    to: 'Budi',
    toPhone: '0895 3735 6500',
    products: const ['Espresso Machine'],
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

    test('maskPhone keeps two digits and keeps separators', () {
      expect(Receipt.maskPhone('08131369382'), '08*****9382');
      expect(Receipt.maskPhone('0812 3456 7890'), '08** **** 7890');
      // Under 10 digits: only the prefix stays visible.
      expect(Receipt.maskPhone('+62 812-3456'), '+62 ***-****');
      expect(Receipt.maskPhone('08'), '08');
      expect(Receipt.maskPhone(''), '');
    });

    test('withMaskedPhones masks only the phone numbers', () {
      final receipt = Receipt(
        number: 'RCP-1',
        from: 'Seanite',
        fromPhone: '08131369382',
        to: 'Budi',
        toPhone: '0895 3735 6500',
        products: const ['Kopi'],
        address: 'Jl. Contoh 1',
        issuedAt: DateTime(2026, 11, 27),
      );

      final masked = receipt.withMaskedPhones();

      expect(masked.fromPhone, '08*****9382');
      expect(masked.toPhone, '08** **** 6500');
      expect(masked.to, 'Budi');
      expect(masked.address, 'Jl. Contoh 1');
      expect(masked.products, const ['Kopi']);
      // The original keeps the full number for the customer history.
      expect(receipt.toPhone, '0895 3735 6500');
    });

    test('notes default to an empty string when not supplied', () {
      expect(sample().notes, isEmpty);
    });

    test('file label falls back to the date when there is no number', () {
      expect(sample().fileLabel, 'receipt-RCP-20260909-1432');

      final unnumbered = Receipt(
        number: '',
        from: 'Ichsan',
        fromPhone: '0812',
        to: 'Budi',
        toPhone: '0895',
        products: const ['Kopi'],
        address: 'Jakarta',
        issuedAt: DateTime(2026, 9, 9, 14, 32),
      );
      expect(unnumbered.fileLabel, 'receipt-20260909-1432');
    });

    test('formats coordinates only when they are known', () {
      expect(sample().hasCoordinates, isFalse);
      expect(sample().formattedCoordinates, isEmpty);

      final located = sample(lat: -6.2088, lng: 106.8456);
      expect(located.hasCoordinates, isTrue);
      expect(located.formattedCoordinates, '-6.208800, 106.845600');
    });
  });
}
