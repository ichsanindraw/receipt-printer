import '../models/customer.dart';
import '../models/receipt.dart';

// sqflite only ships Android/iOS implementations, so the web build falls
// back to an in-memory store — the same per-platform split as the thermal
// printer service.
import 'customer_history_service_unsupported.dart'
    if (dart.library.io) 'customer_history_service_io.dart'
    as impl;

/// Keeps track of customers who have ordered before, so a repeat order can
/// be searched and applied to the form instead of retyped.
///
/// There is no backend yet, so this is the system of record for customer
/// history: persisted locally, keyed by phone number.
abstract class CustomerHistoryService {
  /// Upserts the recipient from [receipt]: a repeat phone number refreshes
  /// the stored address, products and notes and bumps the order count
  /// rather than creating a duplicate. Does nothing when the recipient has
  /// no name or phone — there is nothing to key a repeat order on.
  Future<void> saveFromReceipt(Receipt receipt);

  /// Customers matching [query] by name or phone, most recently ordered
  /// first. A blank query returns the most recent customers overall.
  Future<List<Customer>> search(String query, {int limit = 30});

  /// Removes a customer from the history, e.g. after a typo.
  Future<void> delete(int id);
}

CustomerHistoryService createCustomerHistoryService() =>
    impl.createCustomerHistoryService();
