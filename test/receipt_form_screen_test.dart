import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_printer/models/customer.dart';
import 'package:receipt_printer/models/printer_settings.dart';
import 'package:receipt_printer/screens/receipt_form_screen.dart';
import 'package:receipt_printer/theme/app_theme.dart';
import 'package:receipt_printer/widgets/app_button.dart';
import 'package:receipt_printer/widgets/app_text_field.dart';

import 'support/fake_address_service.dart';
import 'support/fake_customer_history_service.dart';
import 'support/fake_thermal_printer_service.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    required FakeCustomerHistoryService customerHistoryService,
  }) async {
    await tester.binding.setSurfaceSize(const Size(900, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ReceiptFormScreen(
            addressService: FakeAddressService(),
            printerService: FakeThermalPrinterService(),
            printerSettings: const PrinterSettings(),
            customerHistoryService: customerHistoryService,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder fieldFor(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(AppTextField));

  Customer customer({
    int id = 1,
    String name = 'Budi Santoso',
    String phone = '081234567890',
    String address = 'Jl. Sudirman No. 1, Jakarta',
    List<String> products = const ['Kopi', 'Roti'],
    String notes = '',
    DateTime? lastOrderedAt,
    int orderCount = 1,
  }) => Customer(
    id: id,
    name: name,
    phone: phone,
    address: address,
    products: products,
    notes: notes,
    lastOrderedAt: lastOrderedAt ?? DateTime(2026, 9, 1),
    orderCount: orderCount,
  );

  group('customer history', () {
    testWidgets('tapping a history entry applies it to the form', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        customerHistoryService: FakeCustomerHistoryService(
          customers: [customer(notes: 'Taruh di depan')],
        ),
      );

      await tester.tap(find.text('Riwayat'));
      await tester.pumpAndSettle();

      expect(find.text('Budi Santoso'), findsOneWidget);
      await tester.tap(find.text('Budi Santoso'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<AppTextField>(fieldFor('Kepada')).controller?.text,
        'Budi Santoso',
      );
      expect(
        tester
            .widget<AppTextField>(fieldFor('No. HP penerima'))
            .controller
            ?.text,
        '081234567890',
      );
      expect(
        tester.widget<AppTextField>(fieldFor('Alamat')).controller?.text,
        'Jl. Sudirman No. 1, Jakarta',
      );
      expect(
        tester.widget<AppTextField>(fieldFor('Nama produk')).controller?.text,
        'Kopi',
      );
      expect(find.text('Produk 2'), findsOneWidget);
      expect(
        tester.widget<AppTextField>(fieldFor('Produk 2')).controller?.text,
        'Roti',
      );
      expect(
        tester.widget<AppTextField>(fieldFor('Catatan')).controller?.text,
        'Taruh di depan',
      );
      expect(
        find.text('Data Budi Santoso diterapkan ke formulir.'),
        findsOneWidget,
      );
    });

    testWidgets('the search field filters the list as you type', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        customerHistoryService: FakeCustomerHistoryService(
          customers: [
            customer(id: 1, name: 'Budi', phone: '0811'),
            customer(id: 2, name: 'Siti', phone: '0822'),
          ],
        ),
      );

      await tester.tap(find.text('Riwayat'));
      await tester.pumpAndSettle();
      expect(find.text('Budi'), findsOneWidget);
      expect(find.text('Siti'), findsOneWidget);

      await tester.enterText(fieldFor('Cari'), 'Siti');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('Budi'), findsNothing);
      // One in the search box itself, one in the matching list row.
      expect(find.text('Siti'), findsNWidgets(2));
    });

    testWidgets('an empty history explains itself instead of a blank list', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        customerHistoryService: FakeCustomerHistoryService(),
      );

      await tester.tap(find.text('Riwayat'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Belum ada riwayat pelanggan'),
        findsOneWidget,
      );
    });

    testWidgets('printing a valid receipt saves it to customer history', (
      tester,
    ) async {
      final history = FakeCustomerHistoryService();
      await pumpScreen(tester, customerHistoryService: history);

      await tester.enterText(fieldFor('Kepada'), 'Budi');
      await tester.enterText(fieldFor('No. HP penerima'), '081234567890');
      await tester.enterText(fieldFor('Nama produk'), 'Kopi');
      await tester.enterText(fieldFor('Alamat'), 'Jl. Sudirman, Jakarta');

      await tester.tap(find.widgetWithText(AppButton, 'Cetak resi'));
      await tester.pump();

      expect(history.saved, hasLength(1));
      expect(history.saved.single.to, 'Budi');
      expect(history.saved.single.toPhone, '081234567890');
    });

    testWidgets('unchecking "save to history" skips saving on print', (
      tester,
    ) async {
      final history = FakeCustomerHistoryService();
      await pumpScreen(tester, customerHistoryService: history);

      await tester.enterText(fieldFor('Kepada'), 'Budi');
      await tester.enterText(fieldFor('No. HP penerima'), '081234567890');
      await tester.enterText(fieldFor('Nama produk'), 'Kopi');
      await tester.enterText(fieldFor('Alamat'), 'Jl. Sudirman, Jakarta');

      await tester.tap(find.text('Simpan pelanggan ini ke riwayat'));
      await tester.pump();
      await tester.tap(find.widgetWithText(AppButton, 'Cetak resi'));
      await tester.pump();

      expect(history.saved, isEmpty);
    });

    testWidgets('an invalid form is never saved to history', (tester) async {
      final history = FakeCustomerHistoryService();
      await pumpScreen(tester, customerHistoryService: history);

      await tester.tap(find.widgetWithText(AppButton, 'Cetak resi'));
      await tester.pump();

      expect(history.saved, isEmpty);
    });
  });
}
