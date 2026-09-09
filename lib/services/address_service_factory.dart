import '../config/app_config.dart';
import 'address_service.dart';
import 'google_places_address_service.dart';
import 'nominatim_address_service.dart';

/// Picks the geocoding provider for this build: Google Places when a key was
/// supplied, OpenStreetMap otherwise.
AddressService createAddressService() {
  if (AppConfig.hasGooglePlacesKey) {
    return GooglePlacesAddressService(apiKey: AppConfig.googlePlacesApiKey);
  }
  return NominatimAddressService();
}
