import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_printer/models/customer.dart';
import 'package:receipt_printer/services/customer_backup.dart';
import 'package:receipt_printer/services/customer_history_service_io.dart';
import 'package:receipt_printer/services/customer_history_service_unsupported.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Customer customer({
    String phone = '081234567890',
    String name = 'Budi',
    String address = 'Jl. Sudirman No. 1',
    List<String> products = const ['Kopi', 'Roti'],
    double? latitude,
    double? longitude,
    DateTime? lastOrderedAt,
    int orderCount = 2,
  }) => Customer(
    id: 0,
    name: name,
    phone: phone,
    address: address,
    products: products,
    notes: 'Tanpa gula',
    latitude: latitude,
    longitude: longitude,
    lastOrderedAt: lastOrderedAt ?? DateTime(2026, 9, 9, 14, 32),
    orderCount: orderCount,
  );

  group('CustomerBackup', () {
    test('round-trips every customer field', () {
      final original = [
        customer(latitude: -6.2, longitude: 106.8),
        customer(phone: '08999', name: 'Sari', products: const ['Teh']),
      ];

      final decoded = CustomerBackup.decode(
        CustomerBackup.encode(original, exportedAt: DateTime(2026, 11, 27)),
      );

      expect(decoded, hasLength(2));
      expect(decoded[0].name, 'Budi');
      expect(decoded[0].products, ['Kopi', 'Roti']);
      expect(decoded[0].notes, 'Tanpa gula');
      expect(decoded[0].latitude, -6.2);
      expect(decoded[0].longitude, 106.8);
      expect(decoded[0].lastOrderedAt, DateTime(2026, 9, 9, 14, 32));
      expect(decoded[0].orderCount, 2);
      expect(decoded[1].name, 'Sari');
      expect(decoded[1].latitude, isNull);
    });

    test('rejects a file that is not a customer backup', () {
      expect(
        () => CustomerBackup.decode('{"hello": "world"}'),
        throwsFormatException,
      );
      expect(() => CustomerBackup.decode('not json'), throwsFormatException);
    });

    test('rejects a backup written by a newer app version', () {
      final newer = CustomerBackup.encode([customer()]).replaceFirst(
        '"version": ${CustomerBackup.version}',
        '"version": ${CustomerBackup.version + 1}',
      );
      expect(() => CustomerBackup.decode(newer), throwsFormatException);
    });

    test('rejects a customer missing a required field', () {
      const broken =
          '{"type":"customer_history","version":1,"customers":[{"name":"X"}]}';
      expect(() => CustomerBackup.decode(broken), throwsFormatException);
    });
  });

  group('merge', () {
    final backup = [
      customer(
        products: const ['Kopi'],
        lastOrderedAt: DateTime(2026, 9, 1),
        orderCount: 3,
      ),
    ];

    test('in-memory: restoring twice does not double-count', () async {
      final service = InMemoryCustomerHistoryService();
      await service.merge(backup);
      await service.merge(backup);

      final stored = await service.all();
      expect(stored, hasLength(1));
      expect(stored.single.orderCount, 3);
    });

    test('in-memory: the newer order wins the details', () async {
      final service = InMemoryCustomerHistoryService();
      await service.merge([
        customer(
          address: 'Alamat lama',
          lastOrderedAt: DateTime(2026, 1, 1),
          orderCount: 5,
        ),
      ]);
      await service.merge([
        customer(
          address: 'Alamat baru',
          lastOrderedAt: DateTime(2026, 6, 1),
          orderCount: 2,
        ),
      ]);

      final stored = (await service.all()).single;
      expect(stored.address, 'Alamat baru');
      expect(stored.orderCount, 5);
    });

    test('sqlite: restoring twice does not double-count', () async {
      final service = SqliteCustomerHistoryService(
        databasePath: inMemoryDatabasePath,
      );
      await service.merge(backup);
      await service.merge(backup);

      final stored = await service.all();
      expect(stored, hasLength(1));
      expect(stored.single.orderCount, 3);
      expect(stored.single.products, ['Kopi']);
    });
  });
}
