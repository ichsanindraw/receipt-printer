import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:receipt_printer/services/google_places_address_service.dart';

void main() {
  const autocompletePayload = {
    'suggestions': [
      {
        'placePrediction': {
          'placeId': 'abc123',
          'text': {
            'text': 'Monas, Gambir, Central Jakarta, Jakarta, Indonesia',
          },
          'structuredFormat': {
            'mainText': {'text': 'Monas'},
            'secondaryText': {
              'text': 'Gambir, Central Jakarta, Jakarta, Indonesia',
            },
          },
        },
      },
    ],
  };

  GooglePlacesAddressService serviceReturning(
    Object payload, {
    void Function(http.Request request)? onRequest,
  }) {
    return GooglePlacesAddressService(
      apiKey: 'test-key',
      client: MockClient((request) async {
        onRequest?.call(request);
        return http.Response(jsonEncode(payload), 200);
      }),
    );
  }

  test('search maps predictions to suggestions', () async {
    final service = serviceReturning(autocompletePayload);

    final results = await service.search('Monas');

    expect(results, hasLength(1));
    expect(results.single.placeId, 'abc123');
    expect(results.single.primaryText, contains('Monas'));
  });

  test('search is restricted to Indonesia', () async {
    late Map<String, dynamic> body;
    final service = serviceReturning(
      autocompletePayload,
      onRequest: (request) =>
          body = jsonDecode(request.body) as Map<String, dynamic>,
    );

    await service.search('Monas');

    expect(body['includedRegionCodes'], ['ID']);
  });

  test('short queries never hit the network', () async {
    var called = false;
    final service = serviceReturning(
      autocompletePayload,
      onRequest: (_) => called = true,
    );

    expect(await service.search('Mo'), isEmpty);
    expect(called, isFalse);
  });

  group('reverse geocoding', () {
    Map<String, dynamic> geocodePayload({
      required String countryShortName,
      String formattedAddress = 'Monas, Jakarta, Indonesia',
    }) {
      return {
        'results': [
          {
            'formatted_address': formattedAddress,
            'place_id': 'xyz789',
            'address_components': [
              {
                'long_name': countryShortName == 'ID' ? 'Indonesia' : 'Other',
                'short_name': countryShortName,
                'types': ['country', 'political'],
              },
            ],
          },
        ],
      };
    }

    test('keeps the tapped coordinates for a point in Indonesia', () async {
      final service = serviceReturning(geocodePayload(countryShortName: 'ID'));

      final result = await service.reverse(-6.2, 106.8);

      expect(result, isNotNull);
      expect(result!.latitude, -6.2);
      expect(result.longitude, 106.8);
      expect(result.placeId, 'xyz789');
    });

    test('rejects a point outside Indonesia', () async {
      // The Geocoding API's region biasing only affects forward geocoding,
      // so this must be rejected after the fact via the country component.
      final service = serviceReturning(
        geocodePayload(
          countryShortName: 'MY',
          formattedAddress: 'Petronas Towers, Kuala Lumpur, Malaysia',
        ),
      );

      expect(await service.reverse(3.1579, 101.7116), isNull);
    });

    test('rejects a result with no country component at all', () async {
      final service = serviceReturning({
        'results': [
          {
            'formatted_address': 'Somewhere',
            'place_id': 'q',
            'address_components': <Map<String, dynamic>>[],
          },
        ],
      });

      expect(await service.reverse(0, 0), isNull);
    });

    test('returns null when there are no results', () async {
      final service = serviceReturning({'results': <dynamic>[]});

      expect(await service.reverse(0, 0), isNull);
    });
  });
}
