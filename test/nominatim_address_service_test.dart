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
