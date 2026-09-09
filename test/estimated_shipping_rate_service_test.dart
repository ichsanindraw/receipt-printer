import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:receipt_printer/models/address_suggestion.dart';
import 'package:receipt_printer/services/estimated_shipping_rate_service.dart';
import 'package:receipt_printer/services/nominatim_address_service.dart';
import 'package:receipt_printer/services/shipping_rate_service.dart';

void main() {
  final service = EstimatedShippingRateService(
    geocoder: NominatimAddressService(
      client: MockClient((_) async => http.Response('[]', 200)),
    ),
  );

  // Monas, Jakarta and Gedung Sate, Bandung — about 120 km apart.
  const jakarta = AddressSuggestion(
    description: 'Monas, Jakarta',
    latitude: -6.1754,
    longitude: 106.8272,
  );
  const bandung = AddressSuggestion(
    description: 'Gedung Sate, Bandung',
    latitude: -6.9025,
    longitude: 107.6186,
  );
  const makassar = AddressSuggestion(
    description: 'Makassar',
    latitude: -5.1477,
    longitude: 119.4327,
  );

  group('distance', () {
    test('Jakarta to Bandung is about 120 km', () {
      final km = EstimatedShippingRateService.distanceBetween(
        jakarta.latitude!,
        jakarta.longitude!,
        bandung.latitude!,
        bandung.longitude!,
      );
      expect(km, closeTo(120, 8));
    });

    test('a point to itself is zero', () {
      expect(
        EstimatedShippingRateService.distanceBetween(-6.2, 106.8, -6.2, 106.8),
        0,
      );
    });
  });

  group('quotes', () {
    test('prices Jakarta to Bandung near the real reguler tariff', () async {
      final quotes = await service.quote(
        origin: jakarta,
        destination: bandung,
        weightGram: 1000,
        courierCodes: ['jne'],
      );

      final reguler = quotes.firstWhere((q) => q.service == 'REG');
      // Live JNE REG on this route is Rp 12.000.
      expect(reguler.cost, inInclusiveRange(9000, 16000));
      expect(reguler.courierName, 'JNE');
      expect(reguler.formattedCost, matches(RegExp(r'^Rp \d{1,3}\.\d{3}$')));
    });

    test('a longer route costs more than a shorter one', () async {
      Future<int> regulerCost(AddressSuggestion destination) async {
        final quotes = await service.quote(
          origin: jakarta,
          destination: destination,
          weightGram: 1000,
          courierCodes: ['jne'],
        );
        return quotes.firstWhere((q) => q.service == 'REG').cost;
      }

      expect(
        await regulerCost(makassar),
        greaterThan(await regulerCost(bandung)),
      );
    });

    test('weight is billed per rounded-up kilogram', () async {
      Future<int> costFor(int gram) async {
        final quotes = await service.quote(
          origin: jakarta,
          destination: bandung,
          weightGram: gram,
          courierCodes: ['jne'],
        );
        return quotes.firstWhere((q) => q.service == 'REG').cost;
      }

      final oneKg = await costFor(1000);
      expect(await costFor(300), oneKg, reason: 'under 1 kg bills as 1 kg');
      expect(await costFor(1200), oneKg * 2, reason: '1.2 kg bills as 2 kg');
      expect(await costFor(3000), oneKg * 3);
    });

    test('results are sorted cheapest first', () async {
      final quotes = await service.quote(
        origin: jakarta,
        destination: bandung,
        weightGram: 1000,
        courierCodes: ['jne', 'jnt', 'sicepat', 'pos'],
      );

      expect(quotes.length, greaterThan(4));
      final costs = quotes.map((q) => q.cost).toList();
      expect(costs, orderedEquals([...costs]..sort()));
    });

    test('express services cost more and arrive sooner than reguler', () async {
      final quotes = await service.quote(
        origin: jakarta,
        destination: makassar,
        weightGram: 1000,
        courierCodes: ['jne'],
      );

      final reguler = quotes.firstWhere((q) => q.service == 'REG');
      final express = quotes.firstWhere((q) => q.service == 'YES');
      expect(express.cost, greaterThan(reguler.cost));
      expect(express.etd, isNot(reguler.etd));
    });

    test('unknown courier codes are skipped rather than throwing', () async {
      final quotes = await service.quote(
        origin: jakarta,
        destination: bandung,
        weightGram: 1000,
        courierCodes: ['jne', 'notacourier'],
      );

      expect(quotes.every((q) => q.courierCode == 'jne'), isTrue);
    });

    test('refuses to quote without coordinates on both ends', () {
      expect(
        () => service.quote(
          origin: jakarta,
          destination: const AddressSuggestion(description: 'Somewhere'),
          weightGram: 1000,
          courierCodes: ['jne'],
        ),
        throwsA(isA<ShippingRateException>()),
      );
    });
  });
}
