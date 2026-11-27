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

  /// Every stored customer, most recently ordered first. Used for backup.
  Future<List<Customer>> all();

  /// Merges [customers] from a backup into the history, keyed by phone.
  /// A new phone is added. A phone already stored keeps whichever record
  /// was ordered most recently, and its order count becomes the higher of
  /// the two, so restoring twice does not double-count. Returns how many
  /// customers were added or updated.
  Future<int> merge(List<Customer> customers);
}

/// Merge rule shared by both implementations: the newer order wins the
/// details, and the larger order count wins the count.
Customer mergeCustomer(Customer existing, Customer incoming) {
  final incomingIsNewer = incoming.lastOrderedAt.isAfter(
    existing.lastOrderedAt,
  );
  final newer = incomingIsNewer ? incoming : existing;
  final orderCount = incoming.orderCount > existing.orderCount
      ? incoming.orderCount
      : existing.orderCount;
  return Customer(
    id: existing.id,
    name: newer.name,
    phone: existing.phone,
    address: newer.address,
    products: newer.products,
    notes: newer.notes,
    latitude: newer.latitude,
    longitude: newer.longitude,
    lastOrderedAt: newer.lastOrderedAt,
    orderCount: orderCount,
  );
}

CustomerHistoryService createCustomerHistoryService() =>
    impl.createCustomerHistoryService();
