import '../models/customer.dart';
import '../models/receipt.dart';
import 'customer_history_service.dart';

/// Web build: sqflite has no web implementation. Customer history still
/// works within the session; it just does not survive a page reload.
class InMemoryCustomerHistoryService implements CustomerHistoryService {
  InMemoryCustomerHistoryService();

  final Map<String, Customer> _byPhone = {};
  int _nextId = 1;

  @override
  Future<void> saveFromReceipt(Receipt receipt) async {
    final phone = receipt.toPhone.trim();
    final name = receipt.to.trim();
    if (phone.isEmpty || name.isEmpty) return;

    final existing = _byPhone[phone];
    _byPhone[phone] = Customer(
      id: existing?.id ?? _nextId++,
      name: name,
      phone: phone,
      address: receipt.address.trim(),
      products: receipt.products,
      notes: receipt.notes.trim(),
      latitude: receipt.latitude,
      longitude: receipt.longitude,
      lastOrderedAt: receipt.issuedAt,
      orderCount: (existing?.orderCount ?? 0) + 1,
    );
  }

  @override
  Future<List<Customer>> search(String query, {int limit = 30}) async {
    final trimmed = query.trim().toLowerCase();
    final matches =
        _byPhone.values
            .where(
              (customer) =>
                  trimmed.isEmpty ||
                  customer.name.toLowerCase().contains(trimmed) ||
                  customer.phone.contains(trimmed),
            )
            .toList()
          ..sort((a, b) => b.lastOrderedAt.compareTo(a.lastOrderedAt));
    return matches.take(limit).toList();
  }

  @override
  Future<void> delete(int id) async {
    _byPhone.removeWhere((_, customer) => customer.id == id);
  }
}

CustomerHistoryService createCustomerHistoryService() =>
    InMemoryCustomerHistoryService();
