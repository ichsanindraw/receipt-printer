import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/address_suggestion.dart';
import '../models/courier.dart';
import '../models/shipping_quote.dart';
import 'shipping_rate_service.dart';

/// RajaOngkir V2 (Komerce) — real courier tariffs.
///
/// Activated when a key is supplied:
/// `flutter run --dart-define=RAJAONGKIR_API_KEY=...`
///
/// Places come from RajaOngkir's own kecamatan-level database rather than the
/// map geocoder, because the cost endpoint addresses locations by their
/// RajaOngkir id.
class RajaOngkirShippingRateService implements ShippingRateService {
  RajaOngkirShippingRateService({required this.apiKey, http.Client? client})
    : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  static const String _host = 'rajaongkir.komerce.id';

  @override
  String get providerLabel => 'RajaOngkir';

  @override
  bool get isEstimate => false;

  @override
  String get disclaimer =>
      'Live tariffs from RajaOngkir. Volume weight and insurance are not '
      'included.';

  @override
  List<Courier> get couriers => Courier.all;

  @override
  Future<List<AddressSuggestion>> searchPlaces(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return const [];

    final response = await _send(
      () => _client.get(
        Uri.https(_host, '/api/v1/destination/domestic-destination', {
          'search': trimmed,
          'limit': '10',
          'offset': '0',
        }),
        headers: {'key': apiKey},
      ),
    );

    final places = _data(response);
    return places
        .whereType<Map<String, dynamic>>()
        .map((place) {
          final label = (place['label'] as String?) ?? '';
          final separator = label.indexOf(', ');
          return AddressSuggestion(
            description: label,
            placeId: place['id']?.toString(),
            secondaryText: separator == -1
                ? null
                : label.substring(separator + 2),
          );
        })
        .toList(growable: false);
  }

  /// Search results already carry the id the cost endpoint needs.
  @override
  Future<AddressSuggestion> resolvePlace(AddressSuggestion place) async =>
      place;

  @override
  Future<List<ShippingQuote>> quote({
    required AddressSuggestion origin,
    required AddressSuggestion destination,
    required int weightGram,
    required List<String> courierCodes,
  }) async {
    final originId = origin.placeId;
    final destinationId = destination.placeId;
    if (originId == null || destinationId == null) {
      throw const ShippingRateException(
        'Pick both places from the suggestions.',
      );
    }
    if (courierCodes.isEmpty) {
      throw const ShippingRateException('Choose at least one courier.');
    }

    final response = await _send(
      () => _client.post(
        Uri.https(_host, '/api/v1/calculate/domestic-cost'),
        headers: {
          'key': apiKey,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'origin': originId,
          'destination': destinationId,
          'weight': '$weightGram',
          'courier': courierCodes.join(':'),
        },
      ),
    );

    final quotes = _data(
      response,
    ).whereType<Map<String, dynamic>>().map(_toQuote).toList();
    quotes.sort((a, b) => a.cost.compareTo(b.cost));
    return quotes;
  }

  ShippingQuote _toQuote(Map<String, dynamic> json) {
    final code = (json['code'] as String?) ?? '';
    final description = (json['description'] as String?)?.trim() ?? '';
    return ShippingQuote(
      courierCode: code,
      courierName: Courier.nameFor(code),
      service: (json['service'] as String?) ?? '-',
      // POS returns internal numeric codes here; drop those.
      description: int.tryParse(description) == null ? description : '',
      cost: (json['cost'] as num?)?.round() ?? 0,
      etd: _etd(json['etd'] as String?),
    );
  }

  /// RajaOngkir returns `''`, `'3 day'`, `'2-4 day'` or `'0 day'`.
  static String _etd(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return '-';
    final normalised = value.replaceAll(RegExp(r'\s*days?$'), '').trim();
    if (normalised == '0') return 'Hari ini';
    return '$normalised hari';
  }

  List<dynamic> _data(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return const [];

    final meta = decoded['meta'] as Map<String, dynamic>?;
    final code = (meta?['code'] as num?)?.toInt() ?? 200;
    if (code != 200) {
      throw ShippingRateException(
        (meta?['message'] as String?) ?? 'RajaOngkir returned an error.',
      );
    }
    return decoded['data'] as List<dynamic>? ?? const [];
  }

  Future<String> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(const Duration(seconds: 15));
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const ShippingRateException(
          'RajaOngkir rejected the API key. Check RAJAONGKIR_API_KEY.',
        );
      }
      if (response.statusCode != 200) {
        throw ShippingRateException(
          'RajaOngkir replied with ${response.statusCode}.',
        );
      }
      return response.body;
    } on ShippingRateException {
      rethrow;
    } catch (error) {
      throw const ShippingRateException(
        'Could not reach RajaOngkir. Check your connection.',
      );
    }
  }

  @override
  void dispose() => _client.close();
}
