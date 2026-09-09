/// A single address candidate returned by an [AddressService].
class AddressSuggestion {
  const AddressSuggestion({
    required this.description,
    this.placeId,
    this.latitude,
    this.longitude,
    this.secondaryText,
  });

  /// Full, human readable address — what we drop into the form field.
  final String description;

  /// Provider specific id, used to look up coordinates when the autocomplete
  /// response does not include them (Google Places works this way).
  final String? placeId;

  final double? latitude;
  final double? longitude;

  /// Optional smaller line shown under [description] in the suggestion list.
  final String? secondaryText;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// First line of the address — the part worth showing in bold in a list.
  String get primaryText {
    final separator = description.indexOf(', ');
    return separator == -1 ? description : description.substring(0, separator);
  }

  AddressSuggestion copyWith({
    String? description,
    String? placeId,
    double? latitude,
    double? longitude,
    String? secondaryText,
  }) {
    return AddressSuggestion(
      description: description ?? this.description,
      placeId: placeId ?? this.placeId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      secondaryText: secondaryText ?? this.secondaryText,
    );
  }

  @override
  String toString() => 'AddressSuggestion($description, $latitude, $longitude)';
}
