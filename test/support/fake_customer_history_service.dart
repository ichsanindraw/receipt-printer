import 'package:receipt_printer/models/customer.dart';
import 'package:receipt_printer/models/receipt.dart';
import 'package:receipt_printer/services/customer_history_service.dart';

/// Stands in for the local database, which widget tests cannot open.
class FakeCustomerHistoryService implements CustomerHistoryService {
  FakeCustomerHistoryService({List<Customer> customers = const []})
    : _customers = List.of(customers);

  final List<Customer> _customers;

  /// Receipts handed to [saveFromReceipt], most recent last.
  final List<Receipt> saved = [];

  @override
  Future<void> saveFromReceipt(Receipt receipt) async {
    saved.add(receipt);
  }

  @override
  Future<List<Customer>> search(String query, {int limit = 30}) async {
    final trimmed = query.trim().toLowerCase();
    final matches = trimmed.isEmpty
        ? _customers
        : _customers.where(
            (customer) =>
                customer.name.toLowerCase().contains(trimmed) ||
                customer.phone.contains(trimmed),
          );
    return matches.take(limit).toList();
  }

  @override
  Future<void> delete(int id) async {
    _customers.removeWhere((customer) => customer.id == id);
  }
}
