import '../models/printer_settings.dart';
import 'thermal_printer_service.dart';

/// Web build: no Bluetooth plugin. The receipt tab falls back to the browser
/// print dialog, so nothing here should ever be reached.
class UnsupportedThermalPrinterService implements ThermalPrinterService {
  const UnsupportedThermalPrinterService();

  static const _message =
      'Printer Bluetooth tidak tersedia di web. Gunakan dialog cetak browser.';

  @override
  bool get isSupported => false;

  @override
  Future<bool> isReady() async => false;

  @override
  Future<List<PrinterDevice>> discoverDevices() async =>
      throw const ThermalPrinterException(_message);

  @override
  Future<void> printBytes(
    List<int> bytes, {
    required String address,
    int copies = 1,
  }) async => throw const ThermalPrinterException(_message);

  @override
  Future<void> disconnect() async {}
}

ThermalPrinterService createThermalPrinterService() =>
    const UnsupportedThermalPrinterService();
