import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_printer/theme/app_theme.dart';
import 'package:receipt_printer/widgets/segmented_tabs.dart';

void main() {
  const labels = ['Resi', 'Ongkir'];
  const icons = [Icons.receipt_long_outlined, Icons.calculate_outlined];

  Future<int?> pumpTabs(WidgetTester tester, {int index = 0}) async {
    int? tapped;
    await tester.binding.setSurfaceSize(const Size(400, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: SegmentedTabs(
              labels: labels,
              icons: icons,
              index: index,
              onChanged: (value) => tapped = value,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tapped;
  }

  /// The track the sliding indicator runs in — the bar minus padding/border.
  Rect trackOf(WidgetTester tester) =>
      tester.getRect(find.byType(AnimatedAlign));

  testWidgets('icon and label sit on the vertical centre of the bar', (
    tester,
  ) async {
    await pumpTabs(tester);
    final centreY = trackOf(tester).center.dy;

    for (var i = 0; i < labels.length; i++) {
      expect(
        tester.getRect(find.byType(Icon).at(i)).center.dy,
        moreOrLessEquals(centreY, epsilon: 0.5),
        reason: 'icon $i is off the vertical centre',
      );
      expect(
        tester.getRect(find.text(labels[i])).center.dy,
        moreOrLessEquals(centreY, epsilon: 0.5),
        reason: '"${labels[i]}" is off the vertical centre',
      );
    }
  });

  testWidgets('icon and label share the same vertical centre', (tester) async {
    await pumpTabs(tester);

    for (var i = 0; i < labels.length; i++) {
      expect(
        tester.getRect(find.byType(Icon).at(i)).center.dy,
        moreOrLessEquals(
          tester.getRect(find.text(labels[i])).center.dy,
          epsilon: 0.5,
        ),
        reason: 'icon and label of segment $i are not aligned to each other',
      );
    }
  });

  testWidgets('each label group is horizontally centred in its segment', (
    tester,
  ) async {
    await pumpTabs(tester);
    final track = trackOf(tester);
    final segmentWidth = track.width / labels.length;

    for (var i = 0; i < labels.length; i++) {
      final icon = tester.getRect(find.byType(Icon).at(i));
      final text = tester.getRect(find.text(labels[i]));
      final groupCentre = (icon.left + text.right) / 2;
      final segmentCentre = track.left + segmentWidth * (i + 0.5);

      expect(
        groupCentre,
        moreOrLessEquals(segmentCentre, epsilon: 0.5),
        reason: 'segment $i content is off centre',
      );
    }
  });

  testWidgets('the indicator covers exactly the selected segment', (
    tester,
  ) async {
    await pumpTabs(tester, index: 1);
    final track = trackOf(tester);
    final indicator = tester.getRect(
      find.descendant(
        of: find.byType(AnimatedAlign),
        matching: find.byType(Container),
      ),
    );

    expect(indicator.width, moreOrLessEquals(track.width / 2, epsilon: 0.5));
    expect(indicator.right, moreOrLessEquals(track.right, epsilon: 0.5));
    expect(indicator.height, moreOrLessEquals(track.height, epsilon: 0.5));
  });

  testWidgets('the whole height of a segment is tappable', (tester) async {
    // Regression: the row used to shrink-wrap to the label height and pin to
    // the top, leaving the lower half of the bar dead.
    await pumpTabs(tester);
    final track = trackOf(tester);

    int? tapped;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: SegmentedTabs(
              labels: labels,
              icons: icons,
              index: 0,
              onChanged: (value) => tapped = value,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Near the bottom edge of the second segment.
    await tester.tapAt(
      Offset(track.left + track.width * 0.75, track.bottom - 2),
    );
    await tester.pump();
    expect(tapped, 1);

    // Near the top edge of the first segment.
    await tester.tapAt(Offset(track.left + track.width * 0.25, track.top + 2));
    await tester.pump();
    expect(tapped, 0);
  });
}
