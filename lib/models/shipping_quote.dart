/// One quoted shipping service.
class ShippingQuote {
  const ShippingQuote({
    required this.courierCode,
    required this.courierName,
    required this.service,
    required this.description,
    required this.cost,
    required this.etd,
  });

  final String courierCode;
  final String courierName;

  /// Service code, e.g. `REG`, `YES`, `BEST`.
  final String service;

  final String description;

  /// Cost in rupiah.
  final int cost;

  /// Estimated delivery, e.g. `2-3 hari`.
  final String etd;

  /// `1234567` -> `Rp 1.234.567`, without needing intl locale data.
  String get formattedCost {
    final digits = cost.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return 'Rp $buffer';
  }
}
