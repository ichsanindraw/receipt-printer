import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:receipt_printer/models/receipt.dart';
import 'package:receipt_printer/services/customer_history_service.dart';
import 'package:receipt_printer/services/customer_history_service_io.dart';
import 'package:receipt_printer/services/customer_history_service_unsupported.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Receipt receipt({
    String to = 'Budi',
    String toPhone = '08123456789',
    String address = 'Jl. Sudirman No. 1, Jakarta',
    List<String> products = const ['Kopi'],
    String notes = '',
    double? lat,
    double? lng,
    DateTime? issuedAt,
  }) => Receipt(
    number: 'RCP-1',
    from: 'Seanite',
    fromPhone: '0813',
    to: to,
    toPhone: toPhone,
    products: products,
    address: address,
    notes: notes,
    latitude: lat,
    longitude: lng,
    issuedAt: issuedAt ?? DateTime(2026, 9, 9, 14, 32),
  );

  /// Both implementations — SQLite on Android/iOS, in-memory on web — must
  /// agree on this contract, so one suite runs against both.
  void behavesLikeACustomerHistoryService(
    CustomerHistoryService Function() create,
  ) {
    test('does nothing for a receipt with no recipient phone', () async {
      final service = create();
      await service.saveFromReceipt(receipt(toPhone: ''));
      expect(await service.search(''), isEmpty);
    });

    test('saves the recipient as a new customer', () async {
      final service = create();
      await service.saveFromReceipt(
        receipt(notes: 'Taruh di depan', lat: -6.2, lng: 106.8),
      );

      final results = await service.search('');
      expect(results, hasLength(1));
      final customer = results.single;
      expect(customer.name, 'Budi');
      expect(customer.phone, '08123456789');
      expect(customer.address, 'Jl. Sudirman No. 1, Jakarta');
      expect(customer.products, ['Kopi']);
      expect(customer.notes, 'Taruh di depan');
      expect(customer.latitude, -6.2);
      expect(customer.longitude, 106.8);
      expect(customer.orderCount, 1);
    });

    test('a repeat phone number refreshes the customer instead of duplicating '
        'it', () async {
      final service = create();
      await service.saveFromReceipt(receipt(address: 'Alamat lama'));
      await service.saveFromReceipt(
        receipt(address: 'Alamat baru', products: const ['Kopi', 'Roti']),
      );

      final results = await service.search('');
      expect(results, hasLength(1));
      expect(results.single.address, 'Alamat baru');
      expect(results.single.products, ['Kopi', 'Roti']);
      expect(results.single.orderCount, 2);
    });

    test('search matches by name or phone', () async {
      final service = create();
      await service.saveFromReceipt(receipt(to: 'Budi Santoso'));

      expect(await service.search('Budi'), hasLength(1));
      expect(await service.search('812345'), hasLength(1));
      expect(await service.search('tidak ada'), isEmpty);
    });

    test(
      'a blank query returns the most recently ordered customers first',
      (() async {
        final service = create();
        await service.saveFromReceipt(
          receipt(to: 'Lama', toPhone: '0811', issuedAt: DateTime(2026, 1, 1)),
        );
        await service.saveFromReceipt(
          receipt(to: 'Baru', toPhone: '0822', issuedAt: DateTime(2026, 6, 1)),
        );

        final results = await service.search('');
        expect(results.map((c) => c.name), ['Baru', 'Lama']);
      }),
    );

    test('delete removes a customer from future searches', () async {
      final service = create();
      await service.saveFromReceipt(receipt());
      final id = (await service.search('')).single.id;

      await service.delete(id);
      expect(await service.search(''), isEmpty);
    });
  }

  group('SqliteCustomerHistoryService', () {
    // sqflite caches opened databases by path, so every test reusing
    // `inMemoryDatabasePath` would share one connection and leak rows
    // between tests. A fresh temp file per test keeps them isolated.
    late Directory tempDir;
    var dbCount = 0;

    setUp(() => tempDir = Directory.systemTemp.createTempSync('ch_test_'));
    tearDown(() => tempDir.deleteSync(recursive: true));

    behavesLikeACustomerHistoryService(
      () => SqliteCustomerHistoryService(
        databasePath: path.join(tempDir.path, 'db_${dbCount++}.sqlite'),
      ),
    );
  });

  group('InMemoryCustomerHistoryService', () {
    behavesLikeACustomerHistoryService(InMemoryCustomerHistoryService.new);
  });
}
