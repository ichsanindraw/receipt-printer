import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_printer/models/printer_settings.dart';
import 'package:receipt_printer/screens/printer_settings_screen.dart';
import 'package:receipt_printer/services/thermal_printer_service.dart';
import 'package:receipt_printer/theme/app_theme.dart';
import 'package:receipt_printer/widgets/app_button.dart';

/// Stands in for the Bluetooth stack, which needs real hardware.
class FakeThermalPrinterService implements ThermalPrinterService {
  FakeThermalPrinterService({
    this.devices = const [],
    this.failure,
    this.supported = true,
  });

  final List<PrinterDevice> devices;
  final String? failure;
  final bool supported;

  int printCalls = 0;
  int lastCopies = 0;
  String? lastAddress;

  @override
  bool get isSupported => supported;

  @override
  Future<bool> isReady() async => supported;

  @override
  Future<List<PrinterDevice>> discoverDevices() async {
    if (failure != null) throw ThermalPrinterException(failure!);
    return devices;
  }

  @override
  Future<void> printBytes(
    List<int> bytes, {
    required String address,
    int copies = 1,
  }) async {
    if (failure != null) throw ThermalPrinterException(failure!);
    printCalls++;
    lastAddress = address;
    lastCopies = copies;
  }

  @override
  Future<void> disconnect() async {}
}

void main() {
  Future<PrinterSettings> pumpScreen(
    WidgetTester tester, {
    required ThermalPrinterService service,
    PrinterSettings settings = const PrinterSettings(),
  }) async {
    var latest = settings;
    await tester.binding.setSurfaceSize(const Size(900, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: PrinterSettingsScreen(
          settings: settings,
          printerService: service,
          onChanged: (value) => latest = value,
        ),
      ),
    );
    await tester.pump();
    return latest;
  }

  const found = [
    PrinterDevice(name: 'RPP02N', address: '66:02:BD:06:18:7B'),
    PrinterDevice(name: 'Panda PRJ', address: 'AA:BB:CC:DD:EE:FF'),
  ];

  testWidgets('scanning lists the discovered printers', (tester) async {
    await pumpScreen(
      tester,
      service: FakeThermalPrinterService(devices: found),
    );

    await tester.tap(find.widgetWithText(AppButton, 'Cari printer'));
    await tester.pumpAndSettle();

    expect(find.text('RPP02N'), findsOneWidget);
    expect(find.text('66:02:BD:06:18:7B'), findsOneWidget);
    expect(find.text('Panda PRJ'), findsOneWidget);
  });

  testWidgets('an empty scan explains what to do next', (tester) async {
    await pumpScreen(tester, service: FakeThermalPrinterService());

    await tester.tap(find.widgetWithText(AppButton, 'Cari printer'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Tidak ada perangkat'), findsOneWidget);
  });

  testWidgets('a scan failure surfaces the printer error', (tester) async {
    await pumpScreen(
      tester,
      service: FakeThermalPrinterService(failure: 'Bluetooth mati.'),
    );

    await tester.tap(find.widgetWithText(AppButton, 'Cari printer'));
    await tester.pumpAndSettle();

    expect(find.text('Bluetooth mati.'), findsOneWidget);
  });

  testWidgets('picking a printer reports it to the parent', (tester) async {
    var saved = const PrinterSettings();
    await tester.binding.setSurfaceSize(const Size(900, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: PrinterSettingsScreen(
          settings: const PrinterSettings(),
          printerService: FakeThermalPrinterService(devices: found),
          onChanged: (value) => saved = value,
        ),
      ),
    );

    await tester.tap(find.widgetWithText(AppButton, 'Cari printer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RPP02N'));
    await tester.pumpAndSettle();

    expect(saved.hasDevice, isTrue);
    expect(saved.deviceName, 'RPP02N');
    expect(saved.deviceAddress, '66:02:BD:06:18:7B');
    // The picker collapses once a device is chosen.
    expect(find.text('Panda PRJ'), findsNothing);
    expect(find.text('TERPILIH'), findsOneWidget);
  });

  testWidgets('paper width and copies are reported to the parent', (
    tester,
  ) async {
    var saved = const PrinterSettings();
    await tester.binding.setSurfaceSize(const Size(900, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: PrinterSettingsScreen(
          settings: const PrinterSettings(),
          printerService: FakeThermalPrinterService(),
          onChanged: (value) => saved = value,
        ),
      ),
    );

    await tester.tap(find.text('58 mm'));
    await tester.pumpAndSettle();
    expect(saved.paperWidth, PaperWidth.mm58);

    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
    expect(saved.copies, 3);
  });

  testWidgets('test print is disabled until a printer is paired', (
    tester,
  ) async {
    await pumpScreen(tester, service: FakeThermalPrinterService());

    final button = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Tes cetak'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('test print sends one copy to the paired printer', (
    tester,
  ) async {
    final service = FakeThermalPrinterService();
    await pumpScreen(
      tester,
      service: service,
      settings: const PrinterSettings(
        deviceName: 'RPP02N',
        deviceAddress: '66:02:BD:06:18:7B',
        copies: 3,
      ),
    );

    await tester.tap(find.widgetWithText(AppButton, 'Tes cetak'));
    await tester.pump();
    // Building ESC/POS bytes loads a real capability profile asset, and the
    // busy spinner never goes quiet, so let real async run instead of
    // pumpAndSettle.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();

    expect(service.printCalls, 1);
    expect(service.lastAddress, '66:02:BD:06:18:7B');
    expect(service.lastCopies, 1, reason: 'a test is always a single copy');
  });

  testWidgets('web build explains that Bluetooth is unavailable', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      service: FakeThermalPrinterService(supported: false),
    );

    expect(find.textContaining('hanya tersedia di Android'), findsOneWidget);
    final scan = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Cari printer'),
    );
    expect(scan.onPressed, isNull);
  });
}
