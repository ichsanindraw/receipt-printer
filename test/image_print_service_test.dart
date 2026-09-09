import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:receipt_printer/models/printer_settings.dart';
import 'package:receipt_printer/services/image_print_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const service = ImagePrintService();

  /// A smooth grey ramp — the case plain thresholding destroys and dithering
  /// preserves.
  img.Image gradient({int width = 200, int height = 120}) {
    final image = img.Image(width: width, height: height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final value = (x / (width - 1) * 255).round();
        image.setPixelRgb(x, y, value, value, value);
      }
    }
    return image;
  }

  test('print head widths match the paper', () {
    expect(ImagePrintService.dotsFor(PaperWidth.mm80), 576);
    expect(ImagePrintService.dotsFor(PaperWidth.mm58), 384);
  });

  test('scales the picture to the print head width', () async {
    for (final paper in PaperWidth.values) {
      final prepared = await ImagePrintService.prepare(
        img.encodePng(gradient()),
        paper,
      );
      expect(prepared, isNotNull);
      expect(prepared!.width, ImagePrintService.dotsFor(paper));
    }
  });

  test('reduces the picture to pure black and white', () async {
    final prepared = await ImagePrintService.prepare(
      img.encodePng(gradient()),
      PaperWidth.mm80,
    );
    final decoded = img.decodePng(prepared!.pngBytes)!;

    final values = <int>{};
    for (var y = 0; y < decoded.height; y += 7) {
      for (var x = 0; x < decoded.width; x += 7) {
        values.add(decoded.getPixel(x, y).r.toInt());
      }
    }
    expect(values, everyElement(anyOf(0, 255)));
  });

  test('dithering preserves the gradient as varying dot density', () async {
    // Thresholding would give a hard 50/50 split: all black then all white.
    // Dithering should instead darken progressively across the width.
    final prepared = await ImagePrintService.prepare(
      img.encodePng(gradient()),
      PaperWidth.mm80,
    );
    final decoded = img.decodePng(prepared!.pngBytes)!;

    double inkAcross(int fromX, int toX) {
      var dark = 0;
      var total = 0;
      for (var y = 0; y < decoded.height; y++) {
        for (var x = fromX; x < toX; x++) {
          if (decoded.getPixel(x, y).r < 128) dark++;
          total++;
        }
      }
      return dark / total;
    }

    final quarter = decoded.width ~/ 4;
    final first = inkAcross(0, quarter);
    final second = inkAcross(quarter, quarter * 2);
    final third = inkAcross(quarter * 2, quarter * 3);

    expect(first, greaterThan(second));
    expect(second, greaterThan(third));
    // A mid-tone band must be a mix, not fully on or off.
    expect(second, inInclusiveRange(0.2, 0.8));
  });

  test('caps how much paper one picture can use', () async {
    final tall = img.Image(width: 100, height: 4000);
    final prepared = await ImagePrintService.prepare(
      img.encodePng(tall),
      PaperWidth.mm80,
    );

    expect(prepared!.height, ImagePrintService.maxHeightDots);
    expect(prepared.millimetresLong, closeTo(175, 2));
  });

  test('rejects bytes that are not an image', () async {
    expect(
      await ImagePrintService.prepare(
        Uint8List.fromList([1, 2, 3, 4]),
        PaperWidth.mm80,
      ),
      isNull,
    );
  });

  test('builds an ESC/POS raster job', () async {
    final prepared = await ImagePrintService.prepare(
      img.encodePng(gradient()),
      PaperWidth.mm80,
    );
    final bytes = await service.build(prepared!);

    expect(bytes.take(2), orderedEquals([0x1B, 0x40]), reason: 'ESC @ first');
    expect(bytes.length, greaterThan(prepared.width * prepared.height ~/ 8));

    const cut = [0x1D, 0x56];
    bool hasCut(List<int> b) {
      for (var i = 0; i < b.length - 1; i++) {
        if (b[i] == cut[0] && b[i + 1] == cut[1]) return true;
      }
      return false;
    }

    expect(hasCut(bytes), isTrue);
    expect(hasCut(await service.build(prepared, cutPaper: false)), isFalse);
  });
}
