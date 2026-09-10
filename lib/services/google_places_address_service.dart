import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/address_suggestion.dart';
import 'address_service.dart';

/// Google Places API (New) — used automatically when a key is supplied with
/// `--dart-define=GOOGLE_PLACES_API_KEY=...`.
///
/// Autocomplete and Place Details come from `places.googleapis.com`; reverse
/// geocoding uses the classic Geocoding API, so enable both for the key.
class GooglePlacesAddressService implements AddressService {
  GooglePlacesAddressService({required this.apiKey, http.Client? client})
    : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  static const String _placesHost = 'places.googleapis.com';
  static const String _geocodeHost = 'maps.googleapis.com';

  @override
  String get providerLabel => 'Google Places';

  @override
  String get attribution => 'Powered by Google';

  @override
  Future<List<AddressSuggestion>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return const [];

    final response = await _send(
      () => _client.post(
        Uri.https(_placesHost, '/v1/places:autocomplete'),
        headers: {'Content-Type': 'application/json', 'X-Goog-Api-Key': apiKey},
        body: jsonEncode({
          'input': trimmed,
          // Deliveries are domestic only, so results outside Indonesia are
          // useless here regardless of what word the user typed.
          'includedRegionCodes': ['ID'],
        }),
      ),
    );

    final decoded = jsonDecode(response) as Map<String, dynamic>;
    final suggestions = decoded['suggestions'] as List<dynamic>? ?? const [];

    return suggestions
        .whereType<Map<String, dynamic>>()
        .map((item) => item['placePrediction'])
        .whereType<Map<String, dynamic>>()
        .map((prediction) {
          final format =
              prediction['structuredFormat'] as Map<String, dynamic>?;
          final main = _text(format?['mainText']);
          final secondary = _text(format?['secondaryText']);
          final full = _text(prediction['text']);
          return AddressSuggestion(
            description: full.isNotEmpty
                ? full
                : [main, secondary].where((e) => e.isNotEmpty).join(', '),
            placeId: prediction['placeId'] as String?,
            secondaryText: secondary.isEmpty ? null : secondary,
          );
        })
        .toList(growable: false);
  }

  /// Autocomplete predictions carry no coordinates, so fetch Place Details.
  @override
  Future<AddressSuggestion> resolve(AddressSuggestion suggestion) async {
    final placeId = suggestion.placeId;
    if (placeId == null || suggestion.hasCoordinates) return suggestion;

    final response = await _send(
      () => _client.get(
        Uri.https(_placesHost, '/v1/places/$placeId'),
        headers: {
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask': 'formattedAddress,location',
        },
      ),
    );

    final decoded = jsonDecode(response) as Map<String, dynamic>;
    final location = decoded['location'] as Map<String, dynamic>?;
    final formatted = decoded['formattedAddress'] as String?;

    return suggestion.copyWith(
      description: formatted,
      latitude: (location?['latitude'] as num?)?.toDouble(),
      longitude: (location?['longitude'] as num?)?.toDouble(),
    );
  }

  @override
  Future<AddressSuggestion?> reverse(double latitude, double longitude) async {
    final response = await _send(
      () => _client.get(
        Uri.https(_geocodeHost, '/maps/api/geocode/json', {
          'latlng': '$latitude,$longitude',
          'key': apiKey,
        }),
      ),
    );

    final decoded = jsonDecode(response) as Map<String, dynamic>;
    final results = decoded['results'] as List<dynamic>? ?? const [];
    if (results.isEmpty) return null;

    final first = results.first as Map<String, dynamic>;

    // The Geocoding API's region biasing only affects forward geocoding, so
    // a tap outside Indonesia is rejected after the fact by checking the
    // country component every result already carries.
    final components =
        first['address_components'] as List<dynamic>? ?? const [];
    final isIndonesia = components.any((component) {
      final map = component as Map<String, dynamic>;
      final types = (map['types'] as List<dynamic>? ?? const []).cast<String>();
      return types.contains('country') && map['short_name'] == 'ID';
    });
    if (!isIndonesia) return null;

    return AddressSuggestion(
      description: first['formatted_address'] as String? ?? '',
      placeId: first['place_id'] as String?,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<String> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw AddressServiceException(
          'Google Places replied with ${response.statusCode}. '
          'Check that the API key is valid and the API is enabled.',
        );
      }
      return response.body;
    } on AddressServiceException {
      rethrow;
    } catch (error) {
      throw const AddressServiceException(
        'Could not reach Google Places. Check your connection.',
      );
    }
  }

  String _text(Object? node) =>
      node is Map<String, dynamic> ? (node['text'] as String? ?? '') : '';

  @override
  void dispose() => _client.close();
}
