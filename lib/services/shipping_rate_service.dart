import '../models/address_suggestion.dart';
import '../models/courier.dart';
import '../models/shipping_quote.dart';

/// Thrown when a shipping rate provider cannot answer.
class ShippingRateException implements Exception {
  const ShippingRateException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Quotes domestic Indonesian shipping costs.
///
/// Two implementations ship with the app. They differ in where a "place"
/// comes from, so each provider searches for its own places rather than
/// sharing one geocoder:
///
/// * the offline estimator resolves places through the map geocoder and
///   prices them from the distance between their coordinates;
/// * RajaOngkir resolves places through its own kecamatan-level database and
///   prices them with real courier tariffs.
abstract class ShippingRateService {
  String get providerLabel;

  /// True when the numbers are modelled rather than quoted by a courier. The
  /// UI must say so — see [disclaimer].
  bool get isEstimate;

  String get disclaimer;

  /// Couriers this provider can quote.
  List<Courier> get couriers;

  /// Origin/destination lookup, in whatever place database the provider uses.
  Future<List<AddressSuggestion>> searchPlaces(String query);

  /// Fills in whatever the autocomplete response left out (coordinates, ids).
  Future<AddressSuggestion> resolvePlace(AddressSuggestion place);

  Future<List<ShippingQuote>> quote({
    required AddressSuggestion origin,
    required AddressSuggestion destination,
    required int weightGram,
    required List<String> courierCodes,
  });

  void dispose();
}
