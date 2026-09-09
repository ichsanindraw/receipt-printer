import 'dart:convert';

/// Receipt paper width. Also picked up by the ESC/POS generator, which needs
/// to know how many characters fit on a line.
enum PaperWidth {
  mm58(58, '58 mm'),
  mm80(80, 'Kertas 80 mm');

  const PaperWidth(this.millimetres, this.label);

  final int millimetres;
  final String label;

  static PaperWidth fromName(String? name) => values.firstWhere(
    (value) => value.name == name,
    orElse: () => PaperWidth.mm80,
  );
}

/// A saved thermal printer, plus how to print to it.
class PrinterSettings {
  const PrinterSettings({
    this.deviceName,
    this.deviceAddress,
    this.paperWidth = PaperWidth.mm80,
    this.copies = 1,
    this.cutPaper = true,
  });

  final String? deviceName;

  /// MAC address on Android, BLE identifier on iOS.
  final String? deviceAddress;

  final PaperWidth paperWidth;
  final int copies;

  /// Send the cut command after the receipt. Printers without a cutter ignore
  /// it, but some older ones misbehave, so it can be turned off.
  final bool cutPaper;

  bool get hasDevice => deviceAddress != null && deviceAddress!.isNotEmpty;

  PrinterSettings copyWith({
    String? deviceName,
    String? deviceAddress,
    PaperWidth? paperWidth,
    int? copies,
    bool? cutPaper,
  }) {
    return PrinterSettings(
      deviceName: deviceName ?? this.deviceName,
      deviceAddress: deviceAddress ?? this.deviceAddress,
      paperWidth: paperWidth ?? this.paperWidth,
      copies: copies ?? this.copies,
      cutPaper: cutPaper ?? this.cutPaper,
    );
  }

  /// Drops the paired device but keeps the paper and copy preferences.
  PrinterSettings withoutDevice() => PrinterSettings(
    paperWidth: paperWidth,
    copies: copies,
    cutPaper: cutPaper,
  );

  Map<String, dynamic> toJson() => {
    'deviceName': deviceName,
    'deviceAddress': deviceAddress,
    'paperWidth': paperWidth.name,
    'copies': copies,
    'cutPaper': cutPaper,
  };

  factory PrinterSettings.fromJson(Map<String, dynamic> json) {
    return PrinterSettings(
      deviceName: json['deviceName'] as String?,
      deviceAddress: json['deviceAddress'] as String?,
      paperWidth: PaperWidth.fromName(json['paperWidth'] as String?),
      copies: (json['copies'] as num?)?.toInt().clamp(1, 5) ?? 1,
      cutPaper: json['cutPaper'] as bool? ?? true,
    );
  }

  String encode() => jsonEncode(toJson());

  /// Returns defaults for malformed or missing input rather than throwing —
  /// bad stored preferences must never stop the app from starting.
  static PrinterSettings decode(String? raw) {
    if (raw == null || raw.isEmpty) return const PrinterSettings();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const PrinterSettings();
      return PrinterSettings.fromJson(decoded);
    } catch (_) {
      return const PrinterSettings();
    }
  }
}

/// A Bluetooth device offered in the picker.
class PrinterDevice {
  const PrinterDevice({required this.name, required this.address});

  final String name;
  final String address;

  String get displayName => name.trim().isEmpty ? address : name.trim();
}
