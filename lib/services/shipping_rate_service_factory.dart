import '../config/app_config.dart';
import 'address_service.dart';
import 'estimated_shipping_rate_service.dart';
import 'rajaongkir_shipping_rate_service.dart';
import 'shipping_rate_service.dart';

/// Real tariffs when a RajaOngkir key was supplied, distance-based estimates
/// otherwise. [geocoder] is only used by the estimator, which needs
/// coordinates; it is not disposed here when RajaOngkir wins.
ShippingRateService createShippingRateService({
  required AddressService geocoder,
}) {
  if (AppConfig.hasRajaOngkirKey) {
    return RajaOngkirShippingRateService(apiKey: AppConfig.rajaOngkirApiKey);
  }
  return EstimatedShippingRateService(geocoder: geocoder);
}
