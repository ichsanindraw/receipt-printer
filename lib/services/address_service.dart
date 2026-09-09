import '../models/address_suggestion.dart';

/// Thrown when a geocoding provider is unreachable or answers with an error.
class AddressServiceException implements Exception {
  const AddressServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Anything that can turn typed text into addresses, and coordinates back into
/// an address. Two implementations ship with the app: OpenStreetMap Nominatim
/// (default, no API key) and Google Places.
abstract class AddressService {
  /// Shown in the UI so it is obvious which provider is active.
  String get providerLabel;

  /// Attribution line the provider's terms require us to display.
  String get attribution;

  /// Autocomplete candidates for [query]. Callers debounce; implementations do
  /// not have to.
  Future<List<AddressSuggestion>> search(String query);

  /// Fills in coordinates for a suggestion that came back without them.
  /// Returns [suggestion] unchanged when nothing more can be resolved.
  Future<AddressSuggestion> resolve(AddressSuggestion suggestion);

  /// Reverse geocoding — used when the user drops the pin on the map instead
  /// of typing. Returns `null` when the point has no known address.
  Future<AddressSuggestion?> reverse(double latitude, double longitude);

  void dispose();
}
