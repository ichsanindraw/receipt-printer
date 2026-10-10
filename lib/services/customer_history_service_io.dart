import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/customer.dart';
import '../models/receipt.dart';
import 'customer_history_service.dart';

/// SQLite-backed customer history, for the Android/iOS builds.
class SqliteCustomerHistoryService implements CustomerHistoryService {
  /// [databasePath] is overridable for tests, which run against
  /// [inMemoryDatabasePath] instead of a file under the app's real data
  /// directory.
  SqliteCustomerHistoryService({this.databasePath});

  final String? databasePath;

  static const _dbName = 'customer_history.db';
  static const _table = 'customers';

  Database? _db;

  Future<Database> _database() async {
    final opened = _db;
    if (opened != null) return opened;

    final dbPath = databasePath ?? path.join(await getDatabasesPath(), _dbName);
    final db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) => db.execute('''
        CREATE TABLE $_table (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT NOT NULL UNIQUE,
          address TEXT NOT NULL,
          products TEXT NOT NULL,
          notes TEXT NOT NULL DEFAULT '',
          latitude REAL,
          longitude REAL,
          last_ordered_at TEXT NOT NULL,
          order_count INTEGER NOT NULL DEFAULT 1
        )
      '''),
    );
    _db = db;
    return db;
  }

  @override
  Future<void> saveFromReceipt(Receipt receipt) async {
    final phone = receipt.toPhone.trim();
    final name = receipt.to.trim();
    if (phone.isEmpty || name.isEmpty) return;

    final db = await _database();
    final existing = await db.query(
      _table,
      columns: ['order_count'],
      where: 'phone = ?',
      whereArgs: [phone],
      limit: 1,
    );

    final values = <String, Object?>{
      'name': name,
      'phone': phone,
      'address': receipt.address.trim(),
      'products': receipt.products.join('\n'),
      'notes': receipt.notes.trim(),
      'latitude': receipt.latitude,
      'longitude': receipt.longitude,
      'last_ordered_at': receipt.issuedAt.toIso8601String(),
    };

    if (existing.isEmpty) {
      await db.insert(_table, {...values, 'order_count': 1});
    } else {
      final orderCount = (existing.first['order_count'] as int) + 1;
      await db.update(
        _table,
        {...values, 'order_count': orderCount},
        where: 'phone = ?',
        whereArgs: [phone],
      );
    }
  }

  @override
  Future<List<Customer>> search(String query, {int limit = 30}) async {
    final db = await _database();
    final trimmed = query.trim();
    final rows = trimmed.isEmpty
        ? await db.query(_table, orderBy: 'last_ordered_at DESC', limit: limit)
        : await db.query(
            _table,
            where: 'name LIKE ? OR phone LIKE ?',
            whereArgs: ['%$trimmed%', '%$trimmed%'],
            orderBy: 'last_ordered_at DESC',
            limit: limit,
          );
    return rows.map(_toCustomer).toList();
  }

  @override
  Future<void> delete(int id) async {
    final db = await _database();
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Customer _toCustomer(Map<String, Object?> row) => Customer(
    id: row['id']! as int,
    name: row['name']! as String,
    phone: row['phone']! as String,
    address: row['address']! as String,
    products: (row['products']! as String)
        .split('\n')
        .where((product) => product.isNotEmpty)
        .toList(),
    notes: row['notes'] as String? ?? '',
    latitude: row['latitude'] as double?,
    longitude: row['longitude'] as double?,
    lastOrderedAt: DateTime.parse(row['last_ordered_at']! as String),
    orderCount: row['order_count'] as int? ?? 1,
  );
}

CustomerHistoryService createCustomerHistoryService() =>
    SqliteCustomerHistoryService();
