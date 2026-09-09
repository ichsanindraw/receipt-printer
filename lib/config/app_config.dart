/// Build-time configuration.
///
/// The app works with zero configuration: address autocomplete falls back to
/// OpenStreetMap's Nominatim service, which needs no API key.
///
/// To use Google Places instead, pass a key at build/run time:
///
///   flutter run --dart-define=GOOGLE_PLACES_API_KEY=your_key_here
class AppConfig {
  const AppConfig._();

  static const String appName = 'Receipt Printer';

  /// Google Places API key, injected with `--dart-define`. Empty by default.
  static const String googlePlacesApiKey = String.fromEnvironment(
    'GOOGLE_PLACES_API_KEY',
  );

  static bool get hasGooglePlacesKey => googlePlacesApiKey.isNotEmpty;

  /// Sent to Nominatim and the OSM tile servers so we play by their usage
  /// policy, which requires an identifiable client.
  static const String userAgent =
      'receipt_printer/1.0 (https://github.com/ichsanindraw/receipt-printer)';

  static const String packageName = 'com.ichsanindraw.receipt_printer';
}
