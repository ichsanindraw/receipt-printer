import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

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
      await _write(bytes);
    }
  }

  /// Bytes per Bluetooth write, and the pause between them.
  ///
  /// A receipt is about a kilobyte, but a full-width image is tens of
  /// kilobytes, and handing that to the printer in one write overruns its
  /// buffer: it prints the top of the picture and silently drops the rest.
  /// 512 bytes every 20 ms is roughly 25 kB/s, comfortably under the speed
  /// the head can actually put on paper, so the buffer never runs ahead.
  static const int _chunkBytes = 512;
  static const Duration _chunkPause = Duration(milliseconds: 20);

  /// Pause before retrying a failed connect, and how many extra attempts
  /// beyond the first are worth making.
  ///
  /// The very first `connect()` to a printer that is on, paired, and in
  /// range routinely fails on Android's classic Bluetooth socket — not
  /// because anything is actually wrong — and a second attempt right after
  /// succeeds. Without a retry here, that meant the very first "Cetak resi"
  /// after picking a printer always failed, and only worked once "Tes
  /// cetak" (or another failed print) had already burned through that first
  /// bad attempt.
  static const Duration _reconnectPause = Duration(milliseconds: 400);
  static const int _connectAttempts = 2;

  /// Splits a job into writes. Pure and exposed so the split can be tested:
  /// a bug here would silently corrupt every print.
  @visibleForTesting
  static Iterable<List<int>> chunk(
    List<int> bytes, [
    int size = _chunkBytes,
  ]) sync* {
    if (bytes.isEmpty) return;
    for (var offset = 0; offset < bytes.length; offset += size) {
      yield bytes.sublist(offset, math.min(offset + size, bytes.length));
    }
  }

  Future<void> _write(List<int> bytes) async {
    var written = 0;
    for (final part in chunk(bytes)) {
      final sent = await PrintBluetoothThermal.writeBytes(part);
      if (!sent) {
        // The link is unreliable once a write fails; force a fresh connect.
        _connectedAddress = null;
        throw const ThermalPrinterException(
          'Gagal mengirim data ke printer. Coba hubungkan ulang.',
        );
      }
      written += part.length;
      if (written < bytes.length) await Future<void>.delayed(_chunkPause);
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

    var connected = false;
    for (var attempt = 1; attempt <= _connectAttempts; attempt++) {
      connected = await PrintBluetoothThermal.connect(
        macPrinterAddress: address,
      );
      if (connected || attempt == _connectAttempts) break;
      await Future<void>.delayed(_reconnectPause);
    }
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
