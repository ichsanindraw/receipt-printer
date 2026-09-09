import 'package:receipt_printer/models/printer_settings.dart';
import 'package:receipt_printer/services/thermal_printer_service.dart';

/// Stands in for the Bluetooth stack, which needs real hardware.
///
/// Also pins down `isSupported`, which the real implementation derives from
/// `Platform`. Without that, screen tests pass on macOS and fail on a Linux
/// CI runner because the two take different branches.
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
  List<int>? lastBytes;

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
    lastBytes = bytes;
  }

  @override
  Future<void> disconnect() async {}
}
