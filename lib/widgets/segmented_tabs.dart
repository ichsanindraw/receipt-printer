import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A two-up pill switcher with a sliding indicator.
///
/// Used instead of Material's `TabBar` (underline indicator) or
/// `NavigationBar` (bottom bar), both of which read as stock Android.
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.icons,
    required this.index,
    required this.onChanged,
  }) : assert(labels.length == icons.length);

  final List<String> labels;
  final List<IconData> icons;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: palette.hairline),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / labels.length;

          return Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment(
                  labels.length == 1
                      ? 0
                      : (index / (labels.length - 1)) * 2 - 1,
                  0,
                ),
                child: Container(
                  width: segmentWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              // Positioned.fill matters: a non-positioned Stack child gets
              // loose constraints, so the row would shrink-wrap to the text
              // height and sit at the top of the bar, leaving the lower half
              // untappable.
              Positioned.fill(
                child: Row(
                  // Stretch so each segment's tap target is the full height of
                  // the bar, not just the height of its label.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < labels.length; i++)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChanged(i),
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            style:
                                theme.textTheme.titleSmall?.copyWith(
                                  color: i == index
                                      ? theme.colorScheme.onSurface
                                      : palette.inkMuted,
                                ) ??
                                const TextStyle(),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  icons[i],
                                  size: 17,
                                  color: i == index
                                      ? theme.colorScheme.onSurface
                                      : palette.inkMuted,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  labels[i],
                                  // The type scale sets a 1.3 line height,
                                  // which pushes the glyphs off the icon's
                                  // optical centre inside a Row.
                                  style: const TextStyle(height: 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
