import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_printer/app.dart';
import 'package:receipt_printer/widgets/app_button.dart';
import 'package:receipt_printer/widgets/app_text_field.dart';

void main() {
  /// Each tab is a lazily built ListView, so give it a surface tall enough to
  /// lay out every card at once.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ReceiptPrinterApp());
    await tester.pump();
  }

  Finder fieldFor(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(AppTextField));

  Future<void> openOngkir(WidgetTester tester) async {
    // The header title and the tab share the label; the tab is the last one.
    await tester.tap(find.text('Ongkir').last);
    await tester.pumpAndSettle();
  }

  group('receipt tab', () {
    testWidgets('shows every receipt field and the print button', (
      tester,
    ) async {
      await pumpApp(tester);

      expect(find.text('Nomor'), findsOneWidget);
      expect(find.text('Dari'), findsOneWidget);
      expect(find.text('Kepada'), findsOneWidget);
      expect(find.text('Telepon'), findsOneWidget);
      expect(find.text('Nama produk'), findsOneWidget);
      expect(find.text('Alamat'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Cetak resi'), findsOneWidget);
    });

    testWidgets('prefills a generated receipt number', (tester) async {
      await pumpApp(tester);

      final field = tester.widget<AppTextField>(fieldFor('Nomor'));
      expect(field.controller?.text, matches(RegExp(r'^RCP-\d{8}-\d{4}$')));
    });

    testWidgets('blocks printing until the form is valid', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.widgetWithText(AppButton, 'Cetak resi'));
      await tester.pump();

      expect(find.text('Lengkapi dulu kolom yang ditandai.'), findsOneWidget);
      expect(find.text('Nama pengirim wajib diisi'), findsOneWidget);
      expect(find.text('Nama penerima wajib diisi'), findsOneWidget);
      expect(find.text('Nama produk wajib diisi'), findsOneWidget);
      expect(find.text('Alamat wajib diisi'), findsOneWidget);
    });

    testWidgets('rejects a phone number that is too short', (tester) async {
      await pumpApp(tester);

      await tester.enterText(fieldFor('Telepon'), '123');
      await tester.tap(find.widgetWithText(AppButton, 'Cetak resi'));
      await tester.pump();

      expect(find.text('Nomor telepon tidak valid'), findsOneWidget);
    });

    testWidgets('a validation error clears once the field is filled', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.tap(find.widgetWithText(AppButton, 'Cetak resi'));
      await tester.pump();
      expect(find.text('Nama pengirim wajib diisi'), findsOneWidget);

      await tester.enterText(fieldFor('Dari'), 'Ichsan');
      await tester.pump();
      expect(find.text('Nama pengirim wajib diisi'), findsNothing);
    });

    testWidgets('clearing the form regenerates the receipt number', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.enterText(fieldFor('Dari'), 'Ichsan');
      await tester.pump();
      expect(find.text('Ichsan'), findsOneWidget);

      await tester.tap(find.text('Kosongkan formulir'));
      await tester.pump();

      expect(find.text('Ichsan'), findsNothing);
      expect(find.text('Formulir dikosongkan.'), findsOneWidget);
    });
  });

  group('ongkir tab', () {
    testWidgets('switching tabs reveals the shipping form', (tester) async {
      await pumpApp(tester);
      await openOngkir(tester);

      expect(find.text('Asal'), findsOneWidget);
      expect(find.text('Tujuan'), findsOneWidget);
      expect(find.text('Berat paket'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Cek ongkir'), findsOneWidget);
      // Default courier selection.
      expect(find.text('JNE'), findsOneWidget);
      expect(find.text('SiCepat'), findsOneWidget);
    });

    testWidgets('refuses to quote before both places are picked', (
      tester,
    ) async {
      await pumpApp(tester);
      await openOngkir(tester);

      await tester.tap(find.widgetWithText(AppButton, 'Cek ongkir'));
      await tester.pump();

      expect(
        find.text('Pilih asal dan tujuan dari daftar saran.'),
        findsOneWidget,
      );
    });

    testWidgets('weight presets update the weight field', (tester) async {
      await pumpApp(tester);
      await openOngkir(tester);

      await tester.tap(find.text('5 kg'));
      await tester.pump();

      final field = tester.widget<AppTextField>(fieldFor('Berat paket'));
      expect(field.controller?.text, '5000');
    });

    testWidgets('the receipt tab keeps its state while on ongkir', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.enterText(fieldFor('Dari'), 'Ichsan');
      await tester.pump();

      await openOngkir(tester);
      await tester.tap(find.text('Resi').last);
      await tester.pumpAndSettle();

      expect(find.text('Ichsan'), findsOneWidget);
    });
  });
}
