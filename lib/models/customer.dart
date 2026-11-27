import 'package:intl/intl.dart';

/// A recipient who has ordered before, kept so a repeat order can be found
/// and applied to the form instead of retyped from scratch.
///
/// There is no backend yet, so this doubles as the local order history:
/// printing a receipt refreshes the matching customer (keyed by phone
/// number) rather than creating a new row.
class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.products,
    required this.lastOrderedAt,
    required this.orderCount,
    this.notes = '',
    this.latitude,
    this.longitude,
  });

  final int id;
  final String name;
  final String phone;
  final String address;

  /// Products from the most recent order, in the order they were entered.
  final List<String> products;

  final String notes;
  final double? latitude;
  final double? longitude;
  final DateTime lastOrderedAt;
  final int orderCount;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// Backup form. The local [id] is left out: it is only meaningful inside
  /// the database that assigned it, and a restore assigns fresh ids.
  Map<String, Object?> toJson() => {
    'name': name,
    'phone': phone,
    'address': address,
    'products': products,
    'notes': notes,
    'latitude': latitude,
    'longitude': longitude,
    'lastOrderedAt': lastOrderedAt.toIso8601String(),
    'orderCount': orderCount,
  };

  /// Reads the backup form. Throws [FormatException] or [TypeError] when a
  /// required field is missing or malformed.
  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: 0,
    name: json['name'] as String,
    phone: json['phone'] as String,
    address: json['address'] as String,
    products: (json['products'] as List<dynamic>).cast<String>(),
    notes: json['notes'] as String? ?? '',
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    lastOrderedAt: DateTime.parse(json['lastOrderedAt'] as String),
    orderCount: json['orderCount'] as int? ?? 1,
  );

  String get productSummary => products.join(', ');

  String get formattedLastOrderedAt =>
      DateFormat('dd MMM yyyy').format(lastOrderedAt);
}
