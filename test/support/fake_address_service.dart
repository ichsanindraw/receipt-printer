import 'package:receipt_printer/models/address_suggestion.dart';
import 'package:receipt_printer/services/address_service.dart';

/// Minimal stand-in for a geocoder. The receipt form only calls [search],
/// [resolve] or [reverse] when the user interacts with the address
/// autocomplete or the map, so tests that don't exercise those can leave
/// this unconfigured.
class FakeAddressService implements AddressService {
  FakeAddressService({this.providerLabel = 'Fake', this.attribution = ''});

  @override
  final String providerLabel;

  @override
  final String attribution;

  @override
  Future<List<AddressSuggestion>> search(String query) async => const [];

  @override
  Future<AddressSuggestion> resolve(AddressSuggestion suggestion) async =>
      suggestion;

  @override
  Future<AddressSuggestion?> reverse(double latitude, double longitude) async =>
      null;

  @override
  void dispose() {}
}
