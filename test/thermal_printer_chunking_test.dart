import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_printer/services/thermal_printer_service_io.dart';

void main() {
  List<int> job(int length) => List<int>.generate(length, (i) => i % 256);

  test('chunks join back into exactly the original job', () {
    for (final length in [0, 1, 511, 512, 513, 4096, 70000]) {
      final bytes = job(length);
      final rejoined = [
        for (final part in IoThermalPrinterService.chunk(bytes)) ...part,
      ];
      expect(rejoined, bytes, reason: 'round trip failed at $length bytes');
    }
  });

  test('no chunk exceeds the write size and only the last is short', () {
    final parts = IoThermalPrinterService.chunk(job(1300), 512).toList();

    expect(parts.map((p) => p.length), [512, 512, 276]);
    expect(parts.every((p) => p.length <= 512), isTrue);
  });

  test('an empty job produces no writes', () {
    expect(IoThermalPrinterService.chunk(const []), isEmpty);
  });

  test('a job shorter than one chunk is a single write', () {
    expect(IoThermalPrinterService.chunk(job(10), 512).toList(), [job(10)]);
  });
}
