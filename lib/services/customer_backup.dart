import 'dart:convert';

import '../models/customer.dart';

/// Reads and writes the customer-history backup file.
///
/// The file is plain JSON so it can be opened, checked or kept outside the
/// app. [version] lets a future format change be recognised on import.
class CustomerBackup {
  const CustomerBackup._();

  static const int version = 1;

  static String encode(List<Customer> customers, {DateTime? exportedAt}) {
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'receipt_printer',
      'type': 'customer_history',
      'version': version,
      'exportedAt': (exportedAt ?? DateTime.now()).toIso8601String(),
      'customers': customers.map((customer) => customer.toJson()).toList(),
    });
  }

  /// Throws [FormatException] when [source] is not a customer-history backup
  /// this app can read.
  static List<Customer> decode(String source) {
    final Object? root;
    try {
      root = jsonDecode(source);
    } on FormatException {
      throw const FormatException('File ini bukan cadangan yang valid.');
    }

    if (root is! Map<String, dynamic> ||
        root['type'] != 'customer_history' ||
        root['customers'] is! List<dynamic>) {
      throw const FormatException('File ini bukan cadangan data pelanggan.');
    }

    final version = root['version'];
    if (version is! int || version > CustomerBackup.version) {
      throw const FormatException(
        'Cadangan ini dibuat dengan versi aplikasi yang lebih baru.',
      );
    }

    try {
      return (root['customers'] as List<dynamic>)
          .map((item) => Customer.fromJson(item as Map<String, dynamic>))
          .toList();
    } on TypeError {
      throw const FormatException('Isi cadangan tidak lengkap atau rusak.');
    }
  }
}
