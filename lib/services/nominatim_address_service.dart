import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/address_suggestion.dart';
import 'address_service.dart';

/// OpenStreetMap Nominatim — free, keyless, and good enough for a receipt app.
///
/// Nominatim's usage policy asks for at most one request per second and an
/// identifiable User-Agent. The UI debounces keystrokes; the User-Agent comes
/// from [AppConfig]. Browsers forbid setting User-Agent from JS, so on web we
/// leave it off and rely on the Referer instead.
class NominatimAddressService implements AddressService {
  NominatimAddressService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const String _host = 'nominatim.openstreetmap.org';

  @override
  String get providerLabel => 'OpenStreetMap';

  @override
  String get attribution => '© OpenStreetMap contributors';

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    if (!kIsWeb) 'User-Agent': AppConfig.userAgent,
  };

  @override
  Future<List<AddressSuggestion>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return const [];

    final uri = Uri.https(_host, '/search', {
      'q': trimmed,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '6',
      // Deliveries are domestic only, so results outside Indonesia are
      // useless here regardless of what word the user typed.
      'countrycodes': 'id',
    });

    final body = await _get(uri);
    final results = jsonDecode(body) as List<dynamic>;

    return results
        .whereType<Map<String, dynamic>>()
        .map(_toSuggestion)
        .toList(growable: false);
  }

  /// Nominatim already returns coordinates with every hit, so there is nothing
  /// left to resolve.
  @override
  Future<AddressSuggestion> resolve(AddressSuggestion suggestion) async =>
      suggestion;

  @override
  Future<AddressSuggestion?> reverse(double latitude, double longitude) async {
    final uri = Uri.https(_host, '/reverse', {
      'lat': '$latitude',
      'lon': '$longitude',
      'format': 'jsonv2',
      'addressdetails': '1',
    });

    final decoded = jsonDecode(await _get(uri));
    if (decoded is! Map<String, dynamic> || decoded['display_name'] == null) {
      return null;
    }

    // /reverse has no country filter to put on the request — it resolves
    // whatever point you give it — so a tap outside Indonesia is rejected
    // after the fact using the country_code addressdetails already asked for.
    final address = decoded['address'] as Map<String, dynamic>?;
    if (address?['country_code'] != 'id') return null;

    return _toSuggestion(
      decoded,
    ).copyWith(latitude: latitude, longitude: longitude);
  }

  Future<String> _get(Uri uri) async {
    try {
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw AddressServiceException(
          'OpenStreetMap replied with ${response.statusCode}. Try again.',
        );
      }
      return response.body;
    } on AddressServiceException {
      rethrow;
    } catch (error) {
      throw const AddressServiceException(
        'Could not reach OpenStreetMap. Check your connection.',
      );
    }
  }

  AddressSuggestion _toSuggestion(Map<String, dynamic> json) {
    final displayName = (json['display_name'] as String?) ?? '';
    final parts = displayName.split(', ');
    return AddressSuggestion(
      description: displayName,
      placeId: json['place_id']?.toString(),
      latitude: double.tryParse('${json['lat']}'),
      longitude: double.tryParse('${json['lon']}'),
      secondaryText: parts.length > 1 ? parts.skip(1).join(', ') : null,
    );
  }

  @override
  void dispose() => _client.close();
}
