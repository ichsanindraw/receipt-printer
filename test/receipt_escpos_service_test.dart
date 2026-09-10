import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_printer/models/printer_settings.dart';
import 'package:receipt_printer/models/receipt.dart';
import 'package:receipt_printer/services/receipt_escpos_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const service = ReceiptEscPosService();

  Receipt receipt({
    double? lat,
    double? lng,
    List<String> products = const ['Espresso Machine'],
    String notes = '',
    String address = 'Jl. Sudirman No. 1, Jakarta',
  }) => Receipt(
    number: 'RCP-20260910-1432',
    from: 'Ichsan',
    fromPhone: '081234567890',
    to: 'Budi',
    toPhone: '089537356500',
    products: products,
    address: address,
    notes: notes,
    latitude: lat,
    longitude: lng,
    issuedAt: DateTime(2026, 9, 10, 14, 32),
  );

  /// ESC/POS is a byte stream, so assert on the readable text it carries.
  String textOf(List<int> bytes) =>
      String.fromCharCodes(bytes.where((b) => b >= 32 && b < 127));

  int indexOfText(List<int> bytes, String text, {int from = 0}) {
    final needle = text.codeUnits;
    outer:
    for (var i = from; i <= bytes.length - needle.length; i++) {
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

  /// Whether `ESC E 1` (bold on) is the last emphasis command before [text].
  bool isBold(List<int> bytes, String text) {
    final end = indexOfText(bytes, text);
    expect(end, greaterThan(-1), reason: '"$text" is not in the output');
    var bold = false;
    for (var i = 0; i + 2 < end; i++) {
      if (bytes[i] == 0x1B && bytes[i + 1] == 0x45) bold = bytes[i + 2] == 1;
    }
    return bold;
  }

  /// Whether an `ESC d n` (feed n lines) command sits anywhere in `[start, end)`.
  bool hasFeedCommand(List<int> bytes, int start, int end, {int n = 1}) {
    for (var i = start; i < end - 2 && i >= 0; i++) {
      if (bytes[i] == 0x1B && bytes[i + 1] == 0x64 && bytes[i + 2] == n) {
        return true;
      }
    }
    return false;
  }

  test('carries every field the receipt shows', () async {
    final text = textOf(await service.build(receipt()));

    expect(text, contains('RCP-20260910-1432'));
    expect(text, contains('Ichsan'));
    expect(text, contains('081234567890'));
    expect(text, contains('Budi'));
    expect(text, contains('089537356500'));
    expect(text, contains('Jl. Sudirman No. 1, Jakarta'));
    expect(text, contains('Espresso Machine'));
    expect(text, contains('TERIMA KASIH'));
  });

  test('starts with the ESC @ initialise command', () async {
    final bytes = await service.build(receipt());
    expect(bytes.take(2), orderedEquals([0x1B, 0x40]));
  });

  test('has no masthead — the receipt starts at its own metadata', () async {
    // Regression: a name/logo line the recipient doesn't need, on paper
    // worth saving.
    final text = textOf(await service.build(receipt()));
    expect(text, isNot(contains('RECEIPT')));
    expect(text, isNot(contains('RECEIPT PRINTER')));
  });

  test('never prints a maps QR code, pinned or not', () async {
    // Regression: the QR image was the single biggest thing on the paper.
    // The coordinates still print as a small text line under ALAMAT — that
    // stays — but nothing invites a scan.
    final plain = textOf(await service.build(receipt()));
    expect(plain, isNot(contains('Scan')));

    final located = await service.build(receipt(lat: -6.2088, lng: 106.8456));
    final locatedText = textOf(located);
    expect(locatedText, isNot(contains('Scan')));
    expect(locatedText, contains('-6.208800, 106.845600'));
    // The coordinates text line itself still adds a little length, just
    // nowhere near what the QR image used to.
    expect(located.length, greaterThan(plain.length));
  });

  test('form values print at double height so they are readable', () async {
    // Regression: values printed at the base size came off an 80 mm printer
    // too small to read next to the header.
    final bytes = await service.build(receipt());

    for (final value in [
      'Ichsan',
      '081234567890',
      'Budi',
      '089537356500',
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

  test(
    'the receipt number and date print smaller than the field values',
    () async {
      final bytes = await service.build(receipt());
      // One size down from the double-height field values, so DARI/KEPADA/etc.
      // read as the content that matters most on the slip.
      expect(heightMultiplier(sizeByteFor(bytes, 'RCP-20260910-1432')), 1);
      expect(heightMultiplier(sizeByteFor(bytes, '10 Sep 2026')), 1);
      expect(heightMultiplier(sizeByteFor(bytes, 'Ichsan')), 2);
    },
  );

  test('captions and values both print in font A', () async {
    // Regression: captions used to select font B and the generator only
    // emits a font command when fontType is non-null, so a value with a
    // null fontType silently inherited font B from the caption above it.
    // Captions moved to font A too (it read clearer than the condensed B),
    // so this now also guards against either one drifting back to font B.
    final bytes = await service.build(receipt());

    for (final caption in ['DARI', 'NO. HP', 'KEPADA', 'ALAMAT', 'PRODUK']) {
      expect(fontFor(bytes, caption), 0, reason: '$caption should be font A');
    }
    for (final value in [
      'Ichsan',
      '081234567890',
      'Budi',
      '089537356500',
      'Jl. Sudirman No. 1, Jakarta',
      'Espresso Machine',
    ]) {
      expect(fontFor(bytes, value), 0, reason: '"$value" should be font A');
    }
    expect(fontFor(bytes, 'TERIMA KASIH'), 0);
  });

  test('the coordinates footnote deliberately stays in font B', () async {
    final bytes = await service.build(receipt(lat: -6.2088, lng: 106.8456));
    expect(fontFor(bytes, '-6.208800'), 1);
  });

  test('captions are not bold, unlike the values they introduce', () async {
    final bytes = await service.build(receipt());
    for (final caption in ['DARI', 'NO. HP', 'KEPADA', 'ALAMAT', 'PRODUK']) {
      expect(
        isBold(bytes, caption),
        isFalse,
        reason: '$caption should not be bold',
      );
    }
    expect(isBold(bytes, 'Ichsan'), isTrue);
  });

  test('the sender and recipient phone sit under their own name', () async {
    final bytes = await service.build(receipt());

    final dari = indexOfText(bytes, 'DARI');
    final firstNoHp = indexOfText(bytes, 'NO. HP');
    final fromPhone = indexOfText(bytes, '081234567890');
    final kepada = indexOfText(bytes, 'KEPADA');
    final secondNoHp = indexOfText(bytes, 'NO. HP', from: firstNoHp + 1);
    final toPhone = indexOfText(bytes, '089537356500');

    expect(dari, greaterThan(-1), reason: 'DARI missing');
    expect(firstNoHp, greaterThan(dari), reason: 'sender NO. HP out of order');
    expect(
      fromPhone,
      greaterThan(firstNoHp),
      reason: 'sender phone out of order',
    );
    expect(kepada, greaterThan(fromPhone), reason: 'KEPADA out of order');
    expect(
      secondNoHp,
      greaterThan(kepada),
      reason: 'recipient NO. HP out of order',
    );
    expect(
      toPhone,
      greaterThan(secondNoHp),
      reason: 'recipient phone out of order',
    );
  });

  test(
    'a name and its own phone stay flush, but groups and fields have a gap',
    () async {
      final bytes = await service.build(receipt());
      int endOf(String text) => indexOfText(bytes, text) + text.length;
      int startOf(String text, {int from = 0}) =>
          indexOfText(bytes, text, from: from);

      final firstNoHp = startOf('NO. HP');
      final secondNoHp = startOf('NO. HP', from: firstNoHp + 1);

      // Regression: only the hr() section dividers had any breathing room —
      // every field ran straight into the next one, sender phone included.
      expect(
        hasFeedCommand(bytes, endOf('Ichsan'), firstNoHp),
        isFalse,
        reason: 'DARI and its own NO. HP should stay flush together',
      );
      expect(
        hasFeedCommand(bytes, endOf('081234567890'), startOf('KEPADA')),
        isTrue,
        reason: 'no gap between the sender group and KEPADA',
      );
      expect(
        hasFeedCommand(bytes, endOf('Budi'), secondNoHp),
        isFalse,
        reason: 'KEPADA and its own NO. HP should stay flush together',
      );
      expect(
        hasFeedCommand(bytes, endOf('089537356500'), startOf('ALAMAT')),
        isTrue,
        reason: 'no gap between the recipient group and ALAMAT',
      );
    },
  );

  test('a hand-typed multi-line address keeps its lines in order', () async {
    // The address is free text, not only an autocompleted single line — the
    // street may not be in the map provider's index at all — so a courier
    // formatting it across several lines must come through as those same
    // lines on paper, in the order they were typed, not run together or
    // reshuffled by however the encoder handles an embedded '\n'.
    const address =
        'Klinik Bersalin Putera Jaya\n'
        'Jl Apel Gg. Apel Salam\n'
        'Pontianak Barat, Kota Pontianak\n'
        'Kalimantan Barat';
    final bytes = await service.build(receipt(address: address));

    var from = 0;
    for (final line in address.split('\n')) {
      final at = indexOfText(bytes, line, from: from);
      expect(at, greaterThanOrEqualTo(from), reason: '"$line" out of order');
      from = at + line.length;
    }
  });

  group('products', () {
    test('each product prints as its own "* " line', () async {
      final text = textOf(
        await service.build(
          receipt(products: const ['Espresso Machine', 'Milk Frother']),
        ),
      );

      expect(text, contains('* Espresso Machine'));
      expect(text, contains('* Milk Frother'));
    });

    test('blank product entries are dropped rather than printed', () async {
      final text = textOf(
        await service.build(
          receipt(products: const ['Espresso Machine', '  ', '']),
        ),
      );

      // Only the one real product's bullet line appears.
      expect('* '.allMatches(text).length, 1);
    });

    test('an empty product list prints a dash rather than nothing', () async {
      final text = textOf(await service.build(receipt(products: const [])));
      expect(text, contains('PRODUK'));
      expect(text, isNot(contains('*')));
    });
  });

  group('notes', () {
    test('a CATATAN section prints only when notes are given', () async {
      final withoutNotes = textOf(await service.build(receipt()));
      expect(withoutNotes, isNot(contains('CATATAN')));

      final withNotes = textOf(
        await service.build(
          receipt(notes: 'Titip di satpam kalau tidak ada orang.'),
        ),
      );
      expect(withNotes, contains('CATATAN'));
      expect(withNotes, contains('Titip di satpam kalau tidak ada orang.'));
    });

    test('whitespace-only notes count as no notes', () async {
      final text = textOf(await service.build(receipt(notes: '   ')));
      expect(text, isNot(contains('CATATAN')));
    });
  });

  group('optional receipt number', () {
    test('prints the number line when one is set', () async {
      final bytes = await service.build(receipt());
      // 'NO. HP' would satisfy a bare contains('NO.') check regardless of
      // whether the number row itself printed, so check the header
      // specifically, before either phone caption exists in the stream.
      final header = textOf(bytes.sublist(0, indexOfText(bytes, 'DARI')));
      expect(header, contains('NO.'));
      expect(header, contains('RCP-20260910-1432'));
    });

    test('omits the whole line when the number is blank', () async {
      final blank = Receipt(
        number: '',
        from: 'Ichsan',
        fromPhone: '081234567890',
        to: 'Budi',
        toPhone: '089537356500',
        products: const ['Espresso Machine'],
        address: 'Jl. Sudirman No. 1, Jakarta',
        issuedAt: DateTime(2026, 9, 10, 14, 32),
      );

      final bytes = await service.build(blank);
      // 'NO. HP' (both phone captions) and the address itself ('Jl. Sudirman
      // No. 1...') both legitimately contain the substring 'NO.', so the
      // absence check only makes sense against the header, before either of
      // those exists in the stream.
      final header = textOf(bytes.sublist(0, indexOfText(bytes, 'DARI')));
      expect(header, isNot(contains('NO.')));
      // The date line still prints.
      expect(header, contains('TGL'));
      expect(header, contains('10 Sep 2026'));
    });

    test('explains the missing number in a footnote when blank', () async {
      final blank = Receipt(
        number: '',
        from: 'Ichsan',
        fromPhone: '081234567890',
        to: 'Budi',
        toPhone: '089537356500',
        products: const ['Espresso Machine'],
        address: 'Jl. Sudirman No. 1, Jakarta',
        issuedAt: DateTime(2026, 9, 10, 14, 32),
      );

      final text = textOf(await service.build(blank));
      expect(text, contains('Nomor resi tidak diisi'));
    });

    test('says nothing extra when a number is set', () async {
      final text = textOf(await service.build(receipt()));
      expect(text, isNot(contains('Nomor resi tidak diisi')));
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
      fromPhone: '0812',
      to: 'B',
      toPhone: '0813',
      products: const [],
      address: '',
      issuedAt: DateTime(2026, 9, 10),
    );

    expect(textOf(await service.build(blank)), contains('-'));
  });
}
