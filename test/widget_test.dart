import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_printer/app.dart';

void main() {
  /// The form is a lazily built ListView, so give it a surface tall enough to
  /// lay out every section at once.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ReceiptPrinterApp());
  }

  Finder fieldFor(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(TextFormField));

  testWidgets('shows every receipt field and the print button', (tester) async {
    await pumpApp(tester);

    expect(find.text('Receipt number'), findsOneWidget);
    expect(find.text('From (sender name)'), findsOneWidget);
    expect(find.text('To (recipient name)'), findsOneWidget);
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('Product name'), findsOneWidget);
    expect(find.text('Address'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Print Receipt'), findsOneWidget);
  });

  testWidgets('prefills a generated receipt number', (tester) async {
    await pumpApp(tester);

    final field = tester.widget<TextFormField>(fieldFor('Receipt number'));
    expect(field.controller?.text, matches(RegExp(r'^RCP-\d{8}-\d{4}$')));
  });

  testWidgets('blocks printing until the form is valid', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Print Receipt'));
    await tester.pump();

    expect(
      find.text('Please complete the highlighted fields.'),
      findsOneWidget,
    );
    expect(find.text('Sender name is required'), findsOneWidget);
    expect(find.text('Recipient name is required'), findsOneWidget);
    expect(find.text('Product name is required'), findsOneWidget);
    expect(find.text('Address is required'), findsOneWidget);
  });

  testWidgets('rejects a phone number that is too short', (tester) async {
    await pumpApp(tester);

    await tester.enterText(fieldFor('Phone'), '123');
    await tester.tap(find.widgetWithText(FilledButton, 'Print Receipt'));
    await tester.pump();

    expect(find.text('Enter a valid phone number'), findsOneWidget);
  });

  testWidgets('clearing the form regenerates the receipt number', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.enterText(fieldFor('From (sender name)'), 'Ichsan');
    await tester.pump();
    expect(find.text('Ichsan'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear form'));
    await tester.pump();

    expect(find.text('Ichsan'), findsNothing);
    expect(find.text('Form cleared.'), findsOneWidget);
  });
}
