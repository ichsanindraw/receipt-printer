import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:receipt_printer/app.dart';
import 'package:receipt_printer/widgets/app_button.dart';
import 'package:receipt_printer/widgets/app_text_field.dart';

void main() {
  /// Each tab is a lazily built ListView, so give it a surface tall enough to
  /// lay out every card at once.
  Future<void> pumpApp(WidgetTester tester) async {
    // The home screen reads saved printer settings on start.
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(900, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ReceiptPrinterApp());
    await tester.pump();
  }

  Finder fieldFor(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(AppTextField));

  /// The header title and the tab share the label; the tab is the last one.
  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> openOngkir(WidgetTester tester) => openTab(tester, 'Ongkir');

  group('receipt tab', () {
    testWidgets('shows every receipt field and the print button', (
      tester,
    ) async {
      await pumpApp(tester);

      expect(find.text('Nomor'), findsOneWidget);
      expect(find.text('Dari'), findsOneWidget);
      expect(find.text('No. HP pengirim'), findsOneWidget);
      expect(find.text('Kepada'), findsOneWidget);
      expect(find.text('No. HP penerima'), findsOneWidget);
      expect(find.text('Nama produk'), findsOneWidget);
      expect(find.text('Alamat'), findsOneWidget);
      expect(find.text('Catatan'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Cetak resi'), findsOneWidget);
    });

    testWidgets('prefills a generated receipt number', (tester) async {
      await pumpApp(tester);

      final field = tester.widget<AppTextField>(fieldFor('Nomor'));
      expect(field.controller?.text, matches(RegExp(r'^RCP-\d{8}-\d{4}$')));
    });

    testWidgets('prefills the sender with its standing default', (
      tester,
    ) async {
      await pumpApp(tester);

      expect(find.text('Seanité'), findsOneWidget);
      expect(find.text('08131369382'), findsOneWidget);
    });

    testWidgets('blocks printing until the form is valid', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.widgetWithText(AppButton, 'Cetak resi'));
      await tester.pump();

      expect(find.text('Lengkapi dulu kolom yang ditandai.'), findsOneWidget);
      // The sender defaults are already valid, so only the recipient,
      // product and address are left complaining.
      expect(find.text('Nama pengirim wajib diisi'), findsNothing);
      expect(find.text('Nama penerima wajib diisi'), findsOneWidget);
      expect(find.text('No. HP penerima wajib diisi'), findsOneWidget);
      expect(find.text('Nama produk wajib diisi'), findsOneWidget);
      expect(find.text('Alamat wajib diisi'), findsOneWidget);
    });

    testWidgets('the receipt number is optional', (tester) async {
      await pumpApp(tester);

      await tester.enterText(fieldFor('Nomor'), '');
      await tester.tap(find.widgetWithText(AppButton, 'Cetak resi'));
      await tester.pump();

      // The other fields still complain; the number does not.
      expect(find.text('Nama penerima wajib diisi'), findsOneWidget);
      expect(find.textContaining('Nomor resi'), findsNothing);
      expect(
        find.text('Opsional — kosongkan kalau tidak dipakai.'),
        findsOneWidget,
      );
    });

    testWidgets('rejects a phone number that is too short', (tester) async {
      await pumpApp(tester);

      await tester.enterText(fieldFor('No. HP penerima'), '123');
      await tester.tap(find.widgetWithText(AppButton, 'Cetak resi'));
      await tester.pump();

      expect(find.text('No. HP penerima tidak valid'), findsOneWidget);
    });

    testWidgets('a validation error clears once the field is filled', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.tap(find.widgetWithText(AppButton, 'Cetak resi'));
      await tester.pump();
      expect(find.text('Nama penerima wajib diisi'), findsOneWidget);

      await tester.enterText(fieldFor('Kepada'), 'Ichsan');
      await tester.pump();
      expect(find.text('Nama penerima wajib diisi'), findsNothing);
    });

    testWidgets('a second product field can be added and removed', (
      tester,
    ) async {
      await pumpApp(tester);

      expect(find.text('Produk 2'), findsNothing);
      // With a single product, removing it is not offered at all.
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      await tester.tap(find.text('Tambah produk'));
      await tester.pump();
      expect(find.text('Produk 2'), findsOneWidget);
      // With two rows, both become removable — not just the one just added.
      expect(find.byIcon(Icons.close_rounded), findsNWidgets(2));

      // Rows render in order, so the second row's button is the last one.
      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pump();
      expect(find.text('Produk 2'), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets(
      'only the first product is required; extra blank rows are dropped',
      (tester) async {
        await pumpApp(tester);
        await tester.enterText(fieldFor('Kepada'), 'Ichsan');
        await tester.enterText(fieldFor('No. HP penerima'), '081234567890');
        await tester.enterText(fieldFor('Nama produk'), 'Kopi');
        await tester.enterText(fieldFor('Alamat'), 'Jl. Sudirman, Jakarta');

        await tester.tap(find.text('Tambah produk'));
        await tester.pump();
        // Leave "Produk 2" blank.

        await tester.tap(find.widgetWithText(AppButton, 'Cetak resi'));
        await tester.pump();

        expect(find.text('Lengkapi dulu kolom yang ditandai.'), findsNothing);
      },
    );

    testWidgets('the notes field has no validator and stays optional', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.widgetWithText(AppButton, 'Cetak resi'));
      await tester.pump();

      expect(find.text('Catatan wajib diisi'), findsNothing);
    });

    testWidgets('clearing the form keeps the sender default', (tester) async {
      await pumpApp(tester);

      await tester.enterText(fieldFor('Dari'), 'Toko Lain');
      await tester.enterText(fieldFor('Kepada'), 'Ichsan');
      await tester.pump();
      expect(find.text('Toko Lain'), findsOneWidget);

      await tester.tap(find.text('Kosongkan formulir'));
      await tester.pump();

      expect(find.text('Toko Lain'), findsNothing);
      expect(find.text('Ichsan'), findsNothing);
      // The sender default comes back rather than being blanked out too.
      expect(find.text('Seanité'), findsOneWidget);
      expect(find.text('08131369382'), findsOneWidget);
      expect(find.text('Formulir dikosongkan.'), findsOneWidget);
    });
  });

  group('gambar tab', () {
    testWidgets('offers a gallery picker and a disabled print button', (
      tester,
    ) async {
      await pumpApp(tester);
      await openTab(tester, 'Gambar');

      expect(find.text('Cetak foto dari galeri.'), findsOneWidget);
      expect(
        find.widgetWithText(AppButton, 'Pilih dari galeri'),
        findsOneWidget,
      );

      // Nothing picked and no printer paired, so printing stays off.
      final print = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Cetak gambar'),
      );
      expect(print.onPressed, isNull);
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
