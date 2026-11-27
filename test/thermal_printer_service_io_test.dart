import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_printer/models/printer_settings.dart';
import 'package:receipt_printer/services/thermal_printer_service.dart';
import 'package:receipt_printer/services/thermal_printer_service_io.dart';

/// Stands in for the Bluetooth plugin, which only talks to real hardware
/// (and answers `false` outright on Linux, where CI runs).
///
/// [connectResults] is consumed one value per `connect` call, so a test can
/// script "fails once, then succeeds"; the last value repeats.
class FakeBluetoothPrinterPlugin extends BluetoothPrinterPlugin {
  FakeBluetoothPrinterPlugin({required this.connectResults});

  final List<bool> connectResults;
  int connectCalls = 0;
  final List<List<int>> written = [];

  @override
  Future<bool> isPermissionGranted() async => true;

  @override
  Future<bool> isBluetoothEnabled() async => true;

  @override
  Future<List<PrinterDevice>> pairedDevices() async => const [];

  @override
  Future<bool> isConnected() async => true;

  @override
  Future<bool> connect(String address) async {
    final index = connectCalls < connectResults.length
        ? connectCalls
        : connectResults.length - 1;
    connectCalls++;
    return connectResults[index];
  }

  @override
  Future<bool> writeBytes(List<int> bytes) async {
    written.add(bytes);
    return true;
  }

  @override
  Future<bool> disconnect() async => true;
}

void main() {
  IoThermalPrinterService serviceWith(FakeBluetoothPrinterPlugin plugin) =>
      IoThermalPrinterService(plugin: plugin, supported: true);

  test('a first connect that fails is retried automatically, so the very '
      'first print still goes through without a separate test print', () async {
    // Regression: Android's classic Bluetooth socket routinely fails the
    // very first connect to an otherwise healthy, paired printer. Without
    // a retry, this made the first "Cetak resi" after picking a printer
    // fail outright, and only a subsequent attempt (e.g. "Tes cetak")
    // would succeed.
    final plugin = FakeBluetoothPrinterPlugin(connectResults: [false, true]);

    await serviceWith(
      plugin,
    ).printBytes([1, 2, 3], address: '00:11:22:33:44:55');

    expect(plugin.connectCalls, 2);
    expect(plugin.written, [
      [1, 2, 3],
    ]);
  });

  test('a connect that fails every attempt still surfaces an error', () async {
    final plugin = FakeBluetoothPrinterPlugin(connectResults: [false]);

    await expectLater(
      () => serviceWith(
        plugin,
      ).printBytes([1, 2, 3], address: '00:11:22:33:44:55'),
      throwsA(
        isA<ThermalPrinterException>().having(
          (error) => error.message,
          'message',
          contains('Tidak bisa terhubung'),
        ),
      ),
    );
    expect(plugin.connectCalls, 2);
    expect(plugin.written, isEmpty);
  });

  test('a connect that succeeds first try is not retried', () async {
    final plugin = FakeBluetoothPrinterPlugin(connectResults: [true]);

    await serviceWith(
      plugin,
    ).printBytes([1, 2, 3], address: '00:11:22:33:44:55');

    expect(plugin.connectCalls, 1);
  });

  test('an unsupported platform refuses to print', () async {
    final plugin = FakeBluetoothPrinterPlugin(connectResults: [true]);
    final service = IoThermalPrinterService(plugin: plugin, supported: false);

    await expectLater(
      () => service.printBytes([1], address: '00:11:22:33:44:55'),
      throwsA(isA<ThermalPrinterException>()),
    );
    expect(plugin.connectCalls, 0);
  });
}
