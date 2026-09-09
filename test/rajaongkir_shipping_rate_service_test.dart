import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:receipt_printer/models/address_suggestion.dart';
import 'package:receipt_printer/models/shipping_quote.dart';
import 'package:receipt_printer/services/rajaongkir_shipping_rate_service.dart';
import 'package:receipt_printer/services/shipping_rate_service.dart';

void main() {
  // Trimmed from a live response so the parser is tested against the real
  // shape: an empty etd, a "3 day" etd, and POS's numeric junk description.
  const costPayload = {
    'meta': {
      'message': 'Success Calculate Domestic Shipping cost',
      'code': 200,
      'status': 'success',
    },
    'data': [
      {
        'name': 'Jalur Nugraha Ekakurir (JNE)',
        'code': 'jne',
        'service': 'REG',
        'description': 'Layanan Reguler',
        'cost': 12000,
        'etd': '1 day',
      },
      {
        'name': 'J&T Express',
        'code': 'jnt',
        'service': 'EZ',
        'description': 'Reguler',
        'cost': 15000,
        'etd': '',
      },
      {
        'name': 'POS Indonesia',
        'code': 'pos',
        'service': 'Pos Reguler',
        'description': '240',
        'cost': 9900,
        'etd': '2-4 day',
      },
      {
        'name': 'AnterAja',
        'code': 'anteraja',
        'service': 'SD',
        'description': 'Anteraja Same Day',
        'cost': 35300,
        'etd': '0 day',
      },
    ],
  };

  const placePayload = {
    'meta': {'message': 'ok', 'code': 200, 'status': 'success'},
    'data': [
      {
        'id': 17601,
        'label': 'GAMBIR, GAMBIR, JAKARTA PUSAT, DKI JAKARTA, 10110',
        'province_name': 'DKI JAKARTA',
        'city_name': 'JAKARTA PUSAT',
        'district_name': 'GAMBIR',
        'subdistrict_name': 'GAMBIR',
        'zip_code': '10110',
      },
    ],
  };

  RajaOngkirShippingRateService serviceReturning(
    Object payload, {
    int status = 200,
    void Function(http.Request request)? onRequest,
  }) {
    return RajaOngkirShippingRateService(
      apiKey: 'test-key',
      client: MockClient((request) async {
        onRequest?.call(request);
        return http.Response(jsonEncode(payload), status);
      }),
    );
  }

  const gambir = AddressSuggestion(description: 'GAMBIR', placeId: '17601');
  const dago = AddressSuggestion(description: 'DAGO', placeId: '4917');

  test('searchPlaces maps labels and ids', () async {
    late Uri captured;
    final service = serviceReturning(
      placePayload,
      onRequest: (request) => captured = request.url,
    );

    final places = await service.searchPlaces('gambir');

    expect(captured.path, '/api/v1/destination/domestic-destination');
    expect(captured.queryParameters['search'], 'gambir');
    expect(places.single.placeId, '17601');
    expect(places.single.primaryText, 'GAMBIR');
    expect(places.single.secondaryText, contains('JAKARTA PUSAT'));
  });

  test('short queries never hit the network', () async {
    var called = false;
    final service = serviceReturning(
      placePayload,
      onRequest: (_) => called = true,
    );

    expect(await service.searchPlaces('ga'), isEmpty);
    expect(called, isFalse);
  });

  test('quote posts the ids, weight and colon-joined couriers', () async {
    late http.Request captured;
    final service = serviceReturning(
      costPayload,
      onRequest: (request) => captured = request,
    );

    await service.quote(
      origin: gambir,
      destination: dago,
      weightGram: 1500,
      courierCodes: ['jne', 'jnt'],
    );

    expect(captured.method, 'POST');
    expect(captured.headers['key'], 'test-key');
    expect(captured.bodyFields, {
      'origin': '17601',
      'destination': '4917',
      'weight': '1500',
      'courier': 'jne:jnt',
    });
  });

  test('parses services, sorts cheapest first and tidies etd', () async {
    final service = serviceReturning(costPayload);

    final quotes = await service.quote(
      origin: gambir,
      destination: dago,
      weightGram: 1000,
      courierCodes: ['jne'],
    );

    expect(
      quotes.map((q) => q.cost),
      orderedEquals([9900, 12000, 15000, 35300]),
    );

    final pos = quotes.firstWhere((q) => q.courierCode == 'pos');
    expect(pos.courierName, 'POS');
    expect(pos.etd, '2-4 hari');
    expect(pos.description, '', reason: 'numeric junk description is dropped');

    ShippingQuote byCourier(String code) =>
        quotes.firstWhere((q) => q.courierCode == code);

    expect(byCourier('jne').etd, '1 hari');
    expect(byCourier('jnt').etd, '-', reason: 'empty etd becomes a dash');
    expect(byCourier('anteraja').etd, 'Hari ini', reason: '0 day is same-day');
  });

  test('surfaces the API message when the meta code is not 200', () async {
    final service = serviceReturning({
      'meta': {'message': 'Invalid courier', 'code': 422, 'status': 'error'},
      'data': null,
    });

    expect(
      () => service.quote(
        origin: gambir,
        destination: dago,
        weightGram: 1000,
        courierCodes: ['nope'],
      ),
      throwsA(
        isA<ShippingRateException>().having(
          (e) => e.message,
          'message',
          'Invalid courier',
        ),
      ),
    );
  });

  test('calls out a rejected API key', () async {
    final service = serviceReturning(const {}, status: 401);

    expect(
      () => service.searchPlaces('gambir'),
      throwsA(
        isA<ShippingRateException>().having(
          (e) => e.message,
          'message',
          contains('API key'),
        ),
      ),
    );
  });

  test('requires a place id on both ends', () {
    final service = serviceReturning(costPayload);

    expect(
      () => service.quote(
        origin: const AddressSuggestion(description: 'no id'),
        destination: dago,
        weightGram: 1000,
        courierCodes: ['jne'],
      ),
      throwsA(isA<ShippingRateException>()),
    );
  });
}
