import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/printer_settings.dart';

/// An image converted to exactly what the printer will put on paper.
class PreparedImage {
  const PreparedImage({
    required this.pngBytes,
    required this.width,
    required this.height,
  });

  /// Black-and-white PNG — shown as the preview *and* rasterised for the
  /// printer, so what you see is what comes out.
  final Uint8List pngBytes;

  final int width;
  final int height;

  /// Roughly how much paper this uses, at the usual 203 dpi.
  double get millimetresLong => height / 203 * 25.4;
}

/// Prints a picture from the gallery on the thermal printer.
///
/// Thermal printers are one bit per dot: a pixel is burned or it is not.
/// Plain thresholding turns a photo into blotches, so the image is
/// Floyd–Steinberg dithered first, which trades spatial resolution for
/// apparent greys and keeps photographs readable.
class ImagePrintService {
  const ImagePrintService();

  /// Print head width in dots. 80 mm heads are 576 dots, 58 mm are 384.
  static int dotsFor(PaperWidth paper) => paper == PaperWidth.mm58 ? 384 : 576;

  /// Caps the paper a single picture can use — about 175 mm at 203 dpi.
  static const int maxHeightDots = 1400;

  /// Decoding and dithering a full-size photo takes long enough to drop
  /// frames, so it runs off the UI isolate.
  static Future<PreparedImage?> prepare(Uint8List source, PaperWidth paper) =>
      compute(_prepare, (source, dotsFor(paper)));

  Future<List<int>> build(
    PreparedImage prepared, {
    bool cutPaper = true,
  }) async {
    img.Image? decoded;
    try {
      decoded = img.decodePng(prepared.pngBytes);
    } catch (_) {
      decoded = null;
    }
    if (decoded == null) {
      throw const ImagePrintException('Gambar tidak bisa dibaca.');
    }

    final profile = await CapabilityProfile.load();
    final generator = Generator(
      prepared.width > 400 ? PaperSize.mm80 : PaperSize.mm58,
      profile,
    );

    return [
      ...generator.reset(),
      ...generator.imageRaster(decoded, align: PosAlign.center),
      ...generator.feed(2),
      if (cutPaper) ...generator.cut(),
    ];
  }
}

class ImagePrintException implements Exception {
  const ImagePrintException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Runs in a background isolate; must stay top level.
PreparedImage? _prepare((Uint8List, int) request) {
  final (source, targetWidth) = request;

  // decodeImage sniffs formats and some decoders throw on short or corrupt
  // input rather than declining, so a bad pick must not take down the isolate.
  img.Image? decoded;
  try {
    decoded = img.decodeImage(source);
  } catch (_) {
    return null;
  }
  if (decoded == null) return null;

  // Fit the print head exactly, then cap the length.
  var resized = img.copyResize(
    decoded,
    width: targetWidth,
    interpolation: img.Interpolation.average,
  );
  if (resized.height > ImagePrintService.maxHeightDots) {
    resized = img.copyCrop(
      resized,
      x: 0,
      y: 0,
      width: resized.width,
      height: ImagePrintService.maxHeightDots,
    );
  }

  final dithered = _floydSteinberg(img.grayscale(resized));

  return PreparedImage(
    pngBytes: img.encodePng(dithered),
    width: dithered.width,
    height: dithered.height,
  );
}

/// Floyd–Steinberg error diffusion down to pure black and white.
img.Image _floydSteinberg(img.Image gray) {
  final width = gray.width;
  final height = gray.height;

  // Errors accumulate beyond 0..255, so carry the work in doubles.
  final level = Float64List(width * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      level[y * width + x] = gray.getPixel(x, y).r.toDouble();
    }
  }

  void diffuse(int x, int y, double error, double factor) {
    if (x < 0 || x >= width || y >= height) return;
    level[y * width + x] += error * factor;
  }

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final index = y * width + x;
      final old = level[index];
      final quantised = old < 128 ? 0.0 : 255.0;
      level[index] = quantised;

      final error = old - quantised;
      diffuse(x + 1, y, error, 7 / 16);
      diffuse(x - 1, y + 1, error, 3 / 16);
      diffuse(x, y + 1, error, 5 / 16);
      diffuse(x + 1, y + 1, error, 1 / 16);
    }
  }

  final out = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final value = level[y * width + x].round().clamp(0, 255);
      out.setPixelRgb(x, y, value, value, value);
    }
  }
  return out;
}
