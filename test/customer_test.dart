import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_printer/models/customer.dart';

void main() {
  Customer sample({double? lat, double? lng}) => Customer(
    id: 1,
    name: 'Budi',
    phone: '081234567890',
    address: 'Jl. Sudirman No. 1, Jakarta',
    products: const ['Kopi', 'Roti'],
    latitude: lat,
    longitude: lng,
    lastOrderedAt: DateTime(2026, 9, 9),
    orderCount: 2,
  );

  group('Customer', () {
    test('joins products into a single-line summary', () {
      expect(sample().productSummary, 'Kopi, Roti');
    });

    test('has coordinates only when both are known', () {
      expect(sample().hasCoordinates, isFalse);
      expect(sample(lat: -6.2, lng: 106.8).hasCoordinates, isTrue);
    });

    test('formats the last order date', () {
      expect(sample().formattedLastOrderedAt, '09 Sep 2026');
    });
  });
}
