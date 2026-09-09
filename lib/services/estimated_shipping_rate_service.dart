import 'dart:math' as math;

import '../models/address_suggestion.dart';
import '../models/courier.dart';
import '../models/shipping_quote.dart';
import 'address_service.dart';
import 'shipping_rate_service.dart';

/// Offline shipping estimator — the default, because every Indonesian rate
/// API (RajaOngkir, Binderbyte, AgenWebsite …) needs an account and a key.
///
/// It reuses the coordinates the map geocoder already gives us and prices the
/// great-circle distance against a per-courier tariff table. Real couriers
/// price by zone rather than by kilometre, so these are **estimates**, close
/// enough to sanity-check a delivery but not to bill a customer. Supply a
/// RajaOngkir key to get quoted tariffs instead.
class EstimatedShippingRateService implements ShippingRateService {
  const EstimatedShippingRateService({required this.geocoder});

  final AddressService geocoder;

  @override
  String get providerLabel => 'Estimasi';

  @override
  bool get isEstimate => true;

  @override
  String get disclaimer =>
      'Estimated from the distance between the two pins, not quoted by the '
      'courier. Add a RajaOngkir key for real tariffs.';

  @override
  List<Courier> get couriers => Courier.all;

  @override
  Future<List<AddressSuggestion>> searchPlaces(String query) =>
      geocoder.search(query);

  @override
  Future<AddressSuggestion> resolvePlace(AddressSuggestion place) =>
      geocoder.resolve(place);

  @override
  Future<List<ShippingQuote>> quote({
    required AddressSuggestion origin,
    required AddressSuggestion destination,
    required int weightGram,
    required List<String> courierCodes,
  }) async {
    if (!origin.hasCoordinates || !destination.hasCoordinates) {
      throw const ShippingRateException(
        'Pick both places from the suggestions so their coordinates are known.',
      );
    }

    final distanceKm = distanceBetween(
      origin.latitude!,
      origin.longitude!,
      destination.latitude!,
      destination.longitude!,
    );
    final band = _bandFor(distanceKm);
    final billableKg = math.max(1, (weightGram / 1000).ceil());

    final quotes = <ShippingQuote>[];
    for (final code in courierCodes) {
      final profile = _profiles[code];
      if (profile == null) continue;

      for (final service in profile.services) {
        final raw =
            band.baseTariff *
            profile.priceIndex *
            service.multiplier *
            billableKg;
        quotes.add(
          ShippingQuote(
            courierCode: code,
            courierName: Courier.nameFor(code),
            service: service.code,
            description: service.description,
            cost: _roundTo500(math.max(raw, _minimumTariff.toDouble())),
            etd: band.etd(service.dayOffset),
          ),
        );
      }
    }

    quotes.sort((a, b) => a.cost.compareTo(b.cost));
    return quotes;
  }

  /// The geocoder is borrowed from the receipt tab, which owns and disposes
  /// it. Closing it here would break address autocomplete on that tab.
  @override
  void dispose() {}

  /// Great-circle distance in kilometres.
  static double distanceBetween(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0088;
    double toRadians(double degrees) => degrees * math.pi / 180;

    final dLat = toRadians(lat2 - lat1);
    final dLon = toRadians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(toRadians(lat1)) *
            math.cos(toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static int _roundTo500(double value) => (value / 500).round() * 500;

  static const int _minimumTariff = 8000;

  static _Band _bandFor(double km) =>
      _bands.firstWhere((band) => km <= band.maxKm);

  /// First-kilogram tariff by distance band, in rupiah, calibrated against
  /// live JNE/SiCepat/AnterAja reguler quotes: Jakarta-Bandung (~120 km) is
  /// Rp 11-12k, Jakarta-Surabaya (~660 km) ~Rp 24k, Jakarta-Makassar
  /// (~1450 km) ~Rp 40k. Couriers actually price by zone, so the further the
  /// route the looser this gets.
  static const List<_Band> _bands = [
    _Band(maxKm: 25, baseTariff: 10000, minDays: 1, maxDays: 1),
    _Band(maxKm: 150, baseTariff: 11500, minDays: 1, maxDays: 2),
    _Band(maxKm: 400, baseTariff: 15000, minDays: 2, maxDays: 3),
    _Band(maxKm: 800, baseTariff: 22000, minDays: 2, maxDays: 4),
    _Band(maxKm: 1500, baseTariff: 36000, minDays: 3, maxDays: 5),
    _Band(maxKm: 2500, baseTariff: 52000, minDays: 4, maxDays: 7),
    _Band(maxKm: double.infinity, baseTariff: 80000, minDays: 5, maxDays: 9),
  ];

  /// Per-courier price position and the services each one sells.
  static const Map<String, _CourierProfile> _profiles = {
    'jne': _CourierProfile(
      priceIndex: 1.00,
      services: [
        _Service('OKE', 'Ongkos Kirim Ekonomis', 0.85, 1),
        _Service('REG', 'Layanan Reguler', 1.00, 0),
        _Service('YES', 'Yakin Esok Sampai', 1.75, -2),
      ],
    ),
    'jnt': _CourierProfile(
      priceIndex: 0.97,
      services: [
        _Service('ECO', 'Ekonomi', 0.85, 1),
        _Service('EZ', 'Reguler', 1.00, 0),
      ],
    ),
    'sicepat': _CourierProfile(
      priceIndex: 0.95,
      services: [
        _Service('GOKIL', 'Cargo Kilat', 0.70, 2),
        _Service('REG', 'Layanan Reguler', 1.00, 0),
        _Service('BEST', 'Besok Sampai Tujuan', 1.80, -2),
      ],
    ),
    'anteraja': _CourierProfile(
      priceIndex: 0.93,
      services: [
        _Service('REG', 'Reguler', 1.00, 0),
        _Service('NEXTDAY', 'Next Day', 1.70, -2),
      ],
    ),
    'pos': _CourierProfile(
      priceIndex: 0.90,
      services: [
        _Service('KARGO', 'Pos Kargo', 0.65, 3),
        _Service('REG', 'Pos Reguler', 1.00, 0),
      ],
    ),
    'tiki': _CourierProfile(
      priceIndex: 1.05,
      services: [
        _Service('ECO', 'Ekonomi', 0.85, 1),
        _Service('REG', 'Reguler', 1.00, 0),
        _Service('ONS', 'Over Night Service', 1.80, -2),
      ],
    ),
    'ninja': _CourierProfile(
      priceIndex: 0.92,
      services: [_Service('STANDARD', 'Standard', 1.00, 0)],
    ),
    'lion': _CourierProfile(
      priceIndex: 0.88,
      services: [
        _Service('BIGPACK', 'Kargo', 0.65, 2),
        _Service('REGPACK', 'Reguler', 1.00, 0),
        _Service('ONEPACK', 'One Day Service', 1.70, -2),
      ],
    ),
  };
}

class _Band {
  const _Band({
    required this.maxKm,
    required this.baseTariff,
    required this.minDays,
    required this.maxDays,
  });

  final double maxKm;
  final int baseTariff;
  final int minDays;
  final int maxDays;

  String etd(int dayOffset) {
    final min = math.max(1, minDays + dayOffset);
    final max = math.max(min, maxDays + dayOffset);
    return min == max ? '$min hari' : '$min-$max hari';
  }
}

class _CourierProfile {
  const _CourierProfile({required this.priceIndex, required this.services});

  /// Where the courier sits against JNE reguler, which is 1.00.
  final double priceIndex;
  final List<_Service> services;
}

class _Service {
  const _Service(this.code, this.description, this.multiplier, this.dayOffset);

  final String code;
  final String description;

  /// Against the courier's own reguler service.
  final double multiplier;

  /// Shifts the band's delivery window; negative is faster.
  final int dayOffset;
}
