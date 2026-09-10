import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:receipt_printer/services/address_service.dart';
import 'package:receipt_printer/services/nominatim_address_service.dart';

void main() {
  const searchPayload = [
    {
      'place_id': '123',
      'display_name': 'Monas, Gambir, Central Jakarta, Jakarta, Indonesia',
      'lat': '-6.1753924',
      'lon': '106.8271528',
      'address': {'country': 'Indonesia', 'country_code': 'id'},
    },
  ];

  test('search maps Nominatim hits to suggestions with coordinates', () async {
    late Uri captured;
    final service = NominatimAddressService(
      client: MockClient((request) async {
        captured = request.url;
        return http.Response(jsonEncode(searchPayload), 200);
      }),
    );

    final results = await service.search('Monas');

    expect(captured.path, '/search');
    expect(captured.queryParameters['q'], 'Monas');
    expect(results, hasLength(1));
    expect(results.single.primaryText, 'Monas');
    expect(results.single.secondaryText, contains('Gambir'));
    expect(results.single.latitude, closeTo(-6.1753924, 0.000001));
    expect(results.single.hasCoordinates, isTrue);
  });

  test('search is restricted to Indonesia', () async {
    late Uri captured;
    final service = NominatimAddressService(
      client: MockClient((request) async {
        captured = request.url;
        return http.Response(jsonEncode(searchPayload), 200);
      }),
    );

    await service.search('Monas');

    expect(captured.queryParameters['countrycodes'], 'id');
  });

  test('short queries never hit the network', () async {
    var called = false;
    final service = NominatimAddressService(
      client: MockClient((_) async {
        called = true;
        return http.Response('[]', 200);
      }),
    );

    expect(await service.search('Mo'), isEmpty);
    expect(called, isFalse);
  });

  test('reverse geocoding keeps the tapped coordinates', () async {
    final service = NominatimAddressService(
      client: MockClient(
        (_) async => http.Response(jsonEncode(searchPayload.first), 200),
      ),
    );

    final result = await service.reverse(-6.2, 106.8);

    expect(result, isNotNull);
    expect(result!.latitude, -6.2);
    expect(result.longitude, 106.8);
    expect(result.description, contains('Monas'));
  });

  test('reverse geocoding rejects a point outside Indonesia', () async {
    // /reverse has no country filter to put on the request, so this must be
    // rejected after the fact using the address_details it already asked for.
    final malaysiaPayload = {
      ...searchPayload.first,
      'display_name': 'Petronas Towers, Kuala Lumpur, Malaysia',
      'address': {'country': 'Malaysia', 'country_code': 'my'},
    };
    final service = NominatimAddressService(
      client: MockClient(
        (_) async => http.Response(jsonEncode(malaysiaPayload), 200),
      ),
    );

    expect(await service.reverse(3.1579, 101.7116), isNull);
  });

  test('reverse geocoding rejects a point with no address details', () async {
    final noAddress = {
      'place_id': '999',
      'display_name': 'Somewhere in the ocean',
      'lat': '0',
      'lon': '0',
    };
    final service = NominatimAddressService(
      client: MockClient(
        (_) async => http.Response(jsonEncode(noAddress), 200),
      ),
    );

    expect(await service.reverse(0, 0), isNull);
  });

  test('surfaces a readable error when the provider fails', () async {
    final service = NominatimAddressService(
      client: MockClient((_) async => http.Response('boom', 503)),
    );

    expect(
      () => service.search('Monas'),
      throwsA(
        isA<AddressServiceException>().having(
          (e) => e.message,
          'message',
          contains('503'),
        ),
      ),
    );
  });
}
