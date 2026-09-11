import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_printer/services/thermal_printer_service.dart';
import 'package:receipt_printer/services/thermal_printer_service_io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('groons.web.app/print');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  /// Stubs the native plugin channel `IoThermalPrinterService` talks to.
  /// `connectResults` is consumed one value per `connect` call, so a test
  /// can script "fails once, then succeeds" without touching real Bluetooth.
  void stubChannel({required List<bool> connectResults}) {
    var connectCall = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'ispermissionbluetoothgranted':
        case 'bluetoothenabled':
        case 'connectionstatus':
        case 'writebytes':
          return true;
        case 'connect':
          final result = connectResults[connectCall];
          connectCall = (connectCall + 1).clamp(0, connectResults.length - 1);
          return result;
        case 'disconnect':
          return true;
        default:
          return null;
      }
    });
  }

  test(
    'a first connect that fails is retried automatically, so the very '
    'first print still goes through without a separate test print',
    () async {
      // Regression: Android's classic Bluetooth socket routinely fails the
      // very first connect to an otherwise healthy, paired printer. Without
      // a retry, this made the first "Cetak resi" after picking a printer
      // fail outright, and only a subsequent attempt (e.g. "Tes cetak")
      // would succeed.
      stubChannel(connectResults: [false, true]);
      final service = IoThermalPrinterService();

      await service.printBytes(
        [1, 2, 3],
        address: '00:11:22:33:44:55',
      );
      // No exception means the retry rescued the first failed connect.
    },
  );

  test('a connect that fails every attempt still surfaces an error', () async {
    stubChannel(connectResults: [false, false]);
    final service = IoThermalPrinterService();

    await expectLater(
      () => service.printBytes([1, 2, 3], address: '00:11:22:33:44:55'),
      throwsA(isA<ThermalPrinterException>()),
    );
  });

  test('a connect that succeeds first try is not retried', () async {
    var connectCalls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'ispermissionbluetoothgranted':
        case 'bluetoothenabled':
        case 'connectionstatus':
        case 'writebytes':
          return true;
        case 'connect':
          connectCalls++;
          return true;
        default:
          return null;
      }
    });

    final service = IoThermalPrinterService();
    await service.printBytes([1, 2, 3], address: '00:11:22:33:44:55');

    expect(connectCalls, 1);
  });
}
