import 'package:intl/intl.dart';

/// Everything the form collects, and everything the printed receipt shows.
class Receipt {
  const Receipt({
    required this.number,
    required this.from,
    required this.to,
    required this.phone,
    required this.productName,
    required this.address,
    required this.issuedAt,
    this.latitude,
    this.longitude,
  });

  /// Receipt / order number, e.g. `RCP-20260909-1432`.
  final String number;

  /// Sender name.
  final String from;

  /// Recipient name.
  final String to;

  /// Recipient phone number.
  final String phone;

  final String productName;

  /// Delivery address, normally picked from the map autocomplete.
  final String address;

  final double? latitude;
  final double? longitude;

  final DateTime issuedAt;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// The receipt number is optional, so printing and file names fall back to
  /// the issue date rather than producing a bare `receipt-`.
  String get fileLabel {
    if (number.trim().isEmpty) {
      return 'receipt-${DateFormat('yyyyMMdd-HHmm').format(issuedAt)}';
    }
    return 'receipt-${number.trim()}';
  }

  String get formattedIssuedAt =>
      DateFormat('dd MMM yyyy, HH:mm').format(issuedAt);

  String get formattedCoordinates => hasCoordinates
      ? '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}'
      : '';

  /// Deep link that opens the delivery address in Google Maps. Encoded into the
  /// QR code on the printed receipt so a courier can scan and navigate.
  String? get mapsUrl => hasCoordinates
      ? 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude'
      : null;

  /// A sensible default receipt number based on the current time.
  static String generateNumber([DateTime? now]) {
    final stamp = DateFormat('yyyyMMdd-HHmm').format(now ?? DateTime.now());
    return 'RCP-$stamp';
  }
}
