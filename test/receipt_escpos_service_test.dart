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
