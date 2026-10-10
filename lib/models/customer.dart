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

  String get productSummary => products.join(', ');

  String get formattedLastOrderedAt =>
      DateFormat('dd MMM yyyy').format(lastOrderedAt);
}
