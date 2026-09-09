import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_printer/models/printer_settings.dart';

void main() {
  group('PrinterSettings', () {
    test('defaults to 80 mm, one copy, cut enabled and no device', () {
      const settings = PrinterSettings();

      expect(settings.hasDevice, isFalse);
      expect(settings.paperWidth, PaperWidth.mm80);
      expect(settings.copies, 1);
      expect(settings.cutPaper, isTrue);
    });

    test('survives a JSON round trip', () {
      const settings = PrinterSettings(
        deviceName: 'RPP02N',
        deviceAddress: '66:02:BD:06:18:7B',
        paperWidth: PaperWidth.mm58,
        copies: 2,
        cutPaper: false,
      );

      final restored = PrinterSettings.decode(settings.encode());

      expect(restored.deviceName, 'RPP02N');
      expect(restored.deviceAddress, '66:02:BD:06:18:7B');
      expect(restored.paperWidth, PaperWidth.mm58);
      expect(restored.copies, 2);
      expect(restored.cutPaper, isFalse);
      expect(restored.hasDevice, isTrue);
    });

    test('withoutDevice drops the printer but keeps the preferences', () {
      const settings = PrinterSettings(
        deviceName: 'RPP02N',
        deviceAddress: '66:02:BD:06:18:7B',
        paperWidth: PaperWidth.mm58,
        copies: 3,
        cutPaper: false,
      );

      final cleared = settings.withoutDevice();

      expect(cleared.hasDevice, isFalse);
      expect(cleared.deviceAddress, isNull);
      expect(cleared.paperWidth, PaperWidth.mm58);
      expect(cleared.copies, 3);
      expect(cleared.cutPaper, isFalse);
    });

    test('an empty address does not count as a paired device', () {
      const settings = PrinterSettings(deviceName: 'x', deviceAddress: '');
      expect(settings.hasDevice, isFalse);
    });

    test('malformed stored settings fall back to defaults', () {
      // Bad preferences must never stop the app from starting.
      for (final raw in [null, '', 'not json', '[]', '{"copies": "many"}']) {
        expect(
          () => PrinterSettings.decode(raw),
          returnsNormally,
          reason: 'input: $raw',
        );
        expect(PrinterSettings.decode(raw).paperWidth, PaperWidth.mm80);
      }
    });

    test('an unknown paper width falls back to 80 mm', () {
      expect(PaperWidth.fromName('mm112'), PaperWidth.mm80);
      expect(PaperWidth.fromName(null), PaperWidth.mm80);
      expect(PaperWidth.fromName('mm58'), PaperWidth.mm58);
    });

    test('copies are clamped to a sane range when decoded', () {
      expect(PrinterSettings.decode('{"copies": 99}').copies, 5);
      expect(PrinterSettings.decode('{"copies": 0}').copies, 1);
    });
  });

  group('PrinterDevice', () {
    test('falls back to the address when the name is blank', () {
      const unnamed = PrinterDevice(name: '  ', address: 'AA:BB:CC');
      expect(unnamed.displayName, 'AA:BB:CC');

      const named = PrinterDevice(name: ' RPP02N ', address: 'AA:BB:CC');
      expect(named.displayName, 'RPP02N');
    });
  });
}
