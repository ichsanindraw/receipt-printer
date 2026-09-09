import 'dart:io';

import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../models/printer_settings.dart';
import 'thermal_printer_service.dart';

/// Bluetooth ESC/POS over [PrintBluetoothThermal].
class IoThermalPrinterService implements ThermalPrinterService {
  IoThermalPrinterService();

  /// The plugin can say whether *a* connection is open but not to which
  /// device, so the address is tracked here to detect a switch of printer.
  String? _connectedAddress;

  @override
  bool get isSupported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  @override
  Future<bool> isReady() async {
    if (!isSupported) return false;
    if (!await PrintBluetoothThermal.isPermissionBluetoothGranted) return false;
    return PrintBluetoothThermal.bluetoothEnabled;
  }

  @override
  Future<List<PrinterDevice>> discoverDevices() async {
    if (!isSupported) {
      throw const ThermalPrinterException(
        'Platform ini belum mendukung printer Bluetooth.',
      );
    }

    await _ensurePermission();

    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      throw const ThermalPrinterException(
        'Bluetooth mati. Nyalakan dulu, lalu coba lagi.',
      );
    }

    final devices = await PrintBluetoothThermal.pairedBluetooths;
    return devices
        .map(
          (device) =>
              PrinterDevice(name: device.name, address: device.macAdress),
        )
        .toList(growable: false);
  }

  @override
  Future<void> printBytes(
    List<int> bytes, {
    required String address,
    int copies = 1,
  }) async {
    if (!isSupported) {
      throw const ThermalPrinterException(
        'Platform ini belum mendukung printer Bluetooth.',
      );
    }

    await _ensurePermission();
    await _ensureConnected(address);

    for (var copy = 0; copy < copies; copy++) {
      final sent = await PrintBluetoothThermal.writeBytes(bytes);
      if (!sent) {
        // The link is unreliable once a write fails; force a fresh connect.
        _connectedAddress = null;
        throw const ThermalPrinterException(
          'Gagal mengirim data ke printer. Coba hubungkan ulang.',
        );
      }
    }
  }

  /// Best-effort cleanup — called from dispose, so it must never throw.
  @override
  Future<void> disconnect() async {
    _connectedAddress = null;
    if (!isSupported) return;
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {
      // Nothing useful to do if the channel is already gone.
    }
  }

  /// Android 12+ gates Bluetooth behind runtime permissions.
  Future<void> _ensurePermission() async {
    if (Platform.isAndroid) {
      final statuses = await [
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
      ].request();
      final denied = statuses.values.any((status) => !status.isGranted);
      if (denied) {
        throw const ThermalPrinterException(
          'Izin Bluetooth ditolak. Aktifkan di pengaturan aplikasi.',
        );
      }
      return;
    }

    if (!await PrintBluetoothThermal.isPermissionBluetoothGranted) {
      throw const ThermalPrinterException(
        'Izin Bluetooth belum diberikan. Aktifkan di pengaturan aplikasi.',
      );
    }
  }

  Future<void> _ensureConnected(String address) async {
    if (_connectedAddress == address &&
        await PrintBluetoothThermal.connectionStatus) {
      return;
    }

    // Drop a connection to a different printer before opening a new one.
    if (_connectedAddress != null) {
      await PrintBluetoothThermal.disconnect;
      _connectedAddress = null;
    }

    final connected = await PrintBluetoothThermal.connect(
      macPrinterAddress: address,
    );
    if (!connected) {
      throw const ThermalPrinterException(
        'Tidak bisa terhubung ke printer. Pastikan printer menyala dan '
        'sudah dipasangkan.',
      );
    }
    _connectedAddress = address;
  }
}

ThermalPrinterService createThermalPrinterService() =>
    IoThermalPrinterService();
