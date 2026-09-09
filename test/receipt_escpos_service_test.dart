import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_printer/models/printer_settings.dart';
import 'package:receipt_printer/models/receipt.dart';
import 'package:receipt_printer/services/receipt_escpos_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const service = ReceiptEscPosService();

  Receipt receipt({double? lat, double? lng}) => Receipt(
    number: 'RCP-20260910-1432',
    from: 'Ichsan',
    to: 'Budi',
    phone: '081234567890',
    productName: 'Espresso Machine',
    address: 'Jl. Sudirman No. 1, Jakarta',
    latitude: lat,
    longitude: lng,
    issuedAt: DateTime(2026, 9, 10, 14, 32),
  );

  /// ESC/POS is a byte stream, so assert on the readable text it carries.
  String textOf(List<int> bytes) =>
      String.fromCharCodes(bytes.where((b) => b >= 32 && b < 127));

  int indexOfText(List<int> bytes, String text) {
    final needle = text.codeUnits;
    outer:
    for (var i = 0; i <= bytes.length - needle.length; i++) {
      for (var j = 0; j < needle.length; j++) {
        if (bytes[i + j] != needle[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  /// The `GS ! n` in force when [text] is printed. The low nibble of n is the
  /// height multiplier - 1, the high nibble the width multiplier - 1.
  int sizeByteFor(List<int> bytes, String text) {
    final end = indexOfText(bytes, text);
    expect(end, greaterThan(-1), reason: '"$text" is not in the output');
    var size = 0;
    for (var i = 0; i + 2 < end; i++) {
      if (bytes[i] == 0x1D && bytes[i + 1] == 0x21) size = bytes[i + 2];
    }
    return size;
  }

  int heightMultiplier(int sizeByte) => (sizeByte & 0x0F) + 1;
  int widthMultiplier(int sizeByte) => ((sizeByte >> 4) & 0x0F) + 1;

  /// The `ESC M n` font in force when [text] is printed: 0 is font A, 1 is
  /// the smaller font B.
  int fontFor(List<int> bytes, String text) {
    final end = indexOfText(bytes, text);
    expect(end, greaterThan(-1), reason: '"$text" is not in the output');
    var font = 0;
    for (var i = 0; i + 2 < end; i++) {
      if (bytes[i] == 0x1B && bytes[i + 1] == 0x4D) font = bytes[i + 2];
    }
    return font;
  }

  test('carries every field the receipt shows', () async {
    final text = textOf(await service.build(receipt()));

    expect(text, contains('RECEIPT'));
    expect(text, contains('RCP-20260910-1432'));
    expect(text, contains('Ichsan'));
    expect(text, contains('Budi'));
    expect(text, contains('081234567890'));
    expect(text, contains('Jl. Sudirman No. 1, Jakarta'));
    expect(text, contains('Espresso Machine'));
    expect(text, contains('TERIMA KASIH'));
  });

  test('starts with the ESC @ initialise command', () async {
    final bytes = await service.build(receipt());
    expect(bytes.take(2), orderedEquals([0x1B, 0x40]));
  });

  test('adds the QR block only when the address is pinned', () async {
    final plain = textOf(await service.build(receipt()));
    expect(plain, isNot(contains('Scan untuk buka alamat')));

    final located = await service.build(receipt(lat: -6.2088, lng: 106.8456));
    expect(textOf(located), contains('Scan untuk buka alamat'));
    expect(textOf(located), contains('-6.208800, 106.845600'));
    expect(
      located.length,
      greaterThan((await service.build(receipt())).length),
    );
  });

  test('form values print at double height so they are readable', () async {
    // Regression: values printed at the base size came off an 80 mm printer
    // too small to read next to the header.
    final bytes = await service.build(receipt());

    for (final value in [
      'Ichsan',
      'Budi',
      '081234567890',
      'Jl. Sudirman No. 1, Jakarta',
      'Espresso Machine',
    ]) {
      final size = sizeByteFor(bytes, value);
      expect(
        heightMultiplier(size),
        2,
        reason: '"$value" is not double height',
      );
      expect(
        widthMultiplier(size),
        1,
        reason: '"$value" must stay single width to keep 48 chars per line',
      );
    }
  });

  test('field captions stay smaller than their values', () async {
    final bytes = await service.build(receipt());
    expect(heightMultiplier(sizeByteFor(bytes, 'ALAMAT')), 1);
    expect(heightMultiplier(sizeByteFor(bytes, 'Jl. Sudirman')), 2);
  });

  test('values print in font A, not the caption font', () async {
    // Regression: captions select font B and the generator only emits a font
    // command when fontType is non-null, so values with a null fontType
    // inherited font B and printed in the small face at double height.
    final bytes = await service.build(receipt());

    for (final caption in ['DARI', 'KEPADA', 'TELEPON', 'ALAMAT', 'PRODUK']) {
      expect(fontFor(bytes, caption), 1, reason: '$caption should be font B');
    }
    for (final value in [
      'Ichsan',
      'Budi',
      '081234567890',
      'Jl. Sudirman No. 1, Jakarta',
      'Espresso Machine',
    ]) {
      expect(fontFor(bytes, value), 0, reason: '"$value" should be font A');
    }
    expect(fontFor(bytes, 'TERIMA KASIH'), 0);
  });

  group('optional receipt number', () {
    test('prints the number line when one is set', () async {
      final text = textOf(await service.build(receipt()));
      expect(text, contains('NO.'));
      expect(text, contains('RCP-20260910-1432'));
    });

    test('omits the whole line when the number is blank', () async {
      final blank = Receipt(
        number: '',
        from: 'Ichsan',
        to: 'Budi',
        phone: '081234567890',
        productName: 'Espresso Machine',
        address: 'Jl. Sudirman No. 1, Jakarta',
        issuedAt: DateTime(2026, 9, 10, 14, 32),
      );

      final text = textOf(await service.build(blank));
      expect(text, isNot(contains('NO.')));
      // The date line still prints.
      expect(text, contains('TGL'));
      expect(text, contains('10 Sep 2026'));
    });
  });

  test('58 mm paper produces a narrower ticket than 80 mm', () async {
    final narrow = await service.build(receipt(), paperWidth: PaperWidth.mm58);
    final wide = await service.build(receipt(), paperWidth: PaperWidth.mm80);

    // The horizontal rule is generated to the paper's character width.
    expect(narrow.length, lessThan(wide.length));
  });

  test('the cut command can be turned off', () async {
    const cut = [0x1D, 0x56]; // GS V
    bool hasCut(List<int> bytes) {
      for (var i = 0; i < bytes.length - 1; i++) {
        if (bytes[i] == cut[0] && bytes[i + 1] == cut[1]) return true;
      }
      return false;
    }

    expect(hasCut(await service.build(receipt())), isTrue);
    expect(hasCut(await service.build(receipt(), cutPaper: false)), isFalse);
  });

  test('an empty optional field prints a dash rather than nothing', () async {
    final blank = Receipt(
      number: 'RCP-1',
      from: 'A',
      to: 'B',
      phone: '0812',
      productName: '',
      address: '',
      issuedAt: DateTime(2026, 9, 10),
    );

    expect(textOf(await service.build(blank)), contains('-'));
  });
}
