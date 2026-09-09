import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_printer/models/printer_settings.dart';
import 'package:receipt_printer/screens/print_image_screen.dart';
import 'package:receipt_printer/services/thermal_printer_service.dart';
import 'package:receipt_printer/theme/app_theme.dart';
import 'package:receipt_printer/widgets/app_button.dart';

import 'support/fake_thermal_printer_service.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    required ThermalPrinterService service,
    PrinterSettings settings = const PrinterSettings(),
  }) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: PrintImageScreen(
            printerService: service,
            printerSettings: settings,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  const paired = PrinterSettings(
    deviceName: 'RPP02N',
    deviceAddress: '66:02:BD:06:18:7B',
  );

  testWidgets('offers the gallery picker', (tester) async {
    await pumpScreen(tester, service: FakeThermalPrinterService());

    expect(find.widgetWithText(AppButton, 'Pilih dari galeri'), findsOneWidget);
  });

  testWidgets('printing stays off until an image is picked', (tester) async {
    await pumpScreen(
      tester,
      service: FakeThermalPrinterService(),
      settings: paired,
    );

    final button = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Cetak gambar'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('asks for a printer when none is paired', (tester) async {
    await pumpScreen(tester, service: FakeThermalPrinterService());

    expect(find.textContaining('Pilih printer dulu'), findsOneWidget);
  });

  testWidgets('says so when the platform has no Bluetooth', (tester) async {
    await pumpScreen(
      tester,
      service: FakeThermalPrinterService(supported: false),
      settings: paired,
    );

    expect(find.textContaining('tidak tersedia di web'), findsOneWidget);
  });

  testWidgets('shows the paper width the image will be sized for', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      service: FakeThermalPrinterService(),
      settings: paired.copyWith(paperWidth: PaperWidth.mm58),
    );

    expect(find.text('58 MM'), findsOneWidget);
  });
}
