// lib/services/database_helper.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Simple logging function
void _log(String message) {
  if (kDebugMode) {
    print('[DatabaseHelper] $message');
  }
}

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  // Helper method to get first int value from query results
  int? _getFirstIntValue(List<Map<String, dynamic>>? results) {
    if (results == null || results.isEmpty) return null;
    final first = results.first;
    if (first.containsKey('count')) {
      final value = first['count'];
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
    }
    return null;
  }

  // ============================================
  // INITIALIZATION
  // ============================================

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    Directory documentsDirectory;
    if (kIsWeb) {
      throw Exception('Web platform not supported yet');
    } else {
      documentsDirectory = await getApplicationDocumentsDirectory();
    }

    final path = join(documentsDirectory.path, 'quickfix.db');

    return await openDatabase(
      path,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  // ============================================
  // DATABASE SCHEMA
  // ============================================

  Future<void> _onCreate(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        role TEXT NOT NULL,
        phone TEXT,
        avatar_url TEXT,
        is_active INTEGER DEFAULT 1,
        last_login TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Customers table
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        site_location TEXT,
        site_notes TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Products table
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        category TEXT NOT NULL,
        subcategory TEXT,
        sku TEXT UNIQUE,
        barcode TEXT,
        unit_price REAL NOT NULL,
        cost_price REAL DEFAULT 0,
        quantity INTEGER NOT NULL DEFAULT 0,
        min_stock INTEGER DEFAULT 5,
        max_stock INTEGER DEFAULT 100,
        unit TEXT,
        weight REAL,
        width REAL,
        height REAL,
        length REAL,
        brand TEXT,
        supplier TEXT,
        location TEXT,
        is_active INTEGER DEFAULT 1,
        is_taxable INTEGER DEFAULT 1,
        tax_rate REAL DEFAULT 16,
        image_url TEXT,
        notes TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Quotes table
    await db.execute('''
      CREATE TABLE quotes (
        id TEXT PRIMARY KEY,
        quote_number TEXT NOT NULL UNIQUE,
        customer_id TEXT NOT NULL,
        user_id TEXT,
        status TEXT NOT NULL DEFAULT 'draft',
        subtotal REAL DEFAULT 0,
        tax REAL DEFAULT 0,
        total REAL DEFAULT 0,
        discount REAL DEFAULT 0,
        grand_total REAL DEFAULT 0,
        validity_days INTEGER DEFAULT 14,
        scope TEXT,
        notes TEXT,
        site_measurements TEXT,
        expiry_date TEXT,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
      )
    ''');

    // Quote Items table
    await db.execute('''
      CREATE TABLE quote_items (
        id TEXT PRIMARY KEY,
        quote_id TEXT NOT NULL,
        product_id TEXT,
        item_type TEXT NOT NULL DEFAULT 'stock',
        description TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        unit_price REAL NOT NULL DEFAULT 0,
        discount REAL DEFAULT 0,
        tax REAL DEFAULT 0,
        total REAL DEFAULT 0,
        notes TEXT,
        unit TEXT,
        section TEXT,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (quote_id) REFERENCES quotes(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL
      )
    ''');

    // Invoices table
    await db.execute('''
      CREATE TABLE invoices (
        id TEXT PRIMARY KEY,
        invoice_number TEXT NOT NULL UNIQUE,
        quote_id TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        subtotal REAL DEFAULT 0,
        tax REAL DEFAULT 0,
        discount REAL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        amount_paid REAL DEFAULT 0,
        balance_due REAL DEFAULT 0,
        payment_status TEXT NOT NULL DEFAULT 'unpaid',
        payment_date TEXT,
        due_date TEXT,
        issued_date TEXT,
        scope TEXT,
        notes TEXT,
        terms TEXT,
        currency TEXT DEFAULT 'KES',
        is_void INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (quote_id) REFERENCES quotes(id) ON DELETE CASCADE,
        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
      )
    ''');

    // Sites table
    await db.execute('''
      CREATE TABLE sites (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        address TEXT,
        location TEXT,
        notes TEXT,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
      )
    ''');

    // Photos table
    await db.execute('''
      CREATE TABLE photos (
        id TEXT PRIMARY KEY,
        quote_id TEXT,
        site_id TEXT,
        url TEXT NOT NULL,
        description TEXT,
        file_name TEXT,
        file_size INTEGER,
        mime_type TEXT,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (quote_id) REFERENCES quotes(id) ON DELETE CASCADE,
        FOREIGN KEY (site_id) REFERENCES sites(id) ON DELETE CASCADE
      )
    ''');

    // Sync Queue table
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        operation TEXT NOT NULL,
        record_id TEXT NOT NULL,
        data TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        max_retries INTEGER DEFAULT 3,
        created_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        synced_at TEXT,
        error TEXT
      )
    ''');

    // System Logs table
    await db.execute('''
      CREATE TABLE system_logs (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        user_name TEXT,
        user_role TEXT,
        action TEXT NOT NULL,
        description TEXT NOT NULL,
        details TEXT,
        timestamp TEXT NOT NULL,
        status TEXT DEFAULT 'info'
      )
    ''');

    // Approval Requests table
    await db.execute('''
      CREATE TABLE approval_requests (
        id TEXT PRIMARY KEY,
        requested_by_id TEXT NOT NULL,
        requested_by_name TEXT NOT NULL,
        user_role TEXT NOT NULL,
        action_type TEXT NOT NULL,
        target_id TEXT,
        target_summary TEXT NOT NULL,
        details TEXT,
        status TEXT DEFAULT 'pending',
        created_at TEXT NOT NULL,
        resolved_at TEXT,
        resolved_by_id TEXT,
        resolved_by_name TEXT,
        rejection_reason TEXT
      )
    ''');

    // Create indexes
    await db.execute(
      'CREATE INDEX idx_quotes_customer_id ON quotes(customer_id)',
    );
    await db.execute('CREATE INDEX idx_quotes_user_id ON quotes(user_id)');
    await db.execute('CREATE INDEX idx_quotes_status ON quotes(status)');
    await db.execute(
      'CREATE INDEX idx_quote_items_quote_id ON quote_items(quote_id)',
    );
    await db.execute(
      'CREATE INDEX idx_invoices_customer_id ON invoices(customer_id)',
    );
    await db.execute(
      'CREATE INDEX idx_invoices_quote_id ON invoices(quote_id)',
    );
    await db.execute(
      'CREATE INDEX idx_invoices_payment_status ON invoices(payment_status)',
    );
    await db.execute(
      'CREATE INDEX idx_sync_queue_synced ON sync_queue(synced)',
    );
    await db.execute(
      'CREATE INDEX idx_products_category ON products(category)',
    );
    await db.execute('CREATE INDEX idx_products_sku ON products(sku)');
    await db.execute('CREATE INDEX idx_customers_name ON customers(name)');
    await db.execute('CREATE INDEX idx_photos_quote_id ON photos(quote_id)');
    await db.execute('CREATE INDEX idx_photos_site_id ON photos(site_id)');

    _log('✅ Database created successfully with all tables');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    _log('🔄 Upgrading database from version $oldVersion to $newVersion');

    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sites (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          customer_id TEXT NOT NULL,
          address TEXT,
          location TEXT,
          notes TEXT,
          created_at TEXT,
          updated_at TEXT,
          FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS photos (
          id TEXT PRIMARY KEY,
          quote_id TEXT,
          site_id TEXT,
          url TEXT NOT NULL,
          description TEXT,
          file_name TEXT,
          file_size INTEGER,
          mime_type TEXT,
          created_at TEXT,
          updated_at TEXT,
          FOREIGN KEY (quote_id) REFERENCES quotes(id) ON DELETE CASCADE,
          FOREIGN KEY (site_id) REFERENCES sites(id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE quotes DROP COLUMN items');
        _log('✅ Removed items column from quotes table');
      } catch (e) {
        _log('⚠️ items column not found in quotes table');
      }
    }

    if (oldVersion < 4) {
      try {
        // Add any new columns or indexes here
        _log('✅ Database upgraded to version 4');
      } catch (e) {
        _log('⚠️ Error during upgrade: $e');
      }
    }

    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE quotes ADD COLUMN scope TEXT');
        await db.execute('ALTER TABLE invoices ADD COLUMN scope TEXT');
        _log('✅ Added scope column to quotes and invoices tables');
      } catch (e) {
        _log('⚠️ Error during upgrade to version 5: $e');
      }
    }

    if (oldVersion < 6) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS system_logs (
            id TEXT PRIMARY KEY,
            user_id TEXT,
            user_name TEXT,
            user_role TEXT,
            action TEXT NOT NULL,
            description TEXT NOT NULL,
            details TEXT,
            timestamp TEXT NOT NULL,
            status TEXT DEFAULT 'info'
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS approval_requests (
            id TEXT PRIMARY KEY,
            requested_by_id TEXT NOT NULL,
            requested_by_name TEXT NOT NULL,
            user_role TEXT NOT NULL,
            action_type TEXT NOT NULL,
            target_id TEXT,
            target_summary TEXT NOT NULL,
            details TEXT,
            status TEXT DEFAULT 'pending',
            created_at TEXT NOT NULL,
            resolved_at TEXT,
            resolved_by_id TEXT,
            resolved_by_name TEXT,
            rejection_reason TEXT
          )
        ''');
        _log('✅ Database upgraded to version 6 (system_logs & approval_requests)');
      } catch (e) {
        _log('⚠️ Error during upgrade to version 6: $e');
      }
    }
  }

  // ============================================
  // GENERIC CRUD OPERATIONS
  // ============================================

  int _boolToInt(bool value) => value ? 1 : 0;

  Map<String, dynamic> _sanitizeData(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};
    data.forEach((key, value) {
      if (value is bool) {
        sanitized[key] = _boolToInt(value);
      } else {
        sanitized[key] = value;
      }
    });
    return sanitized;
  }

  Future<int> insert(
    String table,
    Map<String, dynamic> data, {
    Database? db,
  }) async {
    final database = db ?? await this.database;
    final sanitized = _sanitizeData(data);
    return await database.insert(table, sanitized);
  }

  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    required String where,
    List<Object?>? whereArgs,
    Database? db,
  }) async {
    final database = db ?? await this.database;
    final sanitized = _sanitizeData(data);
    return await database.update(
      table,
      sanitized,
      where: where,
      whereArgs: whereArgs,
    );
  }

  Future<int> delete(
    String table, {
    required String where,
    List<Object?>? whereArgs,
    Database? db,
  }) async {
    final database = db ?? await this.database;
    return await database.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
    List<String>? columns,
    Database? db,
  }) async {
    final database = db ?? await this.database;
    return await database.query(
      table,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? args,
    Database? db,
  ]) async {
    final database = db ?? await this.database;
    return await database.rawQuery(sql, args);
  }

  Future<int> rawInsert(String sql, [List<Object?>? args, Database? db]) async {
    final database = db ?? await this.database;
    return await database.rawInsert(sql, args);
  }

  Future<int> rawUpdate(String sql, [List<Object?>? args, Database? db]) async {
    final database = db ?? await this.database;
    return await database.rawUpdate(sql, args);
  }

  Future<int> rawDelete(String sql, [List<Object?>? args, Database? db]) async {
    final database = db ?? await this.database;
    return await database.rawDelete(sql, args);
  }

  // ============================================
  // TRANSACTION
  // ============================================

  Future<void> batch(List<Function(Batch batch)> operations) async {
    final db = await database;
    final batch = db.batch();
    for (var operation in operations) {
      operation(batch);
    }
    await batch.commit(noResult: true);
  }

  Future<T> transaction<T>(Future<T> Function() action) async {
    final db = await database;
    return await db.transaction((txn) async {
      return await action();
    });
  }

  // ============================================
  // FOREIGN KEY HELPERS (NEW)
  // ============================================

  /// Check if foreign keys are currently enabled
  Future<bool> areForeignKeysEnabled() async {
    final db = await database;
    final result = await db.rawQuery('PRAGMA foreign_keys');
    if (result.isNotEmpty) {
      final value = result.first['foreign_keys'];
      if (value is int) return value == 1;
      if (value is String) return value == '1' || value.toLowerCase() == 'on';
    }
    return true;
  }

  /// Execute a function with foreign keys temporarily disabled
  Future<T> withForeignKeysDisabled<T>(Future<T> Function() action) async {
    final db = await database;

    // Check current state
    final wasEnabled = await areForeignKeysEnabled();

    try {
      if (wasEnabled) {
        await db.execute('PRAGMA foreign_keys = OFF');
        _log('🔓 Foreign keys temporarily disabled');
      }

      final result = await action();
      return result;
    } finally {
      if (wasEnabled) {
        await db.execute('PRAGMA foreign_keys = ON');
        _log('🔒 Foreign keys re-enabled');
      }
    }
  }

  // ============================================
  // USER OPERATIONS
  // ============================================

  Future<void> saveUser(Map<String, dynamic> user) async {
    await insert('users', user);
  }

  Future<Map<String, dynamic>?> getUser(String id) async {
    final result = await query('users', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    return await query('users', orderBy: 'name ASC');
  }

  Future<void> deleteUser(String id) async {
    await delete('users', where: 'id = ?', whereArgs: [id]);
  }

  // ============================================
  // CUSTOMER OPERATIONS
  // ============================================

  Future<void> saveCustomer(Map<String, dynamic> customer) async {
    await insert('customers', customer);
  }

  Future<void> saveCustomers(List<Map<String, dynamic>> customers) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var customer in customers) {
        await txn.insert('customers', _sanitizeData(customer));
      }
    });
  }

  Future<Map<String, dynamic>?> getCustomer(String id) async {
    final result = await query('customers', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    return await query('customers', orderBy: 'name ASC');
  }

  Future<List<Map<String, dynamic>>> searchCustomers(String searchQuery) async {
    if (searchQuery.isEmpty) return getAllCustomers();
    final searchTerm = '%$searchQuery%';
    return await query(
      'customers',
      where: 'name LIKE ? OR phone LIKE ? OR email LIKE ? OR address LIKE ?',
      whereArgs: [searchTerm, searchTerm, searchTerm, searchTerm],
      orderBy: 'name ASC',
    );
  }

  Future<void> deleteCustomer(String id) async {
    await delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getCustomerCount() async {
    final result = await rawQuery('SELECT COUNT(*) as count FROM customers');
    return _getFirstIntValue(result) ?? 0;
  }

  // ============================================
  // PRODUCT OPERATIONS
  // ============================================

  Future<void> saveProduct(Map<String, dynamic> product) async {
    await insert('products', product);
  }

  Future<void> saveProducts(List<Map<String, dynamic>> products) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var product in products) {
        await txn.insert('products', _sanitizeData(product));
      }
    });
  }

  Future<Map<String, dynamic>?> getProduct(String id) async {
    final result = await query('products', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllProducts() async {
    return await query('products', orderBy: 'name ASC');
  }

  Future<List<Map<String, dynamic>>> searchProducts(String searchQuery) async {
    if (searchQuery.isEmpty) return getAllProducts();
    final searchTerm = '%$searchQuery%';
    return await query(
      'products',
      where:
          'name LIKE ? OR category LIKE ? OR description LIKE ? OR sku LIKE ? OR brand LIKE ? OR supplier LIKE ?',
      whereArgs: [
        searchTerm,
        searchTerm,
        searchTerm,
        searchTerm,
        searchTerm,
        searchTerm,
      ],
      orderBy: 'name ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getLowStockProducts() async {
    return await query(
      'products',
      where: 'quantity <= min_stock',
      orderBy: 'quantity ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getOutOfStockProducts() async {
    return await query('products', where: 'quantity = 0', orderBy: 'name ASC');
  }

  Future<void> deleteProduct(String id) async {
    await delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getProductCount() async {
    final result = await rawQuery('SELECT COUNT(*) as count FROM products');
    return _getFirstIntValue(result) ?? 0;
  }

  // ============================================
  // QUOTE OPERATIONS
  // ============================================

  Future<void> saveQuote(Map<String, dynamic> quote) async {
    final quoteData = Map<String, dynamic>.from(quote);
    quoteData.remove('items');
    await insert('quotes', quoteData);
  }

  Future<void> saveQuotes(List<Map<String, dynamic>> quotes) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var quote in quotes) {
        final quoteData = Map<String, dynamic>.from(quote);
        quoteData.remove('items');
        await txn.insert('quotes', _sanitizeData(quoteData));
      }
    });
  }

  Future<Map<String, dynamic>?> getQuote(String id) async {
    final result = await query('quotes', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllQuotes() async {
    return await query('quotes', orderBy: 'created_at DESC');
  }

  Future<List<Map<String, dynamic>>> getQuotesByStatus(String status) async {
    return await query(
      'quotes',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getQuotesByCustomer(
    String customerId,
  ) async {
    return await query(
      'quotes',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getQuotesByUser(String userId) async {
    return await query(
      'quotes',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> searchQuotes(String searchQuery) async {
    if (searchQuery.isEmpty) return getAllQuotes();
    final searchTerm = '%$searchQuery%';
    return await query(
      'quotes',
      where: 'quote_number LIKE ? OR customer_name LIKE ?',
      whereArgs: [searchTerm, searchTerm],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> deleteQuote(String id) async {
    await delete('quotes', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getQuoteCount() async {
    final result = await rawQuery('SELECT COUNT(*) as count FROM quotes');
    return _getFirstIntValue(result) ?? 0;
  }

  // ============================================
  // QUOTE ITEM OPERATIONS
  // ============================================

  Future<void> saveQuoteItem(Map<String, dynamic> item) async {
    await insert('quote_items', item);
  }

  Future<void> saveQuoteItems(List<Map<String, dynamic>> items) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var item in items) {
        await txn.insert('quote_items', _sanitizeData(item));
      }
    });
  }

  Future<List<Map<String, dynamic>>> getQuoteItems(String quoteId) async {
    return await query(
      'quote_items',
      where: 'quote_id = ?',
      whereArgs: [quoteId],
    );
  }

  Future<void> deleteQuoteItem(String id) async {
    await delete('quote_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteQuoteItems(String quoteId) async {
    await delete('quote_items', where: 'quote_id = ?', whereArgs: [quoteId]);
  }

  // ============================================
  // INVOICE OPERATIONS
  // ============================================

  Future<void> saveInvoice(Map<String, dynamic> invoice) async {
    await insert('invoices', invoice);
  }

  Future<void> saveInvoices(List<Map<String, dynamic>> invoices) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var invoice in invoices) {
        await txn.insert('invoices', _sanitizeData(invoice));
      }
    });
  }

  Future<Map<String, dynamic>?> getInvoice(String id) async {
    final result = await query('invoices', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllInvoices() async {
    return await query('invoices', orderBy: 'created_at DESC');
  }

  Future<List<Map<String, dynamic>>> getInvoicesByStatus(String status) async {
    return await query(
      'invoices',
      where: 'payment_status = ?',
      whereArgs: [status],
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getInvoicesByCustomer(
    String customerId,
  ) async {
    return await query(
      'invoices',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getOverdueInvoices() async {
    final now = DateTime.now().toIso8601String();
    return await query(
      'invoices',
      where: 'due_date < ? AND payment_status != ?',
      whereArgs: [now, 'paid'],
      orderBy: 'due_date ASC',
    );
  }

  Future<void> deleteInvoice(String id) async {
    await delete('invoices', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getInvoiceCount() async {
    final result = await rawQuery('SELECT COUNT(*) as count FROM invoices');
    return _getFirstIntValue(result) ?? 0;
  }

  // ============================================
  // SITE OPERATIONS
  // ============================================

  Future<void> saveSite(Map<String, dynamic> site) async {
    await insert('sites', site);
  }

  Future<Map<String, dynamic>?> getSite(String id) async {
    final result = await query('sites', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getSitesByCustomer(
    String customerId,
  ) async {
    return await query(
      'sites',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'name ASC',
    );
  }

  Future<void> deleteSite(String id) async {
    await delete('sites', where: 'id = ?', whereArgs: [id]);
  }

  // ============================================
  // PHOTO OPERATIONS
  // ============================================

  Future<void> savePhoto(Map<String, dynamic> photo) async {
    await insert('photos', photo);
  }

  Future<List<Map<String, dynamic>>> getPhotosByQuote(String quoteId) async {
    return await query(
      'photos',
      where: 'quote_id = ?',
      whereArgs: [quoteId],
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getPhotosBySite(String siteId) async {
    return await query(
      'photos',
      where: 'site_id = ?',
      whereArgs: [siteId],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> deletePhoto(String id) async {
    await delete('photos', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deletePhotosByQuote(String quoteId) async {
    await delete('photos', where: 'quote_id = ?', whereArgs: [quoteId]);
  }

  Future<void> deletePhotosBySite(String siteId) async {
    await delete('photos', where: 'site_id = ?', whereArgs: [siteId]);
  }

  // ============================================
  // SYNC QUEUE OPERATIONS
  // ============================================

  Future<int> addToSyncQueue({
    required String tableName,
    required String operation,
    required String recordId,
    required Map<String, dynamic> data,
    int maxRetries = 3,
  }) async {
    final db = await database;
    return await db.insert('sync_queue', {
      'table_name': tableName,
      'operation': operation,
      'record_id': recordId,
      'data': jsonEncode(data),
      'retry_count': 0,
      'max_retries': maxRetries,
      'created_at': DateTime.now().toIso8601String(),
      'synced': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    final db = await database;
    return await db.query(
      'sync_queue',
      where: 'synced = 0 AND retry_count < max_retries',
      orderBy: 'created_at ASC',
    );
  }

  Future<void> markSyncItemSynced(int id) async {
    final db = await database;
    await db.update(
      'sync_queue',
      {'synced': 1, 'synced_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateSyncItemRetry(int id, {String? error}) async {
    final db = await database;

    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT retry_count FROM sync_queue WHERE id = ?',
      [id],
    );

    int newRetryCount = 1;
    if (result.isNotEmpty) {
      final currentRetry = result.first['retry_count'];
      if (currentRetry != null && currentRetry is int) {
        newRetryCount = currentRetry + 1;
      }
    }

    final Map<String, dynamic> values = {'retry_count': newRetryCount};
    if (error != null) {
      values['error'] = error;
    }

    await db.update('sync_queue', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearSyncedItems() async {
    final db = await database;
    await db.delete('sync_queue', where: 'synced = 1');
  }

  Future<int> getPendingSyncCount() async {
    final result = await rawQuery(
      'SELECT COUNT(*) as count FROM sync_queue WHERE synced = 0 AND retry_count < max_retries',
    );
    return _getFirstIntValue(result) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getFailedSyncItems() async {
    final db = await database;
    return await db.query(
      'sync_queue',
      where: 'synced = 0 AND retry_count >= max_retries',
      orderBy: 'created_at ASC',
    );
  }

  Future<void> resetSyncItem(int id) async {
    final db = await database;
    await db.update(
      'sync_queue',
      {'retry_count': 0, 'error': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================
  // DATABASE STATISTICS
  // ============================================

  Future<Map<String, int>> getStats() async {
    final tables = [
      'users',
      'customers',
      'products',
      'quotes',
      'quote_items',
      'invoices',
      'sites',
      'photos',
      'sync_queue',
    ];

    final stats = <String, int>{};
    for (var table in tables) {
      final result = await rawQuery('SELECT COUNT(*) as count FROM $table');
      stats[table] = _getFirstIntValue(result) ?? 0;
    }
    return stats;
  }

  Future<Map<String, int>> getDatabaseSize() async {
    final db = await database;
    final path = db.path;
    final file = File(path);
    if (await file.exists()) {
      final size = await file.length();
      return {
        'size_bytes': size,
        'size_kb': size ~/ 1024,
        'size_mb': size ~/ (1024 * 1024),
      };
    }
    return {'size_bytes': 0, 'size_kb': 0, 'size_mb': 0};
  }

  // ============================================
  // DATABASE MAINTENANCE
  // ============================================

  Future<void> vacuum() async {
    final db = await database;
    await db.execute('VACUUM');
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.execute('DELETE FROM sync_queue');
      await txn.execute('DELETE FROM photos');
      await txn.execute('DELETE FROM quote_items');
      await txn.execute('DELETE FROM invoices');
      await txn.execute('DELETE FROM quotes');
      await txn.execute('DELETE FROM sites');
      await txn.execute('DELETE FROM products');
      await txn.execute('DELETE FROM customers');
      await txn.execute('DELETE FROM users');
      await txn.execute('DELETE FROM sqlite_sequence');
    });
  }

  Future<void> resetForProduction() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.execute('DELETE FROM sync_queue');
      await txn.execute('DELETE FROM photos');
      await txn.execute('DELETE FROM quote_items');
      await txn.execute('DELETE FROM invoices');
      await txn.execute('DELETE FROM quotes');
      await txn.execute('DELETE FROM sites');
      await txn.execute('DELETE FROM products');
      await txn.execute('DELETE FROM customers');
      // Keep only admin users
      await txn.execute("DELETE FROM users WHERE role != 'admin'");
      await txn.execute('DELETE FROM sqlite_sequence');
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('start_quote_number', '010A');
      await prefs.setString('start_invoice_number', 'QPN00001');
    } catch (e) {
      _log('⚠️ Error resetting preference defaults: $e');
    }

    _log('✅ Database reset for production completed (admin users preserved).');
  }

  Future<void> clearTable(String table) async {
    final db = await database;
    await db.delete(table);
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // ============================================
  // BACKUP & RESTORE
  // ============================================

  Future<File> backupDatabase() async {
    final db = await database;
    final path = db.path;
    final file = File(path);

    final backupDir = await getApplicationDocumentsDirectory();
    final backupPath = join(
      backupDir.path,
      'quickfix_backup_${DateTime.now().millisecondsSinceEpoch}.db',
    );

    await file.copy(backupPath);
    return File(backupPath);
  }

  Future<void> restoreDatabase(String backupPath) async {
    final db = await database;
    await db.close();

    final currentPath = db.path;
    final backupFile = File(backupPath);

    if (await backupFile.exists()) {
      await backupFile.copy(currentPath);
      _database = null;
      await database;
    }
  }

  // ============================================
  // QUERY HELPERS
  // ============================================

  Future<bool> tableExists(String tableName) async {
    final result = await rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    return result.isNotEmpty;
  }

  Future<List<String>> getAllTables() async {
    final result = await rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
    );
    return result.map((row) => row['name'] as String).toList();
  }

  // ============================================
  // FIX FOREIGN KEYS
  // ============================================

  /// Check if a customer exists and return the count
  Future<int> customerExists(String customerId) async {
    if (customerId.isEmpty) return 0;
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM customers WHERE id = ?',
      [customerId],
    );
    if (result.isEmpty) return 0;
    final count = result.first['count'];
    if (count is int) return count;
    if (count is String) return int.tryParse(count) ?? 0;
    return 0;
  }

  /// Check if a user exists and return the count
  Future<int> userExists(String userId) async {
    if (userId.isEmpty) return 0;
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM users WHERE id = ?',
      [userId],
    );
    if (result.isEmpty) return 0;
    final count = result.first['count'];
    if (count is int) return count;
    if (count is String) return int.tryParse(count) ?? 0;
    return 0;
  }

  /// Ensure a customer exists, create placeholder if not using INSERT OR REPLACE
  Future<void> ensureCustomerExists(String customerId, {String? name}) async {
    if (customerId.isEmpty) return;

    final exists = await customerExists(customerId);
    if (exists > 0) return;

    _log('⚠️ Customer $customerId not found, creating placeholder...');

    // Use INSERT OR REPLACE to avoid UNIQUE constraint errors
    final db = await database;
    await db.rawInsert(
      '''
      INSERT OR REPLACE INTO customers (id, name, phone, email, address, site_location, site_notes, created_at, updated_at)
      VALUES (?, ?, NULL, NULL, NULL, NULL, NULL, ?, ?)
    ''',
      [
        customerId,
        name ?? 'Unknown Customer (${customerId.substring(0, 8)})',
        DateTime.now().toIso8601String(),
        DateTime.now().toIso8601String(),
      ],
    );
    _log('✅ Created/updated placeholder customer: ${name ?? customerId}');
  }

  /// Ensure a user exists, create placeholder if not using INSERT OR REPLACE
  Future<void> ensureUserExists(String userId, {String? name}) async {
    if (userId.isEmpty) return;

    final exists = await userExists(userId);
    if (exists > 0) return;

    _log('⚠️ User $userId not found, creating placeholder...');

    final db = await database;
    await db.rawInsert(
      '''
      INSERT OR REPLACE INTO users (id, name, email, role, phone, avatar_url, is_active, last_login, created_at, updated_at)
      VALUES (?, ?, ?, ?, NULL, NULL, 1, NULL, ?, ?)
    ''',
      [
        userId,
        name ?? 'Unknown User (${userId.substring(0, 8)})',
        '$userId@local',
        'staff',
        DateTime.now().toIso8601String(),
        DateTime.now().toIso8601String(),
      ],
    );
    _log('✅ Created/updated placeholder user: ${name ?? userId}');
  }

  /// Fix all quotes with missing customer references
  Future<int> fixMissingCustomerReferences() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT q.id, q.customer_id, q.quote_number
      FROM quotes q
      LEFT JOIN customers c ON q.customer_id = c.id
      WHERE c.id IS NULL
    ''');

    if (result.isEmpty) return 0;

    int fixed = 0;
    for (var row in result) {
      final customerId = row['customer_id'] as String;
      final quoteNumber = row['quote_number'] as String;
      _log('⚠️ Quote $quoteNumber has missing customer: $customerId');

      await ensureCustomerExists(customerId);
      fixed++;
    }

    _log('✅ Fixed $fixed missing customer references');
    return fixed;
  }

  /// Fix all quotes with missing user references
  Future<int> fixMissingUserReferences() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT q.id, q.user_id, q.quote_number
      FROM quotes q
      LEFT JOIN users u ON q.user_id = u.id
      WHERE q.user_id IS NOT NULL AND q.user_id != '' AND u.id IS NULL
    ''');

    if (result.isEmpty) return 0;

    int fixed = 0;
    for (var row in result) {
      final userId = row['user_id'] as String;
      final quoteNumber = row['quote_number'] as String;
      _log('⚠️ Quote $quoteNumber has missing user: $userId');

      await ensureUserExists(userId);
      fixed++;
    }

    _log('✅ Fixed $fixed missing user references');
    return fixed;
  }

  /// Fix all invoices with missing customer references
  Future<int> fixMissingInvoiceCustomerReferences() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT i.id, i.customer_id, i.invoice_number
      FROM invoices i
      LEFT JOIN customers c ON i.customer_id = c.id
      WHERE c.id IS NULL
    ''');

    if (result.isEmpty) return 0;

    int fixed = 0;
    for (var row in result) {
      final customerId = row['customer_id'] as String;
      final invoiceNumber = row['invoice_number'] as String;
      _log('⚠️ Invoice $invoiceNumber has missing customer: $customerId');

      await ensureCustomerExists(customerId);
      fixed++;
    }

    _log('✅ Fixed $fixed missing invoice customer references');
    return fixed;
  }

  /// Verify database integrity
  Future<Map<String, dynamic>> verifyIntegrity() async {
    final db = await database;
    final result = <String, dynamic>{};

    // Check quotes with missing customers
    final missingCustomers = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM quotes q
      LEFT JOIN customers c ON q.customer_id = c.id
      WHERE c.id IS NULL
    ''');
    result['quotes_without_customers'] =
        _getFirstIntValue(missingCustomers) ?? 0;

    // Check invoices with missing customers
    final missingInvoiceCustomers = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM invoices i
      LEFT JOIN customers c ON i.customer_id = c.id
      WHERE c.id IS NULL
    ''');
    result['invoices_without_customers'] =
        _getFirstIntValue(missingInvoiceCustomers) ?? 0;

    // Check quote items with missing quotes
    final missingQuotes = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM quote_items qi
      LEFT JOIN quotes q ON qi.quote_id = q.id
      WHERE q.id IS NULL
    ''');
    result['quote_items_without_quotes'] =
        _getFirstIntValue(missingQuotes) ?? 0;

    // Check total counts
    final totalCustomers = await db.rawQuery(
      'SELECT COUNT(*) as count FROM customers',
    );
    result['total_customers'] = _getFirstIntValue(totalCustomers) ?? 0;

    final totalQuotes = await db.rawQuery(
      'SELECT COUNT(*) as count FROM quotes',
    );
    result['total_quotes'] = _getFirstIntValue(totalQuotes) ?? 0;

    final totalInvoices = await db.rawQuery(
      'SELECT COUNT(*) as count FROM invoices',
    );
    result['total_invoices'] = _getFirstIntValue(totalInvoices) ?? 0;

    return result;
  }

  /// Repair database by fixing all foreign key issues
  Future<Map<String, dynamic>> repairForeignKeys() async {
    _log('🔧 Repairing foreign keys...');

    final result = <String, dynamic>{};

    // Use the helper to disable foreign keys during repair
    await withForeignKeysDisabled(() async {
      // Fix quotes with missing customers
      final fixedQuotes = await fixMissingCustomerReferences();
      result['fixed_quotes'] = fixedQuotes;

      // Fix quotes with missing users
      final fixedUsers = await fixMissingUserReferences();
      result['fixed_users'] = fixedUsers;

      // Fix invoices with missing customers
      final fixedInvoices = await fixMissingInvoiceCustomerReferences();
      result['fixed_invoices'] = fixedInvoices;
    });

    // Verify after repair (with foreign keys enabled)
    final verification = await verifyIntegrity();
    result['verification'] = verification;

    _log('✅ Foreign key repair completed');
    return result;
  }

  // ============================================
  // SYNC STATUS (NEW)
  // ============================================

  /// Get sync status including pending and failed items
  Future<Map<String, dynamic>> getSyncStatus() async {
    final pendingCount = await getPendingSyncCount();
    final failedItems = await getFailedSyncItems();

    return {
      'pending_count': pendingCount,
      'failed_count': failedItems.length,
      'failed_items': failedItems,
      'is_synced': pendingCount == 0 && failedItems.isEmpty,
    };
  }

  /// Force sync a specific item by resetting it
  Future<void> forceSyncItem(int id) async {
    await resetSyncItem(id);
    // The item will be picked up by the next sync cycle
  }

  // ============================================
  // SYSTEM LOG OPERATIONS
  // ============================================

  Future<void> saveSystemLog(Map<String, dynamic> log) async {
    await insert('system_logs', log);
  }

  Future<List<Map<String, dynamic>>> getSystemLogs({
    String? searchQuery,
    String? status,
    int limit = 100,
  }) async {
    final whereClauses = <String>[];
    final whereArgs = <Object?>[];

    if (status != null && status.isNotEmpty) {
      whereClauses.add('status = ?');
      whereArgs.add(status);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final term = '%$searchQuery%';
      whereClauses.add('(action LIKE ? OR description LIKE ? OR user_name LIKE ?)');
      whereArgs.addAll([term, term, term]);
    }

    return await query(
      'system_logs',
      where: whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }

  Future<void> clearSystemLogs() async {
    await delete('system_logs', where: '1 = 1');
  }

  // ============================================
  // APPROVAL REQUEST OPERATIONS
  // ============================================

  Future<void> saveApprovalRequest(Map<String, dynamic> request) async {
    await insert('approval_requests', request);
  }

  Future<void> updateApprovalRequest(String id, Map<String, dynamic> data) async {
    await update(
      'approval_requests',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getApprovalRequests({String? status}) async {
    if (status != null && status.isNotEmpty) {
      return await query(
        'approval_requests',
        where: 'status = ?',
        whereArgs: [status],
        orderBy: 'created_at DESC',
      );
    }
    return await query('approval_requests', orderBy: 'created_at DESC');
  }

  Future<Map<String, dynamic>?> getApprovalRequest(String id) async {
    final result = await query('approval_requests', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }
}
