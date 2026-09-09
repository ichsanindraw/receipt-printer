import '../models/printer_settings.dart';

// The Bluetooth plugin is mobile/desktop only — it imports dart:io and
// declares no web platform — so the implementation is swapped at compile time
// and web gets a stub that reports the feature as unsupported.
import 'thermal_printer_service_unsupported.dart'
    if (dart.library.io) 'thermal_printer_service_io.dart'
    as impl;

class ThermalPrinterException implements Exception {
  const ThermalPrinterException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Talks ESC/POS to a Bluetooth thermal printer.
abstract class ThermalPrinterService {
  /// False on web, where there is no Bluetooth plugin at all.
  bool get isSupported;

  /// Permission granted and the Bluetooth adapter switched on.
  Future<bool> isReady();

  /// Android lists paired devices — pair in system settings first. iOS lists
  /// nearby BLE devices, since iOS has no pairing step for these printers.
  Future<List<PrinterDevice>> discoverDevices();

  /// Connects if needed, then sends [bytes] once per copy.
  Future<void> printBytes(
    List<int> bytes, {
    required String address,
    int copies = 1,
  });

  Future<void> disconnect();
}

ThermalPrinterService createThermalPrinterService() =>
    impl.createThermalPrinterService();
