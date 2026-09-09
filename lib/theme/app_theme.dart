import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The app's design tokens.
///
/// Deliberately not a stock Material palette: warm paper neutrals, ink-black
/// primary actions, and a single amber accent. Colour is carried by the
/// hairlines and the accent, not by tinted Material surfaces.
class AppColors {
  const AppColors._();

  // Light — warm paper
  static const Color lightBackground = Color(0xFFF4F3F0);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceMuted = Color(0xFFEFEDE8);
  static const Color lightInk = Color(0xFF171614);
  static const Color lightInkMuted = Color(0xFF75706A);
  static const Color lightInkFaint = Color(0xFF9C968E);
  static const Color lightHairline = Color(0xFFE3DFD8);

  // Dark — warm charcoal
  static const Color darkBackground = Color(0xFF121110);
  static const Color darkSurface = Color(0xFF1B1A18);
  static const Color darkSurfaceMuted = Color(0xFF242220);
  static const Color darkInk = Color(0xFFF4F3F0);
  static const Color darkInkMuted = Color(0xFF9E9891);
  static const Color darkInkFaint = Color(0xFF6F6A64);
  static const Color darkHairline = Color(0xFF2E2B28);

  static const Color accent = Color(0xFFC2570F);
  static const Color accentDark = Color(0xFFF08A3C);
  static const Color danger = Color(0xFFB4341F);
  static const Color dangerDark = Color(0xFFE7715C);
  static const Color success = Color(0xFF2C6E4A);
}

/// Corner radii, one scale for the whole app.
class AppRadius {
  const AppRadius._();

  static const double field = 14;
  static const double card = 20;
  static const double pill = 999;
}

class AppSpacing {
  const AppSpacing._();

  static const double gutter = 20;
  static const double betweenCards = 14;
  static const double betweenFields = 14;
}

/// Extra colours the Material [ColorScheme] has no slot for.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.inkMuted,
    required this.inkFaint,
    required this.hairline,
    required this.surfaceMuted,
    required this.accent,
  });

  final Color inkMuted;
  final Color inkFaint;
  final Color hairline;
  final Color surfaceMuted;
  final Color accent;

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>()!;

  @override
  AppPalette copyWith({
    Color? inkMuted,
    Color? inkFaint,
    Color? hairline,
    Color? surfaceMuted,
    Color? accent,
  }) {
    return AppPalette(
      inkMuted: inkMuted ?? this.inkMuted,
      inkFaint: inkFaint ?? this.inkFaint,
      hairline: hairline ?? this.hairline,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      accent: accent ?? this.accent,
    );
  }

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }
}

class AppTheme {
  const AppTheme._();

  static const String fontFamily = 'Plus Jakarta Sans';

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final background = isLight
        ? AppColors.lightBackground
        : AppColors.darkBackground;
    final surface = isLight ? AppColors.lightSurface : AppColors.darkSurface;
    final ink = isLight ? AppColors.lightInk : AppColors.darkInk;
    final inkMuted = isLight ? AppColors.lightInkMuted : AppColors.darkInkMuted;
    final inkFaint = isLight ? AppColors.lightInkFaint : AppColors.darkInkFaint;
    final hairline = isLight ? AppColors.lightHairline : AppColors.darkHairline;
    final surfaceMuted = isLight
        ? AppColors.lightSurfaceMuted
        : AppColors.darkSurfaceMuted;
    final accent = isLight ? AppColors.accent : AppColors.accentDark;
    final danger = isLight ? AppColors.danger : AppColors.dangerDark;

    final scheme = ColorScheme(
      brightness: brightness,
      // Ink is the primary: black buttons, black focus rings.
      primary: ink,
      onPrimary: isLight ? AppColors.lightSurface : AppColors.darkBackground,
      secondary: accent,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: ink,
      surfaceContainerLowest: background,
      surfaceContainerLow: surface,
      surfaceContainer: surfaceMuted,
      surfaceContainerHigh: surfaceMuted,
      surfaceContainerHighest: surfaceMuted,
      onSurfaceVariant: inkMuted,
      outline: hairline,
      outlineVariant: hairline,
      error: danger,
      onError: Colors.white,
    );

    final text = _textTheme(ink, inkMuted);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      fontFamily: fontFamily,
      textTheme: text,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      dividerTheme: DividerThemeData(color: hairline, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: isLight ? AppColors.lightSurface : AppColors.darkBackground,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
        insetPadding: const EdgeInsets.all(AppSpacing.gutter),
        elevation: 0,
      ),
      extensions: [
        AppPalette(
          inkMuted: inkMuted,
          inkFaint: inkFaint,
          hairline: hairline,
          surfaceMuted: surfaceMuted,
          accent: accent,
        ),
      ],
    );
  }

  static TextTheme _textTheme(Color ink, Color inkMuted) {
    // Tight tracking on display sizes, open tracking on the small caps labels.
    return TextTheme(
      displaySmall: TextStyle(
        fontSize: 30,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: ink,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: ink,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: ink,
      ),
      bodyLarge: TextStyle(
        fontSize: 15.5,
        height: 1.45,
        fontWeight: FontWeight.w500,
        color: ink,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: ink,
      ),
      bodySmall: TextStyle(
        fontSize: 12.5,
        height: 1.4,
        fontWeight: FontWeight.w400,
        color: inkMuted,
      ),
      labelLarge: TextStyle(
        fontSize: 15,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: ink,
      ),
      // The small-caps section labels.
      labelSmall: TextStyle(
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.9,
        color: inkMuted,
      ),
    );
  }

  /// Keeps the status bar icons readable against the paper background.
  static SystemUiOverlayStyle overlayStyle(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
      statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: isLight
          ? AppColors.lightBackground
          : AppColors.darkBackground,
      systemNavigationBarIconBrightness: isLight
          ? Brightness.dark
          : Brightness.light,
    );
  }
}
