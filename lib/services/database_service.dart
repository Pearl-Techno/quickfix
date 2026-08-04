// lib/services/database_service.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quickfix/config/constants.dart';
import 'package:quickfix/models/customer.dart';
import 'package:quickfix/models/invoice.dart';
import 'package:quickfix/models/product.dart';
import 'package:quickfix/models/quote.dart';
import 'package:quickfix/models/quote_item.dart';
import 'package:quickfix/services/supabase_service.dart';
import 'package:quickfix/services/database_helper.dart';
import 'package:quickfix/services/log_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quickfix/utils/helpers.dart';

// Simple logging function that can be disabled in production
void _log(String message) {
  if (kDebugMode) {
    print('[DatabaseService] $message');
  }
}

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;

  DatabaseService._internal() {
    _initConnectivity();
    _startPeriodicSync();
  }

  void dispose() {
    _periodicSyncTimer?.cancel();
  }

  final SupabaseService _supabase = SupabaseService();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Connectivity status
  bool _isOnline = false;
  final Connectivity _connectivity = Connectivity();

  // ============================================
  // SYNC LOCK & NOTIFIERS
  // ============================================
  bool _isSyncing = false;
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> pendingSyncCountNotifier = ValueNotifier<int>(0);
  final StreamController<void> _syncCompleteController = StreamController<void>.broadcast();
  Stream<void> get onSyncCompleteStream => _syncCompleteController.stream;
  Timer? _periodicSyncTimer;

  // ============================================
  // INITIALIZATION & CONNECTIVITY
  // ============================================

  Future<void> _initConnectivity() async {
    try {
      await updatePendingCount();
      final result = await _connectivity.checkConnectivity();
      _isOnline = result.first != ConnectivityResult.none;
      _log('🌐 Initial connectivity: ${_isOnline ? "Online" : "Offline"}');

      _connectivity.onConnectivityChanged.listen((results) {
        final wasOnline = _isOnline;
        _isOnline = results.first != ConnectivityResult.none;

        if (!wasOnline && _isOnline) {
          _log('🔄 Connection restored - syncing data...');
          _syncPendingData();
        }

        _log('🌐 Connectivity changed: ${_isOnline ? "Online" : "Offline"}');
      });
    } catch (e) {
      _log('❌ Error initializing connectivity: $e');
      _isOnline = false;
    }
  }

  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        if (await isOnline && _supabase.client.auth.currentUser != null) {
          _log('⏰ Periodic background sync triggered');
          await fullSync();
        }
      } catch (e) {
        _log('❌ Periodic sync error: $e');
      }
    });
  }

  Future<void> updatePendingCount() async {
    try {
      final count = await getPendingSyncCount();
      pendingSyncCountNotifier.value = count;
    } catch (e) {
      _log('❌ Error updating pending count: $e');
    }
  }

  Future<bool> get isOnline async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result.first != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  // ============================================
  // SYNC PENDING DATA (Local -> Supabase)
  // ============================================

  Future<void> _syncPendingData() async {
    if (_isSyncing) {
      _log('⚠️ Sync already in progress, skipping background sync');
      return;
    }

    if (!await isOnline) {
      _log('📴 Cannot sync - offline');
      return;
    }

    _isSyncing = true;
    isSyncingNotifier.value = true;

    try {
      await _syncPendingDataInternal();
    } finally {
      _isSyncing = false;
      isSyncingNotifier.value = false;
      _syncCompleteController.add(null);
      await updatePendingCount();
    }
  }

  Future<void> _syncPendingDataInternal() async {
    _log('🔄 Syncing pending data to Supabase...');
    final pendingItems = await _dbHelper.getPendingSyncItems();

    if (pendingItems.isEmpty) {
      _log('✅ No pending items to sync');
      return;
    }

    _log('📊 Found ${pendingItems.length} pending items');

    for (var item in pendingItems) {
      final id = item['id'] as int;
      final tableName = item['table_name'] as String;
      final operation = item['operation'] as String;
      final recordId = item['record_id'] as String;
      final data = item['data'] as String;

      try {
        final decodedData = Map<String, dynamic>.from(jsonDecode(data));

        _log('🔄 Syncing $tableName $operation for $recordId...');

        switch (tableName) {
          case 'customers':
            await _syncCustomer(operation, recordId, decodedData);
            break;
          case 'products':
            await _syncProduct(operation, recordId, decodedData);
            break;
          case 'quotes':
            await _syncQuote(operation, recordId, decodedData);
            break;
          case 'quote_items':
            await _syncQuoteItem(operation, recordId, decodedData);
            break;
          case 'invoices':
            await _syncInvoice(operation, recordId, decodedData);
            break;
          default:
            _log('⚠️ Unknown table: $tableName');
            continue;
        }

        await _dbHelper.markSyncItemSynced(id);
        _log('✅ Synced: $tableName $operation $recordId');
      } catch (e) {
        _log('❌ Failed to sync item $id: $e');
        await _dbHelper.updateSyncItemRetry(id, error: e.toString());
      }
    }

    // Clean up old synced items
    await _dbHelper.clearSyncedItems();
  }

  // ============================================
  // SYNC TO SUPABASE HELPERS
  // ============================================

  bool _isValidUuid(String id) {
    final regExp = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return regExp.hasMatch(id);
  }

  Future<void> _executeWithDynamicSanitization(
    Future<void> Function(Map<String, dynamic> payload) action,
    Map<String, dynamic> payload,
  ) async {
    Map<String, dynamic> currentPayload = Map<String, dynamic>.from(payload);
    int retries = 0;
    while (retries < 15) {
      try {
        await action(currentPayload);
        return; // Success!
      } catch (e) {
        if (e is PostgrestException) {
          if (e.code == 'PGRST204') {
            final match = RegExp(r"Could not find the '([^']+)' column").firstMatch(e.message);
            if (match != null) {
              final columnName = match.group(1);
              if (columnName != null && currentPayload.containsKey(columnName)) {
                _log('⚠️ Column "$columnName" is missing on Supabase. Sanitizing and retrying...');
                currentPayload.remove(columnName);
                retries++;
                continue; // Retry with sanitized payload
              }
            }
          } else if (e.code == '22P02') {
            final match = RegExp(r'invalid input syntax for type uuid: "([^"]+)"').firstMatch(e.message);
            if (match != null) {
              final invalidValue = match.group(1);
              if (invalidValue != null) {
                String? keyToRemove;
                currentPayload.forEach((key, val) {
                  if (val?.toString() == invalidValue) {
                    keyToRemove = key;
                  }
                });
                if (keyToRemove != null) {
                  _log('⚠️ Field "$keyToRemove" has invalid UUID value "$invalidValue" on Supabase. Sanitizing and retrying...');
                  if (keyToRemove == 'id') {
                    _log('⚠️ Cannot sync record with invalid UUID primary key: $invalidValue');
                    return; // Skip sync entirely
                  }
                  currentPayload.remove(keyToRemove);
                  retries++;
                  continue;
                }
              }
            }
          }
        }
        rethrow; // Rethrow other errors
      }
    }
    _log('❌ Maximum dynamic sanitization retries exceeded');
  }

  Future<void> _syncCustomer(
    String operation,
    String id,
    Map<String, dynamic> data,
  ) async {
    if (!_isValidUuid(id)) {
      _log('⚠️ Skipping customer sync for non-UUID customer id: $id');
      return;
    }
    await _executeWithDynamicSanitization((payload) async {
      switch (operation) {
        case 'insert':
          await _supabase.client
              .from(SupabaseService.customersTable)
              .insert(payload);
          break;
        case 'update':
          await _supabase.client
              .from(SupabaseService.customersTable)
              .update(payload)
              .eq('id', id);
          break;
        case 'delete':
          await _supabase.client
              .from(SupabaseService.customersTable)
              .delete()
              .eq('id', id);
          break;
        default:
          _log('⚠️ Unknown operation: $operation');
      }
    }, data);
  }

  Future<void> _syncProduct(
    String operation,
    String id,
    Map<String, dynamic> data,
  ) async {
    if (!_isValidUuid(id)) {
      _log('⚠️ Skipping product sync for non-UUID product id: $id');
      return;
    }
    await _executeWithDynamicSanitization((payload) async {
      switch (operation) {
        case 'insert':
          await _supabase.client.from(SupabaseService.productsTable).insert(payload);
          break;
        case 'update':
          await _supabase.client
              .from(SupabaseService.productsTable)
              .update(payload)
              .eq('id', id);
          break;
        case 'delete':
          await _supabase.client
              .from(SupabaseService.productsTable)
              .delete()
              .eq('id', id);
          break;
        default:
          _log('⚠️ Unknown operation: $operation');
      }
    }, data);
  }

  Future<void> _syncQuote(
    String operation,
    String id,
    Map<String, dynamic> data,
  ) async {
    if (!_isValidUuid(id)) {
      _log('⚠️ Skipping quote sync for non-UUID quote id: $id');
      return;
    }
    await _executeWithDynamicSanitization((payload) async {
      switch (operation) {
        case 'insert':
          await _supabase.client.from(SupabaseService.quotesTable).insert(payload);
          break;
        case 'update':
          await _supabase.client
              .from(SupabaseService.quotesTable)
              .update(payload)
              .eq('id', id);
          break;
        case 'delete':
          await _supabase.client
              .from(SupabaseService.quotesTable)
              .delete()
              .eq('id', id);
          break;
        default:
          _log('⚠️ Unknown operation: $operation');
      }
    }, data);
  }

  Future<void> _syncQuoteItem(
    String operation,
    String id,
    Map<String, dynamic> data,
  ) async {
    if (!_isValidUuid(id)) {
      _log('⚠️ Skipping quote item sync for non-UUID quote item id: $id');
      return;
    }
    await _executeWithDynamicSanitization((payload) async {
      switch (operation) {
        case 'insert':
          await _supabase.client.from(SupabaseService.quoteItemsTable).insert(payload);
          break;
        case 'update':
          await _supabase.client
              .from(SupabaseService.quoteItemsTable)
              .update(payload)
              .eq('id', id);
          break;
        case 'delete':
          await _supabase.client
              .from(SupabaseService.quoteItemsTable)
              .delete()
              .eq('id', id);
          break;
        default:
          _log('⚠️ Unknown operation: $operation');
      }
    }, data);
  }

  Future<void> _syncInvoice(
    String operation,
    String id,
    Map<String, dynamic> data,
  ) async {
    if (!_isValidUuid(id)) {
      _log('⚠️ Skipping invoice sync for non-UUID invoice id: $id');
      return;
    }
    await _executeWithDynamicSanitization((payload) async {
      switch (operation) {
        case 'insert':
          await _supabase.client
              .from(SupabaseService.invoicesTable)
              .insert(payload);
          break;
        case 'update':
          await _supabase.client
              .from(SupabaseService.invoicesTable)
              .update(payload)
              .eq('id', id);
          break;
        case 'delete':
          await _supabase.client
              .from(SupabaseService.invoicesTable)
              .delete()
              .eq('id', id);
          break;
        default:
          _log('⚠️ Unknown operation: $operation');
      }
    }, data);
  }

  // ============================================
  // PULL LATEST FROM SUPABASE (Supabase -> Local)
  // ============================================

  Future<void> pullLatestFromSupabase() async {
    if (_isSyncing) {
      _log('⚠️ Sync already in progress, skipping pull...');
      return;
    }

    if (!await isOnline) {
      _log('📴 Cannot pull - offline');
      return;
    }

    _isSyncing = true;
    isSyncingNotifier.value = true;

    try {
      await _pullLatestFromSupabaseInternal();
    } finally {
      _isSyncing = false;
      isSyncingNotifier.value = false;
      _syncCompleteController.add(null);
    }
  }

  Future<void> _pullLatestFromSupabaseInternal() async {
    final db = await _dbHelper.database;
    await db.execute('PRAGMA foreign_keys = OFF');
    _log('🔓 Foreign keys disabled for pull');

    try {
      _log('🔄 Pulling latest data from Supabase...');

      // Pull Customers - always do this first
      _log('📥 Pulling customers...');
      final customers = await _fetchCustomersFromSupabase();
      for (var customer in customers) {
        await _saveCustomerWithCheck(customer);
      }
      _log('✅ Pulled ${customers.length} customers');

      // Pull Products
      _log('📥 Pulling products...');
      final products = await _fetchProductsFromSupabase();
      for (var product in products) {
        await _saveProductWithCheck(product);
      }
      _log('✅ Pulled ${products.length} products');

      // Pull Quotes - ensure customers exist first
      _log('📥 Pulling quotes...');
      final quotes = await _fetchQuotesFromSupabase();

      for (var quote in quotes) {
        await _verifyCustomerExists(
          quote.customerId,
          context: 'Quote ${quote.quoteNumber}',
        );
        await _saveQuoteWithCheck(quote);
        await _syncQuoteItemsForQuote(quote.id);
      }
      _log('✅ Pulled ${quotes.length} quotes');

      // Pull Invoices - ensure customers exist first
      _log('📥 Pulling invoices...');
      final invoices = await _fetchInvoicesFromSupabase();

      for (var invoice in invoices) {
        await _verifyCustomerExists(
          invoice.customerId,
          context: 'Invoice ${invoice.invoiceNumber}',
        );
        if (invoice.quoteId.isNotEmpty) {
          await _ensureQuoteExists(invoice.quoteId);
        }
        await _saveInvoiceWithCheck(invoice);
      }
      _log('✅ Pulled ${invoices.length} invoices');

      _log('✅ Pull completed successfully');
    } catch (e) {
      _log('❌ Error pulling from Supabase: $e');
    } finally {
      // Re-enable foreign keys
      await db.execute('PRAGMA foreign_keys = ON');
      _log('🔒 Foreign keys re-enabled');
    }
  }

  // ============================================
  // FULL SYNC (Bi-Directional)
  // ============================================

  Future<void> fullSync() async {
    // Prevent concurrent syncs
    if (_isSyncing) {
      _log('⚠️ Sync already in progress, skipping full sync...');
      return;
    }

    _isSyncing = true;
    isSyncingNotifier.value = true;
    _log('🔄 Starting full bi-directional sync...');

    if (!await isOnline) {
      _log('📴 Cannot sync - offline');
      _isSyncing = false;
      isSyncingNotifier.value = false;
      throw Exception('Cannot sync while offline');
    }

    final db = await _dbHelper.database;
    await db.execute('PRAGMA foreign_keys = OFF');

    try {
      // 1. Push pending local changes to Supabase
      _log('📤 Pushing local changes to Supabase...');
      await _syncPendingDataInternal();

      // 2. Pull latest from Supabase to local
      _log('📥 Pulling latest from Supabase...');
      await _pullLatestFromSupabaseInternal();

      // 3. Fix any data inconsistencies
      _log('🔧 Fixing data inconsistencies...');
      await _fixDuplicateSkus();
      await _repairData();
      await migrateOldNumberingFormats();

      // Push migrated records immediately
      await _syncPendingDataInternal();

      // 4. Verify and repair foreign keys
      await _dbHelper.repairForeignKeys();

      _log('✅ Full sync completed successfully');
      await LogService().logEvent(
        action: 'SYSTEM_SYNC',
        description: 'Completed full bi-directional data synchronization with cloud',
        status: 'info',
      );
    } catch (e) {
      _log('❌ Error during full sync: $e');
      rethrow;
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
      _isSyncing = false;
      isSyncingNotifier.value = false;
      _syncCompleteController.add(null);
      await updatePendingCount();
    }
  }

  // ============================================
  // SYNC WITH FOREIGN KEYS DISABLED
  // ============================================

  Future<void> syncWithForeignKeysDisabled() async {
    // Prevent concurrent syncs
    if (_isSyncing) {
      _log(
        '⚠️ Sync already in progress, skipping syncWithForeignKeysDisabled...',
      );
      return;
    }

    if (!await isOnline) {
      _log('📴 Offline - skipping syncWithForeignKeysDisabled');
      return;
    }

    _isSyncing = true;
    isSyncingNotifier.value = true;
    final db = await _dbHelper.database;
    await db.execute('PRAGMA foreign_keys = OFF');
    _log('🔓 Foreign keys disabled for sync');

    try {
      // 1. Sync Customers
      _log('🔄 Syncing customers...');
      final customers = await getCustomers();
      _log('✅ Synced ${customers.length} customers');

      // 2. Sync Products
      _log('🔄 Syncing products...');
      final products = await getProducts();
      _log('✅ Synced ${products.length} products');

      // 3. Ensure all customers exist before syncing quotes
      _log('🔍 Ensuring all customers exist...');
      await _ensureAllCustomersExist();

      // 4. Repair foreign keys
      await _dbHelper.repairForeignKeys();

      // 5. Sync Quotes
      _log('🔄 Syncing quotes...');
      final quotesResponse = await _supabase.client
          .from(SupabaseService.quotesTable)
          .select('*, customers!inner(name)')
          .order('created_at', ascending: false);

      final quotes = quotesResponse
          .map<Quote>((json) => Quote.fromJson(json))
          .toList();

      int quoteCount = 0;
      for (var quote in quotes) {
        try {
          await _verifyCustomerExists(
            quote.customerId,
            context: 'Quote ${quote.quoteNumber}',
          );
          await _saveQuoteWithCheck(quote);
          quoteCount++;
        } catch (e) {
          _log('❌ Error syncing quote ${quote.quoteNumber}: $e');
          // Try with minimal data
          try {
            await _verifyCustomerExists(
              quote.customerId,
              context: 'Quote ${quote.quoteNumber}',
            );
            final minimalJson = {
              'id': quote.id,
              'quote_number': quote.quoteNumber,
              'customer_id': quote.customerId,
              'user_id': quote.userId,
              'status': quote.status,
              'subtotal': quote.subtotal,
              'tax': quote.tax,
              'total': quote.total,
              'discount': quote.discount,
              'grand_total': quote.grandTotal,
              'validity_days': quote.validityDays,
              'created_at': quote.createdAt?.toIso8601String(),
              'updated_at': quote.updatedAt?.toIso8601String(),
            };
            final existing = await _dbHelper.getQuote(quote.id);
            if (existing != null) {
              await db.update(
                'quotes',
                minimalJson,
                where: 'id = ?',
                whereArgs: [quote.id],
              );
            } else {
              await db.insert('quotes', minimalJson);
            }
            quoteCount++;
            _log('✅ Synced quote with minimal data: ${quote.quoteNumber}');
          } catch (e2) {
            _log('❌ Failed to sync quote ${quote.quoteNumber}: $e2');
          }
        }
      }
      _log('✅ Synced $quoteCount quotes');

      // 6. Sync Invoices
      _log('🔄 Syncing invoices...');
      final invoicesResponse = await _supabase.client
          .from(SupabaseService.invoicesTable)
          .select('*, customers!inner(name), quotes!inner(quote_number)')
          .order('created_at', ascending: false);

      final invoices = invoicesResponse
          .map<Invoice>((json) => Invoice.fromJson(json))
          .toList();

      int invoiceCount = 0;
      for (var invoice in invoices) {
        try {
          await _verifyCustomerExists(
            invoice.customerId,
            context: 'Invoice ${invoice.invoiceNumber}',
          );
          if (invoice.quoteId.isNotEmpty) {
            await _ensureQuoteExists(invoice.quoteId);
          }
          final invoiceJson = invoice.toMap();
          final existing = await _dbHelper.getInvoice(invoice.id);

          if (existing != null) {
            await db.update(
              'invoices',
              invoiceJson,
              where: 'id = ?',
              whereArgs: [invoice.id],
            );
          } else {
            await db.insert('invoices', invoiceJson);
          }
          invoiceCount++;
        } catch (e) {
          _log('❌ Error syncing invoice ${invoice.invoiceNumber}: $e');
          try {
            await _verifyCustomerExists(
              invoice.customerId,
              context: 'Invoice ${invoice.invoiceNumber}',
            );
            final invoiceJson = invoice.toMap();
            invoiceJson['is_void'] = invoice.isVoid ? 1 : 0;
            await db.insert('invoices', invoiceJson);
            invoiceCount++;
          } catch (e2) {
            _log('❌ Failed to insert invoice ${invoice.invoiceNumber}: $e2');
          }
        }
      }
      _log('✅ Synced $invoiceCount invoices');

      // 7. Final verification
      final verification = await _dbHelper.verifyIntegrity();
      _log('📊 Integrity verification: $verification');

      _log('✅ Database sync completed successfully');
    } catch (e) {
      _log('❌ Error during sync: $e');
      rethrow;
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
      _log('🔒 Foreign keys re-enabled');
      _isSyncing = false;
      isSyncingNotifier.value = false;
      _syncCompleteController.add(null);
      await updatePendingCount();
    }
  }

  // ============================================
  // VERIFY CUSTOMER EXISTS
  // ============================================

  Future<void> _verifyCustomerExists(
    String customerId, {
    String? context,
  }) async {
    if (customerId.isEmpty) {
      _log(
        '⚠️ Empty customer ID provided${context != null ? " ($context)" : ""}',
      );
      return;
    }

    // Check if customer exists using a direct query
    final exists = await _dbHelper.customerExists(customerId);
    if (exists > 0) {
      _log('✅ Customer $customerId exists in local DB');
      return;
    }

    _log(
      '⚠️ Customer $customerId does not exist! Creating placeholder...${context != null ? " (Context: $context)" : ""}',
    );

    // Try to fetch from Supabase first
    if (await isOnline) {
      try {
        final response = await _supabase.client
            .from(SupabaseService.customersTable)
            .select()
            .eq('id', customerId)
            .maybeSingle();

        if (response != null) {
          final customer = Customer.fromJson(response);
          await _saveCustomerWithCheck(customer);
          _log('✅ Fetched customer from Supabase: ${customer.name}');
          return;
        }
      } catch (e) {
        _log('❌ Error fetching customer from Supabase: $e');
      }
    }

    // Create placeholder using INSERT OR REPLACE to avoid UNIQUE constraint errors
    final db = await _dbHelper.database;
    await db.rawInsert(
      '''
      INSERT OR REPLACE INTO customers (id, name, phone, email, address, site_location, site_notes, created_at, updated_at)
      VALUES (?, ?, NULL, NULL, NULL, NULL, NULL, ?, ?)
    ''',
      [
        customerId,
        'Unknown Customer (${customerId.substring(0, 8)})',
        DateTime.now().toIso8601String(),
        DateTime.now().toIso8601String(),
      ],
    );
    _log('✅ Created/updated placeholder customer for ID: $customerId');

    // Verify again
    final checkAgain = await _dbHelper.customerExists(customerId);
    if (checkAgain == 0) {
      _log('❌ CRITICAL: Failed to create customer $customerId');
    } else {
      _log('✅ Customer $customerId created successfully');
    }
  }

  Future<void> _ensureAllCustomersExist() async {
    _log('🔍 Ensuring all customers exist...');

    final db = await _dbHelper.database;

    // Find all quotes that reference non-existent customers
    final invalidQuotes = await db.rawQuery('''
      SELECT q.id, q.customer_id, q.quote_number 
      FROM quotes q
      LEFT JOIN customers c ON q.customer_id = c.id
      WHERE c.id IS NULL
    ''');

    for (var row in invalidQuotes) {
      final customerId = row['customer_id'] as String;
      final quoteNumber = row['quote_number'] as String;
      _log('⚠️ Quote $quoteNumber references missing customer: $customerId');
      await _verifyCustomerExists(customerId, context: 'Quote $quoteNumber');
    }

    // Check invoices with missing customers
    final invalidInvoices = await db.rawQuery('''
      SELECT i.id, i.customer_id, i.invoice_number 
      FROM invoices i
      LEFT JOIN customers c ON i.customer_id = c.id
      WHERE c.id IS NULL
    ''');

    for (var row in invalidInvoices) {
      final customerId = row['customer_id'] as String;
      final invoiceNumber = row['invoice_number'] as String;
      _log(
        '⚠️ Invoice $invoiceNumber references missing customer: $customerId',
      );
      await _verifyCustomerExists(
        customerId,
        context: 'Invoice $invoiceNumber',
      );
    }

    _log('✅ All customers ensured');
  }

  // ============================================
  // FETCH FROM SUPABASE
  // ============================================

  Future<List<Customer>> _fetchCustomersFromSupabase() async {
    try {
      final response = await _supabase.client
          .from(SupabaseService.customersTable)
          .select()
          .order('name');
      return response.map<Customer>((json) => Customer.fromJson(json)).toList();
    } catch (e) {
      _log('❌ Error fetching customers from Supabase: $e');
      return [];
    }
  }

  Future<List<Product>> _fetchProductsFromSupabase() async {
    try {
      final response = await _supabase.client
          .from(SupabaseService.productsTable)
          .select()
          .order('name');
      return response.map<Product>((json) => Product.fromJson(json)).toList();
    } catch (e) {
      _log('❌ Error fetching products from Supabase: $e');
      return [];
    }
  }

  Future<List<Quote>> _fetchQuotesFromSupabase() async {
    try {
      final response = await _supabase.client
          .from(SupabaseService.quotesTable)
          .select('*, customers!inner(name)')
          .order('created_at', ascending: false);
      return response.map<Quote>((json) => Quote.fromJson(json)).toList();
    } catch (e) {
      _log('❌ Error fetching quotes from Supabase: $e');
      return [];
    }
  }

  Future<List<Invoice>> _fetchInvoicesFromSupabase() async {
    try {
      final response = await _supabase.client
          .from(SupabaseService.invoicesTable)
          .select('*, customers!inner(name), quotes!inner(quote_number)')
          .order('created_at', ascending: false);
      return response.map<Invoice>((json) => Invoice.fromJson(json)).toList();
    } catch (e) {
      _log('❌ Error fetching invoices from Supabase: $e');
      return [];
    }
  }

  // ============================================
  // CUSTOMER OPERATIONS (Offline-First)
  // ============================================

  Future<List<Customer>> getCustomers({Function()? onSyncComplete}) async {
    // Always read from local DB first
    final maps = await _dbHelper.getAllCustomers();
    final localCustomers = maps.map((map) => Customer.fromJson(map)).toList();

    // If online, fetch latest in background
    isOnline.then((online) {
      if (online) {
        _log('🔄 [Background] Fetching latest customers from Supabase...');
        _fetchCustomersFromSupabase().then((supabaseCustomers) async {
          for (var customer in supabaseCustomers) {
            await _saveCustomerWithCheck(customer);
          }
          _log('✅ [Background] Customers sync complete');
          if (onSyncComplete != null) {
            onSyncComplete();
          }
        }).catchError((e) {
          _log('❌ [Background] Error fetching customers: $e');
        });
      }
    });

    return localCustomers;
  }

  Future<List<Customer>> getCustomersOnlyLocal() async {
    final maps = await _dbHelper.getAllCustomers();
    return maps.map((map) => Customer.fromJson(map)).toList();
  }

  Future<Customer?> getCustomer(String id) async {
    // Always read from local DB first
    final map = await _dbHelper.getCustomer(id);
    if (map != null) {
      return Customer.fromJson(map);
    }

    // If not found locally and online, fetch from Supabase
    if (await isOnline) {
      try {
        final response = await _supabase.client
            .from(SupabaseService.customersTable)
            .select()
            .eq('id', id)
            .maybeSingle();

        if (response != null) {
          final customer = Customer.fromJson(response);
          await _saveCustomerWithCheck(customer);
          return customer;
        }
      } catch (e) {
        _log('❌ Error fetching customer from Supabase: $e');
      }
    }

    return null;
  }

  Future<Customer?> createCustomer(Map<String, dynamic> data) async {
    final id = data['id'] ?? Helpers.generateId();
    final now = DateTime.now().toIso8601String();

    final customer = Customer(
      id: id,
      name: data['name'] ?? '',
      phone: data['phone'],
      email: data['email'],
      address: data['address'],
      siteLocation: data['site_location'],
      siteNotes: data['site_notes'],
      remarks: data['remarks'] ?? data['site_notes'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // 1. ALWAYS save to local DB first
    await _saveCustomerWithCheck(customer);

    // 2. Queue for background sync
    await _dbHelper.addToSyncQueue(
      tableName: 'customers',
      operation: 'insert',
      recordId: id,
      data: {...customer.toJson(), 'created_at': now, 'updated_at': now},
    );
    _log('📝 Queued customer for sync: ${customer.name}');
    await updatePendingCount();

    // 3. Trigger sync in background asynchronously
    _syncPendingData().catchError((e) => _log('Background sync error: $e'));

    return customer;
  }

  Future<Customer?> updateCustomer(String id, Map<String, dynamic> data) async {
    final map = await _dbHelper.getCustomer(id);
    if (map == null) return null;

    final customer = Customer.fromJson(map);
    final updated = customer.copyWith(
      name: data['name'] ?? customer.name,
      phone: data['phone'] ?? customer.phone,
      email: data['email'] ?? customer.email,
      address: data['address'] ?? customer.address,
      siteLocation: data['site_location'] ?? customer.siteLocation,
      siteNotes: data['site_notes'] ?? customer.siteNotes,
      remarks: data['remarks'] ?? customer.remarks,
    );

    // 1. ALWAYS save to local DB first
    await _saveCustomerWithCheck(updated);

    // 2. Queue for background sync
    await _dbHelper.addToSyncQueue(
      tableName: 'customers',
      operation: 'update',
      recordId: id,
      data: {...data, 'updated_at': DateTime.now().toIso8601String()},
    );
    _log('📝 Queued customer update for sync: ${updated.name}');
    await updatePendingCount();

    // 3. Trigger sync in background asynchronously
    _syncPendingData().catchError((e) => _log('Background sync error: $e'));

    return updated;
  }

  Future<bool> deleteCustomer(String id) async {
    // 1. Delete from local DB
    await _dbHelper.deleteCustomer(id);

    // 2. Queue for background sync
    await _dbHelper.addToSyncQueue(
      tableName: 'customers',
      operation: 'delete',
      recordId: id,
      data: {},
    );
    _log('📝 Queued customer deletion for sync: $id');
    await updatePendingCount();

    // 3. Trigger sync in background asynchronously
    _syncPendingData().catchError((e) => _log('Background sync error: $e'));

    return true;
  }

  // ============================================
  // PRODUCT OPERATIONS (Offline-First)
  // ============================================

  Future<List<Product>> getProducts({Function()? onSyncComplete}) async {
    await migrateProductCodesToIncremental();
    final maps = await _dbHelper.getAllProducts();
    final localProducts = maps.map((map) => Product.fromMap(map)).toList();

    isOnline.then((online) {
      if (online && !_isSyncing) {
        _log('🔄 [Background] Fetching latest products from Supabase...');
        _fetchProductsFromSupabase().then((supabaseProducts) async {
          if (_isSyncing) return;
          for (var product in supabaseProducts) {
            await _saveProductWithCheck(product);
          }
          _log('✅ [Background] Products sync complete');
          if (onSyncComplete != null) {
            onSyncComplete();
          }
        }).catchError((e) {
          _log('❌ [Background] Error fetching products: $e');
        });
      }
    });

    return localProducts;
  }

  Future<List<Product>> getProductsOnlyLocal() async {
    await migrateProductCodesToIncremental();
    final maps = await _dbHelper.getAllProducts();
    return maps.map((map) => Product.fromMap(map)).toList();
  }

  Future<Product?> getProduct(String id) async {
    final map = await _dbHelper.getProduct(id);
    if (map != null) {
      return Product.fromMap(map);
    }

    if (await isOnline) {
      try {
        final response = await _supabase.client
            .from(SupabaseService.productsTable)
            .select()
            .eq('id', id)
            .maybeSingle();

        if (response != null) {
          final product = Product.fromJson(response);
          await _saveProductWithCheck(product);
          return product;
        }
      } catch (e) {
        _log('❌ Error fetching product from Supabase: $e');
      }
    }

    return null;
  }

  Future<Product?> createProduct(Map<String, dynamic> data) async {
    final id = data['id'] ?? Helpers.generateId();
    final now = DateTime.now().toIso8601String();
    String sku =
        data['sku']?.toString() ?? await _generateSku(data['name'] ?? 'PROD');

    // Check for SKU conflicts locally
    final existingSku = await _dbHelper.query(
      'products',
      where: 'sku = ?',
      whereArgs: [sku],
    );
    if (existingSku.isNotEmpty) {
      sku = await _generateSku(data['name'] ?? 'PROD');
    }

    final product = Product(
      id: id,
      name: data['name'] ?? '',
      description: data['description'],
      category: data['category'] ?? '',
      subcategory: data['subcategory'],
      sku: sku,
      barcode: data['barcode'],
      unitPrice: data['unit_price']?.toDouble() ?? 0,
      costPrice: data['cost_price']?.toDouble() ?? 0,
      quantity: data['quantity']?.toInt() ?? 0,
      minStock: data['min_stock']?.toInt() ?? 5,
      maxStock: data['max_stock']?.toInt() ?? 100,
      unit: data['unit'],
      weight: data['weight']?.toDouble(),
      width: data['width']?.toDouble(),
      height: data['height']?.toDouble(),
      length: data['length']?.toDouble(),
      brand: data['brand'],
      supplier: data['supplier'],
      location: data['location'],
      isActive: data['is_active'] ?? true,
      isTaxable: data['is_taxable'] ?? true,
      taxRate: data['tax_rate']?.toDouble() ?? 16,
      imageUrl: data['image_url'],
      notes: data['notes'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // 1. ALWAYS save to local DB first
    await _saveProductWithCheck(product);

    // 2. Queue for background sync
    final safeData = _buildSafeProductData(data, sku);
    safeData['id'] = id;
    safeData['created_at'] = now;
    safeData['updated_at'] = now;

    await _dbHelper.addToSyncQueue(
      tableName: 'products',
      operation: 'insert',
      recordId: id,
      data: safeData,
    );
    _log('📝 Queued product for sync: ${product.name}');
    await updatePendingCount();

    // 3. Trigger sync in background asynchronously
    _syncPendingData().catchError((e) => _log('Background sync error: $e'));

    return product;
  }

  Future<Product?> updateProduct(String id, Map<String, dynamic> data) async {
    final map = await _dbHelper.getProduct(id);
    if (map == null) return null;

    final product = Product.fromMap(map);
    final updated = product.copyWith(
      name: data['name'] ?? product.name,
      description: data['description'] ?? product.description,
      category: data['category'] ?? product.category,
      unitPrice: data['unit_price']?.toDouble() ?? product.unitPrice,
      quantity: data['quantity']?.toInt() ?? product.quantity,
      minStock: data['min_stock']?.toInt() ?? product.minStock,
    );

    // 1. ALWAYS save to local DB first
    await _saveProductWithCheck(updated);

    // 2. Queue for background sync
    await _dbHelper.addToSyncQueue(
      tableName: 'products',
      operation: 'update',
      recordId: id,
      data: {...data, 'updated_at': DateTime.now().toIso8601String()},
    );
    _log('📝 Queued product update for sync: ${updated.name}');
    await updatePendingCount();

    // 3. Trigger sync in background asynchronously
    _syncPendingData().catchError((e) => _log('Background sync error: $e'));

    return updated;
  }

  Future<bool> deleteProduct(String id) async {
    // 1. Delete from local DB
    await _dbHelper.deleteProduct(id);

    // 2. Queue for background sync
    await _dbHelper.addToSyncQueue(
      tableName: 'products',
      operation: 'delete',
      recordId: id,
      data: {},
    );
    _log('📝 Queued product deletion for sync: $id');
    await updatePendingCount();

    // 3. Trigger sync in background asynchronously
    _syncPendingData().catchError((e) => _log('Background sync error: $e'));

    return true;
  }

  // ============================================
  // QUOTE OPERATIONS (Offline-First)
  // ============================================

  Future<Quote> _hydrateQuote(Quote quote) async {
    try {
      final customerMap = quote.customerId.isNotEmpty
          ? await _dbHelper.getCustomer(quote.customerId)
          : null;
      final itemMaps = await _dbHelper.getQuoteItems(quote.id);
      final items = itemMaps.map((map) => QuoteItem.fromJson(map)).toList();

      return quote.copyWith(
        customerName: customerMap?['name']?.toString() ?? quote.customerName,
        customer: customerMap != null ? Customer.fromJson(customerMap) : null,
        items: items.isNotEmpty ? items : quote.items,
      );
    } catch (e) {
      _log('❌ Error hydrating quote ${quote.quoteNumber}: $e');
      return quote;
    }
  }

  Future<Invoice> _hydrateInvoice(Invoice invoice) async {
    try {
      final customerMap = invoice.customerId.isNotEmpty
          ? await _dbHelper.getCustomer(invoice.customerId)
          : null;
      final quoteMap = invoice.quoteId.isNotEmpty
          ? await _dbHelper.getQuote(invoice.quoteId)
          : null;

      Quote? quoteObj;
      if (quoteMap != null) {
        quoteObj = Quote.fromJson(quoteMap);
        quoteObj = await _hydrateQuote(quoteObj);
      }

      final subtotal = (invoice.subtotal > 0)
          ? invoice.subtotal
          : (quoteObj != null ? quoteObj.effectiveSubtotal : 0.0);
      final total = (invoice.total > 0)
          ? invoice.total
          : (quoteObj != null ? quoteObj.effectiveTotal : 0.0);
      final balanceDue = (invoice.balanceDue > 0 || invoice.amountPaid > 0)
          ? (total - invoice.amountPaid).clamp(0.0, total)
          : total;

      return invoice.copyWith(
        subtotal: subtotal,
        total: total,
        balanceDue: balanceDue,
        customerName: customerMap?['name']?.toString() ?? invoice.customerName,
        customer: customerMap != null ? Customer.fromJson(customerMap) : null,
        quoteNumber:
            quoteMap?['quote_number']?.toString() ?? invoice.quoteNumber,
        quote: quoteObj,
      );
    } catch (e) {
      _log('❌ Error hydrating invoice ${invoice.invoiceNumber}: $e');
      return invoice;
    }
  }

  Future<void> _syncQuoteItemsForQuote(String quoteId) async {
    if (quoteId.isEmpty) return;

    try {
      final response = await _supabase.client
          .from(SupabaseService.quoteItemsTable)
          .select('*, products(name)')
          .eq('quote_id', quoteId)
          .order('created_at', ascending: true);

      for (final itemJson in response) {
        await _saveQuoteItemWithCheck(QuoteItem.fromJson(itemJson));
      }
    } catch (e) {
      _log('❌ Error syncing quote items for quote $quoteId: $e');
    }
  }

  Future<List<Quote>> getQuotes({Function()? onSyncComplete}) async {
    final maps = await _dbHelper.getAllQuotes();
    final localQuotes = await Future.wait(
      maps.map((map) async => _hydrateQuote(Quote.fromJson(map))),
    );

    isOnline.then((online) {
      if (online) {
        _log('🔄 [Background] Fetching latest quotes from Supabase...');
        _fetchQuotesFromSupabase().then((supabaseQuotes) async {
          for (var quote in supabaseQuotes) {
            await _verifyCustomerExists(
              quote.customerId,
              context: 'Quote ${quote.quoteNumber}',
            );
            await _saveQuoteWithCheck(quote);
            await _syncQuoteItemsForQuote(quote.id);
          }
          _log('✅ [Background] Quotes sync complete');
          if (onSyncComplete != null) {
            onSyncComplete();
          }
        }).catchError((e) {
          _log('❌ [Background] Error fetching quotes: $e');
        });
      }
    });

    return localQuotes;
  }

  Future<List<Quote>> getQuotesOnlyLocal() async {
    final maps = await _dbHelper.getAllQuotes();
    return Future.wait(
      maps.map((map) async => _hydrateQuote(Quote.fromJson(map))),
    );
  }

  Future<Quote?> getQuote(String id) async {
    final map = await _dbHelper.getQuote(id);
    if (map != null) {
      return _hydrateQuote(Quote.fromJson(map));
    }

    if (await isOnline) {
      try {
        final response = await _supabase.client
            .from(SupabaseService.quotesTable)
            .select('*, customers!inner(name)')
            .eq('id', id)
            .maybeSingle();

        if (response != null) {
          final quote = Quote.fromJson(response);
          await _verifyCustomerExists(
            quote.customerId,
            context: 'Quote ${quote.quoteNumber}',
          );
          await _saveQuoteWithCheck(quote);
          await _syncQuoteItemsForQuote(quote.id);
          return _hydrateQuote(quote);
        }
      } catch (e) {
        _log('❌ Error fetching quote from Supabase: $e');
      }
    }

    return null;
  }

  Future<List<Quote>> getQuotesByUser(String userId) async {
    // Read from local DB first
    final maps = await _dbHelper.getQuotesByUser(userId);
    final localQuotes = await Future.wait(
      maps.map((map) async => _hydrateQuote(Quote.fromJson(map))),
    );

    // If online, fetch latest in background
    if (await isOnline) {
      try {
        final response = await _supabase.client
            .from(SupabaseService.quotesTable)
            .select('*, customers!inner(name)')
            .eq('user_id', userId)
            .order('created_at', ascending: false);

        final quotes = response
            .map<Quote>((json) => Quote.fromJson(json))
            .toList();

        for (var quote in quotes) {
          await _verifyCustomerExists(
            quote.customerId,
            context: 'Quote ${quote.quoteNumber}',
          );
          await _saveQuoteWithCheck(quote);
          await _syncQuoteItemsForQuote(quote.id);
        }

        final updatedMaps = await _dbHelper.getQuotesByUser(userId);
        return Future.wait(
          updatedMaps.map((map) async => _hydrateQuote(Quote.fromJson(map))),
        );
      } catch (e) {
        _log('❌ Error fetching quotes by user from Supabase: $e');
        return localQuotes;
      }
    }

    return localQuotes;
  }

  Future<List<Quote>> getQuotesByCustomer(String customerId) async {
    // Read from local DB first
    final maps = await _dbHelper.getQuotesByCustomer(customerId);
    final localQuotes = await Future.wait(
      maps.map((map) async => _hydrateQuote(Quote.fromJson(map))),
    );

    // If online, fetch latest in background
    if (await isOnline) {
      try {
        final response = await _supabase.client
            .from(SupabaseService.quotesTable)
            .select('*, customers!inner(name)')
            .eq('customer_id', customerId)
            .order('created_at', ascending: false);

        final quotes = response
            .map<Quote>((json) => Quote.fromJson(json))
            .toList();

        for (var quote in quotes) {
          await _verifyCustomerExists(
            quote.customerId,
            context: 'Quote ${quote.quoteNumber}',
          );
          await _saveQuoteWithCheck(quote);
          await _syncQuoteItemsForQuote(quote.id);
        }

        final updatedMaps = await _dbHelper.getQuotesByCustomer(customerId);
        return Future.wait(
          updatedMaps.map((map) async => _hydrateQuote(Quote.fromJson(map))),
        );
      } catch (e) {
        _log('❌ Error fetching quotes by customer from Supabase: $e');
        return localQuotes;
      }
    }

    return localQuotes;
  }

  Future<List<Quote>> getQuotesByStatus(String status) async {
    final maps = await _dbHelper.getQuotesByStatus(status);
    return Future.wait(
      maps.map((map) async => _hydrateQuote(Quote.fromJson(map))),
    );
  }

  Future<Quote?> createQuote(Map<String, dynamic> data) async {
    final id = data['id'] ?? Helpers.generateId();
    final now = DateTime.now().toIso8601String();

    // Ensure customer exists first
    if (data['customer_id'] != null) {
      await _verifyCustomerExists(
        data['customer_id'],
        context: 'Creating quote',
      );
    }

    final quote = Quote(
      id: id,
      quoteNumber: data['quote_number'] ?? await generateQuoteNumber(),
      customerId: data['customer_id'] ?? '',
      userId: data['user_id'],
      title: data['title'],
      status: data['status'] ?? Constants.quoteStatusDraft,
      subtotal: data['subtotal']?.toDouble() ?? 0,
      tax: data['tax']?.toDouble() ?? 0,
      total: data['total']?.toDouble() ?? 0,
      discount: data['discount']?.toDouble() ?? 0,
      grandTotal: data['grand_total']?.toDouble() ?? 0,
      validityDays:
          data['validity_days']?.toInt() ?? Constants.defaultQuoteValidityDays,
      scope: data['scope'],
      notes: data['notes'],
      siteMeasurements: data['site_measurements'],
      expiryDate: data['expiry_date'] != null
          ? DateTime.parse(data['expiry_date'])
          : null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      customerName: null,
      items: [],
    );

    // 1. ALWAYS save to local DB first
    await _saveQuoteWithCheck(quote);

    // Save items locally
    if (data['items'] != null) {
      final items = data['items'] as List;
      for (var itemData in items) {
        final item = itemData is QuoteItem
            ? itemData
            : QuoteItem.fromJson(itemData);
        await _saveQuoteItemWithCheck(item);
      }
    }

    // 2. Queue for background sync
    await _dbHelper.addToSyncQueue(
      tableName: 'quotes',
      operation: 'insert',
      recordId: id,
      data: {...quote.toJson(), 'created_at': now, 'updated_at': now},
    );
    _log('📝 Queued quote for sync: ${quote.quoteNumber}');
    await updatePendingCount();

    // 3. Trigger sync in background asynchronously
    _syncPendingData().catchError((e) => _log('Background sync error: $e'));

    return quote;
  }

  Future<Quote?> updateQuote(String id, Map<String, dynamic> data) async {
    try {
      final existing = await _dbHelper.getQuote(id);
      if (existing == null) return null;

      final quote = Quote.fromJson(existing);
      final updated = quote.copyWith(
        title: data['title'] ?? quote.title,
        status: data['status'] ?? quote.status,
        subtotal: data['subtotal']?.toDouble() ?? quote.subtotal,
        tax: data['tax']?.toDouble() ?? quote.tax,
        total: data['total']?.toDouble() ?? quote.total,
        discount: data['discount']?.toDouble() ?? quote.discount,
        grandTotal: data['grand_total']?.toDouble() ?? quote.grandTotal,
        scope: data['scope'] ?? quote.scope,
        notes: data['notes'] ?? quote.notes,
        siteMeasurements: data['site_measurements'] ?? quote.siteMeasurements,
        updatedAt: DateTime.now(),
      );

      // 1. ALWAYS save to local DB first
      await _saveQuoteWithCheck(updated);

      // 2. Queue for background sync
      await _dbHelper.addToSyncQueue(
        tableName: 'quotes',
        operation: 'update',
        recordId: id,
        data: {...data, 'updated_at': DateTime.now().toIso8601String()},
      );
      _log('📝 Queued quote update for sync: ${quote.quoteNumber}');
      await updatePendingCount();

      // 3. Trigger sync in background asynchronously
      _syncPendingData().catchError((e) => _log('Background sync error: $e'));

      return updated;
    } catch (e) {
      _log('❌ Error updating quote: $e');
      return null;
    }
  }

  Future<Quote?> updateQuoteStatus(String id, String status) async {
    final map = await _dbHelper.getQuote(id);
    if (map == null) return null;

    final quote = Quote.fromJson(map);
    final updated = quote.copyWith(status: status);

    // 1. ALWAYS save to local DB first
    await _saveQuoteWithCheck(updated);

    // 2. Queue for background sync
    await _dbHelper.addToSyncQueue(
      tableName: 'quotes',
      operation: 'update',
      recordId: id,
      data: {'status': status, 'updated_at': DateTime.now().toIso8601String()},
    );
    _log('📝 Queued quote status update for sync: ${quote.quoteNumber}');
    await updatePendingCount();

    // 3. Trigger sync in background asynchronously
    _syncPendingData().catchError((e) => _log('Background sync error: $e'));

    return updated;
  }

  Future<bool> deleteQuote(String id) async {
    try {
      // First delete quote items
      await deleteQuoteItemsByQuoteId(id);

      // 1. Delete from local DB
      await _dbHelper.deleteQuote(id);
      _log('✅ Quote deleted locally: $id');

      // 2. Queue for background sync
      await _dbHelper.addToSyncQueue(
        tableName: 'quotes',
        operation: 'delete',
        recordId: id,
        data: {},
      );
      _log('📝 Queued quote deletion for sync: $id');
      await updatePendingCount();

      // 3. Trigger sync in background asynchronously
      _syncPendingData().catchError((e) => _log('Background sync error: $e'));

      return true;
    } catch (e) {
      _log('❌ Error deleting quote: $e');
      return false;
    }
  }

  // ============================================
  // QUOTE ITEM OPERATIONS
  // ============================================

  Future<List<QuoteItem>> getQuoteItems(String quoteId) async {
    try {
      final maps = await _dbHelper.getQuoteItems(quoteId);
      return maps.map((map) => QuoteItem.fromJson(map)).toList();
    } catch (e) {
      _log('❌ Error getting quote items: $e');
      return [];
    }
  }

  Future<QuoteItem?> createQuoteItem(Map<String, dynamic> data) async {
    final id = data['id'] ?? Helpers.generateId();
    final now = DateTime.now().toIso8601String();

    final item = QuoteItem(
      id: id,
      quoteId: data['quote_id'] ?? '',
      productId: data['product_id'],
      itemType: data['item_type'] ?? Constants.itemTypeStock,
      description: data['description'] ?? '',
      quantity: data['quantity']?.toInt() ?? 1,
      unitPrice: data['unit_price']?.toDouble() ?? 0,
      total: data['total']?.toDouble() ?? 0,
      discount: data['discount']?.toDouble() ?? 0,
      tax: data['tax']?.toDouble() ?? 0,
      unit: data['unit'],
      section: data['section'],
      createdAt: DateTime.now(),
      productName: data['product_name'],
    );

    // 1. ALWAYS save to local DB first
    await _saveQuoteItemWithCheck(item);

    // 2. Queue for background sync
    await _dbHelper.addToSyncQueue(
      tableName: 'quote_items',
      operation: 'insert',
      recordId: id,
      data: {...item.toJson(), 'id': id, 'created_at': now},
    );
    _log('📝 Queued quote item for sync');
    await updatePendingCount();

    // 3. Trigger sync in background asynchronously
    _syncPendingData().catchError((e) => _log('Background sync error: $e'));

    return item;
  }

  Future<QuoteItem?> updateQuoteItem(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final existing = await _dbHelper.query(
        'quote_items',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (existing.isEmpty) return null;

      final item = QuoteItem.fromJson(existing.first);
      final updated = QuoteItem(
        id: item.id,
        quoteId: data['quote_id'] ?? item.quoteId,
        productId: data['product_id'] ?? item.productId,
        itemType: data['item_type'] ?? item.itemType,
        description: data['description'] ?? item.description,
        quantity: data['quantity']?.toInt() ?? item.quantity,
        unitPrice: data['unit_price']?.toDouble() ?? item.unitPrice,
        total: data['total']?.toDouble() ?? item.total,
        discount: data['discount']?.toDouble() ?? item.discount,
        tax: data['tax']?.toDouble() ?? item.tax,
        unit: data['unit'] ?? item.unit,
        section: data['section'] ?? item.section,
        createdAt: item.createdAt,
        productName: data['product_name'] ?? item.productName,
      );

      // 1. ALWAYS save to local DB first
      await _saveQuoteItemWithCheck(updated);

      // 2. Queue for background sync
      await _dbHelper.addToSyncQueue(
        tableName: 'quote_items',
        operation: 'update',
        recordId: id,
        data: {...data, 'updated_at': DateTime.now().toIso8601String()},
      );
      _log('📝 Queued quote item update for sync');
      await updatePendingCount();

      // 3. Trigger sync in background asynchronously
      _syncPendingData().catchError((e) => _log('Background sync error: $e'));

      return updated;
    } catch (e) {
      _log('❌ Error updating quote item: $e');
      return null;
    }
  }

  Future<bool> deleteQuoteItem(String id) async {
    try {
      // 1. Delete from local DB
      await _dbHelper.deleteQuoteItem(id);
      _log('✅ Quote item deleted locally');

      // 2. Queue for background sync
      await _dbHelper.addToSyncQueue(
        tableName: 'quote_items',
        operation: 'delete',
        recordId: id,
        data: {},
      );
      _log('📝 Queued quote item deletion for sync');
      await updatePendingCount();

      // 3. Trigger sync in background asynchronously
      _syncPendingData().catchError((e) => _log('Background sync error: $e'));

      return true;
    } catch (e) {
      _log('❌ Error deleting quote item: $e');
      return false;
    }
  }

  Future<void> deleteQuoteItemsByQuoteId(String quoteId) async {
    try {
      // 1. Delete from local DB
      await _dbHelper.deleteQuoteItems(quoteId);
      _log('✅ Quote items deleted locally for quote: $quoteId');

      // 2. Queue for background sync
      await _dbHelper.addToSyncQueue(
        tableName: 'quote_items',
        operation: 'delete',
        recordId: quoteId,
        data: {},
      );
      _log('📝 Queued quote items deletion for sync for quote: $quoteId');
      await updatePendingCount();

      // 3. Trigger sync in background asynchronously
      _syncPendingData().catchError((e) => _log('Background sync error: $e'));
    } catch (e) {
      _log('❌ Error deleting quote items: $e');
    }
  }

  // ============================================
  // INVOICE OPERATIONS (Offline-First)
  // ============================================

  Future<List<Invoice>> getInvoices({Function()? onSyncComplete}) async {
    final maps = await _dbHelper.getAllInvoices();
    final localInvoices = await Future.wait(
      maps.map((map) async => _hydrateInvoice(Invoice.fromJson(map))),
    );

    isOnline.then((online) {
      if (online) {
        _log('🔄 [Background] Fetching latest invoices from Supabase...');
        _fetchInvoicesFromSupabase().then((supabaseInvoices) async {
          for (var invoice in supabaseInvoices) {
            await _verifyCustomerExists(
              invoice.customerId,
              context: 'Invoice ${invoice.invoiceNumber}',
            );
            await _saveInvoiceWithCheck(invoice);
          }
          _log('✅ [Background] Invoices sync complete');
          if (onSyncComplete != null) {
            onSyncComplete();
          }
        }).catchError((e) {
          _log('❌ [Background] Error fetching invoices: $e');
        });
      }
    });

    return localInvoices;
  }

  Future<List<Invoice>> getInvoicesOnlyLocal() async {
    final maps = await _dbHelper.getAllInvoices();
    return Future.wait(
      maps.map((map) async => _hydrateInvoice(Invoice.fromJson(map))),
    );
  }

  Future<Invoice?> getInvoice(String id) async {
    // Try local first
    final map = await _dbHelper.getInvoice(id);
    if (map != null) {
      return _hydrateInvoice(Invoice.fromJson(map));
    }

    // If not found locally and online, fetch from Supabase
    if (await isOnline) {
      try {
        final response = await _supabase.client
            .from(SupabaseService.invoicesTable)
            .select('*, customers!inner(name), quotes!inner(quote_number)')
            .eq('id', id)
            .maybeSingle();

        if (response != null) {
          final invoice = Invoice.fromJson(response);
          await _verifyCustomerExists(
            invoice.customerId,
            context: 'Invoice ${invoice.invoiceNumber}',
          );
          await _saveInvoiceWithCheck(invoice);
          return _hydrateInvoice(invoice);
        }
      } catch (e) {
        _log('❌ Error fetching invoice from Supabase: $e');
      }
    }

    return null;
  }

  Future<Invoice?> createInvoice(Map<String, dynamic> data) async {
    final id = data['id'] ?? Helpers.generateId();
    final now = DateTime.now().toIso8601String();

    if (data['customer_id'] != null) {
      await _verifyCustomerExists(
        data['customer_id'],
        context: 'Creating invoice',
      );
    }

    if (data['quote_id'] != null) {
      await _ensureQuoteExists(data['quote_id']);
    }

    String invoiceNumber = data['invoice_number']?.toString() ?? '';
    if (invoiceNumber.isEmpty) {
      invoiceNumber = await generateInvoiceNumber();
    }

    final invoice = Invoice(
      id: id,
      invoiceNumber: invoiceNumber,
      quoteId: data['quote_id'] ?? '',
      customerId: data['customer_id'] ?? '',
      subtotal: data['subtotal']?.toDouble() ?? 0,
      tax: data['tax']?.toDouble() ?? 0,
      discount: data['discount']?.toDouble() ?? 0,
      total: data['total']?.toDouble() ?? 0,
      amountPaid: data['amount_paid']?.toDouble() ?? 0,
      balanceDue: data['balance_due']?.toDouble() ?? 0,
      paymentStatus: data['payment_status'] ?? Constants.invoiceStatusUnpaid,
      paymentDate: data['payment_date'] != null
          ? DateTime.parse(data['payment_date'])
          : null,
      dueDate: data['due_date'] != null
          ? DateTime.parse(data['due_date'])
          : null,
      issuedDate: data['issued_date'] != null
          ? DateTime.parse(data['issued_date'])
          : null,
      scope: data['scope'],
      notes: data['notes'],
      terms: data['terms'],
      currency: data['currency'] ?? 'KES',
      isVoid: data['is_void'] ?? false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // 1. ALWAYS save to local DB first
    await _saveInvoiceWithCheck(invoice);

    // 2. Queue for background sync
    await _dbHelper.addToSyncQueue(
      tableName: 'invoices',
      operation: 'insert',
      recordId: id,
      data: {...invoice.toJson(), 'created_at': now, 'updated_at': now},
    );
    _log('📝 Queued invoice for sync: ${invoice.invoiceNumber}');
    await updatePendingCount();

    // 3. Trigger sync in background asynchronously
    _syncPendingData().catchError((e) => _log('Background sync error: $e'));

    return invoice;
  }

  Future<Invoice?> createDirectInvoice(Map<String, dynamic> data) async {
    final quoteId = data['quote_id'] ?? Helpers.generateId();
    final customerId = data['customer_id'] ?? '';
    final userId = data['user_id'] ?? '';

    // Generate invoice number
    String invoiceNumber = data['invoice_number']?.toString() ?? '';
    if (invoiceNumber.isEmpty) {
      invoiceNumber = await generateInvoiceNumber();
    }

    final quoteData = {
      'id': quoteId,
      'quote_number': await generateQuoteNumber(),
      'customer_id': customerId,
      'user_id': userId,
      'status': Constants.quoteStatusConverted,
      'subtotal': data['subtotal'] ?? 0.0,
      'tax': data['tax'] ?? 0.0,
      'total': data['total'] ?? 0.0,
      'grand_total': data['total'] ?? 0.0,
      'discount': data['discount'] ?? 0.0,
      'scope': data['scope'],
      'notes': data['notes'],
      'site_measurements': data['site_measurements'],
    };

    // Create the quote
    final quote = await createQuote(quoteData);
    if (quote != null && data['items'] != null) {
      final items = data['items'] as List;
      for (var itemData in items) {
        final item = itemData is QuoteItem
            ? itemData
            : QuoteItem.fromJson(itemData);
        
        final updatedItem = QuoteItem(
          id: item.id,
          quoteId: quoteId,
          productId: item.productId,
          itemType: item.itemType,
          description: item.description,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          discount: item.discount,
          tax: item.tax,
          total: item.total,
          createdAt: item.createdAt,
          productName: item.productName,
          section: item.section,
        );
        await _saveQuoteItemWithCheck(updatedItem);
        
        final now = DateTime.now().toIso8601String();
        await _dbHelper.addToSyncQueue(
          tableName: 'quote_items',
          operation: 'insert',
          recordId: item.id,
          data: {...updatedItem.toJson(), 'created_at': now, 'updated_at': now},
        );
      }
    }

    final invoiceData = {
      ...data,
      'invoice_number': invoiceNumber,
      'quote_id': quoteId,
    };

    return await createInvoice(invoiceData);
  }

  Future<Invoice?> updateInvoicePayment(
    String id,
    String paymentStatus, {
    double? amountPaid,
  }) async {
    try {
      final invoice = await getInvoice(id);
      if (invoice == null) return null;

      final updates = <String, dynamic>{
        'payment_status': paymentStatus,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (paymentStatus == Constants.invoiceStatusPaid) {
        updates['payment_date'] = DateTime.now().toIso8601String();
        if (amountPaid != null) {
          updates['amount_paid'] = amountPaid;
          updates['balance_due'] = invoice.total - amountPaid;
        } else {
          updates['amount_paid'] = invoice.total;
          updates['balance_due'] = 0;
        }
      } else if (paymentStatus == Constants.invoiceStatusPartial) {
        if (amountPaid != null) {
          updates['amount_paid'] = amountPaid;
          updates['balance_due'] = invoice.total - amountPaid;
          updates['payment_date'] = DateTime.now().toIso8601String();
        } else {
          // Keep existing payment fields or default them
          updates['amount_paid'] = invoice.amountPaid;
          updates['balance_due'] = invoice.balanceDue;
          updates['payment_date'] = invoice.paymentDate?.toIso8601String() ?? DateTime.now().toIso8601String();
        }
      } else {
        updates['payment_date'] = null;
        updates['amount_paid'] = 0;
        updates['balance_due'] = invoice.total;
      }

      // 1. ALWAYS update local DB first
      final invoiceJson = invoice.toMap();
      final updatedJson = {...invoiceJson, ...updates};
      await _dbHelper.update(
        'invoices',
        updatedJson,
        where: 'id = ?',
        whereArgs: [id],
      );
      _log('✅ Invoice updated locally: ${invoice.invoiceNumber}');

      // 2. Queue for background sync
      await _dbHelper.addToSyncQueue(
        tableName: 'invoices',
        operation: 'update',
        recordId: id,
        data: updates,
      );
      _log('📝 Queued invoice update for sync: ${invoice.invoiceNumber}');
      await updatePendingCount();

      // 3. Trigger sync in background asynchronously
      _syncPendingData().catchError((e) => _log('Background sync error: $e'));

      // Return the hydrated locally updated invoice
      final updatedInvoice = Invoice.fromJson(updatedJson);
      return await _hydrateInvoice(updatedInvoice);
    } catch (e) {
      _log('❌ Error updating invoice payment: $e');
      return null;
    }
  }

  Future<Invoice?> createInvoiceFromQuote(String quoteId) async {
    try {
      final quote = await getQuote(quoteId);
      if (quote == null) return null;

      final effSubtotal = quote.effectiveSubtotal;
      final effTotal = quote.effectiveTotal;

      // Create invoice data from quote
      final invoiceData = {
        'quote_id': quoteId,
        'customer_id': quote.customerId,
        'subtotal': effSubtotal,
        'tax': quote.tax > 0 ? quote.tax : (effTotal - effSubtotal),
        'discount': quote.discount,
        'total': effTotal,
        'amount_paid': 0,
        'balance_due': effTotal,
        'payment_status': Constants.invoiceStatusUnpaid,
        'due_date': DateTime.now()
            .add(Duration(days: quote.validityDays))
            .toIso8601String(),
        'issued_date': DateTime.now().toIso8601String(),
        'scope': quote.scope,
        'notes': 'Invoice generated from quote ${quote.quoteNumber}',
        'currency': 'KES',
        'is_void': false,
      };

      // Create the invoice
      final invoice = await createInvoice(invoiceData);

      if (invoice != null) {
        // Update quote status to converted
        await updateQuoteStatus(quoteId, Constants.quoteStatusConverted);
        _log('✅ Invoice created from quote: ${quote.quoteNumber}');
        return invoice;
      }

      return null;
    } catch (e) {
      _log('❌ Error creating invoice from quote: $e');
      return null;
    }
  }

  Future<bool> deleteInvoice(String id) async {
    try {
      // Check if invoice exists
      final invoice = await getInvoice(id);
      if (invoice == null) return false;

      // 1. Delete from local DB
      await _dbHelper.deleteInvoice(id);
      _log('✅ Invoice deleted locally: ${invoice.invoiceNumber}');

      // 2. Queue for background sync
      await _dbHelper.addToSyncQueue(
        tableName: 'invoices',
        operation: 'delete',
        recordId: id,
        data: {},
      );
      _log('📝 Queued invoice deletion for sync: ${invoice.invoiceNumber}');
      await updatePendingCount();

      // 3. Trigger sync in background asynchronously
      _syncPendingData().catchError((e) => _log('Background sync error: $e'));

      return true;
    } catch (e) {
      _log('❌ Error deleting invoice: $e');
      return false;
    }
  }

  // ============================================
  // REPAIR AND CLEANUP
  // ============================================

  Future<void> repairAndCleanup() async {
    // Prevent concurrent syncs
    if (_isSyncing) {
      _log('⚠️ Repair already in progress, skipping...');
      return;
    }

    _isSyncing = true;
    _log('🔧 Starting database repair and cleanup...');

    final db = await _dbHelper.database;
    await db.execute('PRAGMA foreign_keys = OFF');

    try {
      // 1. Fix customers
      _log('📊 Checking customers...');
      final supabaseCustomers = await _supabase.client
          .from(SupabaseService.customersTable)
          .select()
          .limit(1000);

      for (var customerJson in supabaseCustomers) {
        final customer = Customer.fromJson(customerJson);
        final existing = await _dbHelper.getCustomer(customer.id);
        if (existing == null) {
          await _dbHelper.insert('customers', customer.toJson());
          _log('✅ Inserted missing customer: ${customer.name}');
        }
      }

      // 2. Use DatabaseHelper's repairForeignKeys
      final repairResult = await _dbHelper.repairForeignKeys();
      _log('✅ Foreign key repair result: $repairResult');

      // 3. Fix quotes with missing customers using our method
      _log('📊 Checking quotes...');
      final allQuotes = await _dbHelper.getAllQuotes();
      int fixedQuotes = 0;

      for (var quoteMap in allQuotes) {
        final quote = Quote.fromJson(quoteMap);
        final customerExists = await _dbHelper.getCustomer(quote.customerId);

        if (customerExists == null) {
          await _verifyCustomerExists(
            quote.customerId,
            context: 'Quote ${quote.quoteNumber}',
          );
          fixedQuotes++;
        }
      }
      _log('✅ Fixed $fixedQuotes quotes');

      // 4. Fix invoices
      _log('📊 Checking invoices...');
      final allInvoices = await _dbHelper.getAllInvoices();
      int fixedInvoices = 0;

      for (var invoiceMap in allInvoices) {
        final invoice = Invoice.fromJson(invoiceMap);

        final customerExists = await _dbHelper.getCustomer(invoice.customerId);
        if (customerExists == null) {
          await _verifyCustomerExists(
            invoice.customerId,
            context: 'Invoice ${invoice.invoiceNumber}',
          );
          fixedInvoices++;
        }

        if (invoice.quoteId.isNotEmpty) {
          final quoteExists = await _dbHelper.getQuote(invoice.quoteId);
          if (quoteExists == null) {
            final response = await _supabase.client
                .from(SupabaseService.quotesTable)
                .select()
                .eq('id', invoice.quoteId)
                .maybeSingle();

            if (response != null) {
              final quote = Quote.fromJson(response);
              await _verifyCustomerExists(
                quote.customerId,
                context: 'Quote ${quote.quoteNumber}',
              );
              await _dbHelper.insert('quotes', quote.toJson());
              _log('✅ Inserted quote for invoice ${invoice.invoiceNumber}');
              fixedInvoices++;
            }
          }
        }
      }
      _log('✅ Fixed $fixedInvoices invoices');

      // 5. Remove orphaned records
      _log('📊 Cleaning up orphaned records...');

      final orphanedItems = await db.rawQuery('''
        SELECT qi.id FROM quote_items qi
        LEFT JOIN quotes q ON qi.quote_id = q.id
        WHERE q.id IS NULL
      ''');
      if (orphanedItems.isNotEmpty) {
        await db.delete('quote_items');
        _log('✅ Removed ${orphanedItems.length} orphaned quote items');
      }

      // 6. Fix duplicate SKUs
      await _fixDuplicateSkus();

      // Migrate old numbering formats
      await migrateOldNumberingFormats();

      // Reset retry counts for failed sync items
      _log('🔄 Resetting failed sync queue items to retry...');
      final failedItems = await _dbHelper.getFailedSyncItems();
      for (var item in failedItems) {
        final id = item['id'] as int;
        await _dbHelper.resetSyncItem(id);
      }
      _log('✅ Reset ${failedItems.length} failed sync items');

      // 7. Vacuum database
      _log('📊 Vacuuming database...');
      await db.execute('VACUUM');
      _log('✅ Database vacuumed');

      // 8. Final verification
      final verification = await _dbHelper.verifyIntegrity();
      _log('📊 Final integrity verification: $verification');

      _log('✅ Database repair and cleanup completed successfully!');
    } catch (e) {
      _log('❌ Error during repair: $e');
      rethrow;
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
      _log('🔒 Foreign keys re-enabled');
      _isSyncing = false;
    }
  }

  Future<void> _repairData() async {
    // Use DatabaseHelper's repair method
    await _dbHelper.repairForeignKeys();
  }

  Future<void> forceRenumberAllRecords() async {
    _log('🔄 Force renumbering all existing quotes and invoices...');
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    // 1. Force Renumber Quotes
    try {
      final quoteRegex = RegExp(r'^\d{3}[A-Z]$');
      
      // Get starting quote number from preferences
      String startQuoteNum = '010A';
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedStart = prefs.getString('start_quote_number')?.trim();
        if (savedStart != null && quoteRegex.hasMatch(savedStart)) {
          startQuoteNum = savedStart;
        }
      } catch (_) {}

      // Get all quotes sorted by created_at
      final quotesList = await db.query(
        'quotes',
        orderBy: 'created_at ASC, id ASC',
      );

      _log('⚠️ Starting quote force renumbering for ${quotesList.length} records...');
      
      // Step 1: Move all to temporary format to prevent UNIQUE constraints failures
      for (int i = 0; i < quotesList.length; i++) {
        final quoteId = quotesList[i]['id'] as String;
        final tempNumber = 'TEMP-Q-${quoteId.substring(0, 8)}-$i';
        await db.update(
          'quotes',
          {'quote_number': tempNumber, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [quoteId],
        );
      }

      // Step 2: Assign final sequential numbers
      String currentQuoteNum = startQuoteNum;
      for (int i = 0; i < quotesList.length; i++) {
        final quoteId = quotesList[i]['id'] as String;
        final oldNumber = quotesList[i]['quote_number'] as String;
        
        _log('🔄 Force migrating quote $oldNumber -> $currentQuoteNum');
        
        await db.update(
          'quotes',
          {'quote_number': currentQuoteNum, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [quoteId],
        );
        
        // Queue for sync
        await _dbHelper.addToSyncQueue(
          tableName: 'quotes',
          operation: 'update',
          recordId: quoteId,
          data: {'quote_number': currentQuoteNum, 'updated_at': now},
        );
        
        currentQuoteNum = incrementAlphanumericQuoteNumber(currentQuoteNum);
      }
      _log('✅ Quote force renumbering complete.');
    } catch (e) {
      _log('❌ Error force renumbering quotes: $e');
      rethrow;
    }

    // 2. Force Renumber Invoices
    try {
      final invoiceRegex = RegExp(r'^QPN\d{5}$');
      
      // Get starting invoice number from preferences
      String startInvoiceNum = 'QPN00001';
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedStart = prefs.getString('start_invoice_number')?.trim();
        if (savedStart != null && invoiceRegex.hasMatch(savedStart)) {
          startInvoiceNum = savedStart;
        }
      } catch (_) {}

      // Get all invoices sorted by created_at
      final invoicesList = await db.query(
        'invoices',
        orderBy: 'created_at ASC, id ASC',
      );

      _log('⚠️ Starting invoice force renumbering for ${invoicesList.length} records...');
      
      // Step 1: Move all to temporary format to prevent UNIQUE constraints failures
      for (int i = 0; i < invoicesList.length; i++) {
        final invoiceId = invoicesList[i]['id'] as String;
        final tempNumber = 'TEMP-I-${invoiceId.substring(0, 8)}-$i';
        await db.update(
          'invoices',
          {'invoice_number': tempNumber, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [invoiceId],
        );
      }

      // Step 2: Assign final sequential numbers
      String currentInvoiceNum = startInvoiceNum;
      for (int i = 0; i < invoicesList.length; i++) {
        final invoiceId = invoicesList[i]['id'] as String;
        final oldNumber = invoicesList[i]['invoice_number'] as String;
        
        _log('🔄 Force migrating invoice $oldNumber -> $currentInvoiceNum');
        
        await db.update(
          'invoices',
          {'invoice_number': currentInvoiceNum, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [invoiceId],
        );
        
        // Queue for sync
        await _dbHelper.addToSyncQueue(
          tableName: 'invoices',
          operation: 'update',
          recordId: invoiceId,
          data: {'invoice_number': currentInvoiceNum, 'updated_at': now},
        );
        
        currentInvoiceNum = incrementInvoiceNumber(currentInvoiceNum);
      }
      _log('✅ Invoice force renumbering complete.');
    } catch (e) {
      _log('❌ Error force renumbering invoices: $e');
      rethrow;
    }

    // Push changes immediately
    if (await isOnline) {
      await _syncPendingDataInternal();
    }
  }

  Future<void> migrateOldNumberingFormats() async {
    _log('🔄 Checking for old quote/invoice numbering formats to migrate...');
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    // 1. Migrate Quotes
    try {
      final quoteRegex = RegExp(r'^\d{3}[A-Z]$');
      
      // Get starting quote number from preferences
      String startQuoteNum = '010A';
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedStart = prefs.getString('start_quote_number')?.trim();
        if (savedStart != null && quoteRegex.hasMatch(savedStart)) {
          startQuoteNum = savedStart;
        }
      } catch (_) {}

      // Get all quotes sorted by created_at
      final quotesList = await db.query(
        'quotes',
        orderBy: 'created_at ASC, id ASC',
      );

      // Check if there are any quotes that do not match the new format
      bool needsQuoteMigration = quotesList.any((q) {
        final qNum = q['quote_number'] as String?;
        return qNum == null || !quoteRegex.hasMatch(qNum);
      });

      if (needsQuoteMigration) {
        _log('⚠️ Found old-format quotes. Starting quote migration...');
        
        // Step 1: Move all to temporary format to prevent UNIQUE constraints failures
        for (int i = 0; i < quotesList.length; i++) {
          final quoteId = quotesList[i]['id'] as String;
          final tempNumber = 'TEMP-Q-${quoteId.substring(0, 8)}-$i';
          await db.update(
            'quotes',
            {'quote_number': tempNumber, 'updated_at': now},
            where: 'id = ?',
            whereArgs: [quoteId],
          );
        }

        // Step 2: Assign final sequential numbers
        String currentQuoteNum = startQuoteNum;
        for (int i = 0; i < quotesList.length; i++) {
          final quoteId = quotesList[i]['id'] as String;
          final oldNumber = quotesList[i]['quote_number'] as String;
          
          _log('🔄 Migrating quote $oldNumber -> $currentQuoteNum');
          
          await db.update(
            'quotes',
            {'quote_number': currentQuoteNum, 'updated_at': now},
            where: 'id = ?',
            whereArgs: [quoteId],
          );
          
          // Queue for sync
          await _dbHelper.addToSyncQueue(
            tableName: 'quotes',
            operation: 'update',
            recordId: quoteId,
            data: {'quote_number': currentQuoteNum, 'updated_at': now},
          );
          
          currentQuoteNum = incrementAlphanumericQuoteNumber(currentQuoteNum);
        }
        _log('✅ Quote numbering migration complete.');
      } else {
        _log('✅ All quotes already match the new format.');
      }
    } catch (e) {
      _log('❌ Error migrating quotes: $e');
    }

    // 2. Migrate Invoices
    try {
      final invoiceRegex = RegExp(r'^QPN\d{5}$');
      
      // Get starting invoice number from preferences
      String startInvoiceNum = 'QPN00001';
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedStart = prefs.getString('start_invoice_number')?.trim();
        if (savedStart != null && invoiceRegex.hasMatch(savedStart)) {
          startInvoiceNum = savedStart;
        }
      } catch (_) {}

      // Get all invoices sorted by created_at
      final invoicesList = await db.query(
        'invoices',
        orderBy: 'created_at ASC, id ASC',
      );

      // Check if there are any invoices that do not match the new format
      bool needsInvoiceMigration = invoicesList.any((i) {
        final iNum = i['invoice_number'] as String?;
        return iNum == null || !invoiceRegex.hasMatch(iNum);
      });

      if (needsInvoiceMigration) {
        _log('⚠️ Found old-format invoices. Starting invoice migration...');
        
        // Step 1: Move all to temporary format to prevent UNIQUE constraints failures
        for (int i = 0; i < invoicesList.length; i++) {
          final invoiceId = invoicesList[i]['id'] as String;
          final tempNumber = 'TEMP-I-${invoiceId.substring(0, 8)}-$i';
          await db.update(
            'invoices',
            {'invoice_number': tempNumber, 'updated_at': now},
            where: 'id = ?',
            whereArgs: [invoiceId],
          );
        }

        // Step 2: Assign final sequential numbers
        String currentInvoiceNum = startInvoiceNum;
        for (int i = 0; i < invoicesList.length; i++) {
          final invoiceId = invoicesList[i]['id'] as String;
          final oldNumber = invoicesList[i]['invoice_number'] as String;
          
          _log('🔄 Migrating invoice $oldNumber -> $currentInvoiceNum');
          
          await db.update(
            'invoices',
            {'invoice_number': currentInvoiceNum, 'updated_at': now},
            where: 'id = ?',
            whereArgs: [invoiceId],
          );
          
          // Queue for sync
          await _dbHelper.addToSyncQueue(
            tableName: 'invoices',
            operation: 'update',
            recordId: invoiceId,
            data: {'invoice_number': currentInvoiceNum, 'updated_at': now},
          );
          
          currentInvoiceNum = incrementInvoiceNumber(currentInvoiceNum);
        }
        _log('✅ Invoice numbering migration complete.');
      } else {
        _log('✅ All invoices already match the new format.');
      }
      await migrateProductCodesToIncremental();
    } catch (e) {
      _log('❌ Error migrating invoices: $e');
    }
  }

  // ============================================
  // FIX DUPLICATE SKUS
  // ============================================

  Future<void> _fixDuplicateSkus() async {
    _log('🔧 Fixing duplicate SKUs...');

    final db = await _dbHelper.database;

    try {
      final duplicates = await db.rawQuery('''
        SELECT sku, COUNT(*) as count, GROUP_CONCAT(id) as ids
        FROM products
        WHERE sku IS NOT NULL AND sku != ''
        GROUP BY sku
        HAVING COUNT(*) > 1
      ''');

      if (duplicates.isEmpty) {
        _log('✅ No duplicate SKUs found');
        return;
      }

      for (var row in duplicates) {
        final sku = row['sku'] as String;
        final ids = (row['ids'] as String).split(',');
        _log('📊 Found ${ids.length} products with SKU: $sku');

        for (int i = 1; i < ids.length; i++) {
          final id = ids[i];
          final productResult = await db.query(
            'products',
            where: 'id = ?',
            whereArgs: [id],
          );

          if (productResult.isNotEmpty) {
            final name = productResult.first['name'] as String? ?? 'Product';
            final newSku = await _generateSku(name);
            await db.update(
              'products',
              {'sku': newSku},
              where: 'id = ?',
              whereArgs: [id],
            );
            _log('✅ Updated product "$name" with new SKU: $newSku');
          }
        }
      }

      _log('✅ Fixed duplicate SKUs');
    } catch (e) {
      _log('❌ Error fixing duplicate SKUs: $e');
    }
  }

  // ============================================
  // PRIVATE HELPER METHODS
  // ============================================

  Future<void> _saveCustomerWithCheck(Customer customer) async {
    try {
      final existing = await _dbHelper.getCustomer(customer.id);
      if (existing != null) {
        await _dbHelper.update(
          'customers',
          customer.toJson(),
          where: 'id = ?',
          whereArgs: [customer.id],
        );
        _log('✅ Updated customer: ${customer.name}');
      } else {
        await _dbHelper.insert('customers', customer.toJson());
        _log('✅ Inserted customer: ${customer.name}');
      }
    } catch (e) {
      _log('Error saving customer: $e');
    }
  }

  Future<void> _verifyUserExists(String? userId, {String? context}) async {
    if (userId == null || userId.isEmpty) {
      _log('⚠️ Empty user ID provided${context != null ? " ($context)" : ""}');
      return;
    }

    final exists = await _dbHelper.userExists(userId);
    if (exists > 0) {
      _log('✅ User $userId exists in local DB');
      return;
    }

    _log(
      '⚠️ User $userId does not exist! Creating placeholder...${context != null ? " (Context: $context)" : ""}',
    );

    await _dbHelper.ensureUserExists(userId, name: context);
  }

  Future<void> _saveProductWithCheck(Product product) async {
    try {
      final existing = await _dbHelper.getProduct(product.id);
      final safeJson = _buildSafeProductData(
        product.toJson(),
        product.sku ?? await _generateSku(product.name),
      );

      if (existing != null) {
        final skuConflict = await _dbHelper.query(
          'products',
          where: 'sku = ? AND id != ?',
          whereArgs: [safeJson['sku'], product.id],
        );
        if (skuConflict.isNotEmpty) {
          final newSku = await _generateSku(product.name);
          safeJson['sku'] = newSku;
        }
        await _dbHelper.update(
          'products',
          safeJson,
          where: 'id = ?',
          whereArgs: [product.id],
        );
        _log('✅ Updated product: ${product.name}');
      } else {
        final skuExists = await _dbHelper.query(
          'products',
          where: 'sku = ?',
          whereArgs: [safeJson['sku']],
        );
        if (skuExists.isNotEmpty) {
          final newSku = await _generateSku(product.name);
          safeJson['sku'] = newSku;
        }
        await _dbHelper.insert('products', safeJson);
        _log('✅ Inserted product: ${product.name}');
      }
    } catch (e) {
      _log('Error saving product: $e');
    }
  }

  Future<void> _saveQuoteWithCheck(Quote quote) async {
    try {
      // First, ensure the customer exists using DatabaseHelper
      await _verifyCustomerExists(
        quote.customerId,
        context: 'Quote ${quote.quoteNumber}',
      );
      await _verifyUserExists(
        quote.userId,
        context: 'Quote ${quote.quoteNumber}',
      );

      final quoteJson = quote.toMap();
      quoteJson.removeWhere((key, value) => value == null);

      final existing = await _dbHelper.getQuote(quote.id);

      if (existing != null) {
        await _dbHelper.update(
          'quotes',
          quoteJson,
          where: 'id = ?',
          whereArgs: [quote.id],
        );
        _log('✅ Updated quote: ${quote.quoteNumber}');
      } else {
        await _dbHelper.insert('quotes', quoteJson);
        _log('✅ Inserted quote: ${quote.quoteNumber}');
      }
    } catch (e) {
      _log('❌ Error saving quote: $e');
      // Try with minimal data
      try {
        // Ensure customer exists one more time
        await _verifyCustomerExists(
          quote.customerId,
          context: 'Quote ${quote.quoteNumber}',
        );
        await _verifyUserExists(
          quote.userId,
          context: 'Quote ${quote.quoteNumber}',
        );

        // Try with just the essential fields
        final minimalQuoteJson = {
          'id': quote.id,
          'quote_number': quote.quoteNumber,
          'customer_id': quote.customerId,
          'user_id': quote.userId,
          'status': quote.status,
          'subtotal': quote.subtotal,
          'tax': quote.tax,
          'total': quote.total,
          'discount': quote.discount,
          'grand_total': quote.grandTotal,
          'validity_days': quote.validityDays,
          'created_at': quote.createdAt?.toIso8601String(),
          'updated_at': quote.updatedAt?.toIso8601String(),
          'expiry_date': quote.expiryDate?.toIso8601String(),
        };

        final existing = await _dbHelper.getQuote(quote.id);
        if (existing != null) {
          await _dbHelper.update(
            'quotes',
            minimalQuoteJson,
            where: 'id = ?',
            whereArgs: [quote.id],
          );
        } else {
          await _dbHelper.insert('quotes', minimalQuoteJson);
        }
        _log('✅ Saved quote with minimal data: ${quote.quoteNumber}');
      } catch (e2) {
        _log('❌ Failed to save quote: ${quote.quoteNumber} - $e2');
      }
    }
  }

  Future<void> _saveQuoteItemWithCheck(QuoteItem item) async {
    try {
      final existing = await _dbHelper.query(
        'quote_items',
        where: 'id = ?',
        whereArgs: [item.id],
      );
      if (existing.isNotEmpty) {
        await _dbHelper.update(
          'quote_items',
          item.toJson(),
          where: 'id = ?',
          whereArgs: [item.id],
        );
      } else {
        await _dbHelper.insert('quote_items', item.toJson());
      }
    } catch (e) {
      _log('Error saving quote item: $e');
    }
  }

  Future<void> _saveInvoiceWithCheck(Invoice invoice) async {
    try {
      // Ensure customer exists
      await _verifyCustomerExists(
        invoice.customerId,
        context: 'Invoice ${invoice.invoiceNumber}',
      );

      if (invoice.quoteId.isNotEmpty) {
        await _ensureQuoteExists(invoice.quoteId);
      }

      final existing = await _dbHelper.getInvoice(invoice.id);
      final invoiceJson = invoice.toMap();
      invoiceJson.removeWhere((key, value) => value == null);

      if (existing != null) {
        await _dbHelper.update(
          'invoices',
          invoiceJson,
          where: 'id = ?',
          whereArgs: [invoice.id],
        );
        _log('✅ Updated invoice: ${invoice.invoiceNumber}');
      } else {
        await _dbHelper.insert('invoices', invoiceJson);
        _log('✅ Inserted invoice: ${invoice.invoiceNumber}');
      }
    } catch (e) {
      _log('Error saving invoice: $e');
      try {
        await _verifyCustomerExists(
          invoice.customerId,
          context: 'Invoice ${invoice.invoiceNumber}',
        );

        final minimalInvoiceJson = {
          'id': invoice.id,
          'invoice_number': invoice.invoiceNumber,
          'quote_id': invoice.quoteId,
          'customer_id': invoice.customerId,
          'total': invoice.total,
          'subtotal': invoice.subtotal,
          'tax': invoice.tax,
          'discount': invoice.discount,
          'amount_paid': invoice.amountPaid,
          'balance_due': invoice.balanceDue,
          'payment_status': invoice.paymentStatus,
          'due_date': invoice.dueDate?.toIso8601String(),
          'issued_date': invoice.issuedDate?.toIso8601String(),
          'created_at': invoice.createdAt?.toIso8601String(),
          'updated_at': invoice.updatedAt?.toIso8601String(),
        };

        final existing = await _dbHelper.getInvoice(invoice.id);
        if (existing != null) {
          await _dbHelper.update(
            'invoices',
            minimalInvoiceJson,
            where: 'id = ?',
            whereArgs: [invoice.id],
          );
        } else {
          await _dbHelper.insert('invoices', minimalInvoiceJson);
        }
        _log('✅ Saved invoice with minimal data: ${invoice.invoiceNumber}');
      } catch (e2) {
        _log('❌ Failed to save invoice: ${invoice.invoiceNumber} - $e2');
      }
    }
  }

  Future<void> _ensureQuoteExists(String quoteId) async {
    if (quoteId.isEmpty) return;
    final localQuote = await _dbHelper.getQuote(quoteId);
    if (localQuote != null) return;

    if (await isOnline) {
      try {
        final response = await _supabase.client
            .from(SupabaseService.quotesTable)
            .select()
            .eq('id', quoteId)
            .maybeSingle();

        if (response != null) {
          final quote = Quote.fromJson(response);
          await _verifyCustomerExists(
            quote.customerId,
            context: 'Quote ${quote.quoteNumber}',
          );
          await _saveQuoteWithCheck(quote);
        }
      } catch (e) {
        _log('Could not fetch quote from Supabase: $e');
      }
    }
  }

  String incrementAlphanumericQuoteNumber(String quoteNumber) {
    if (quoteNumber.length != 4) return '010A';
    final numericPartStr = quoteNumber.substring(0, 3);
    final letterPartStr = quoteNumber.substring(3, 4);
    
    int? numeric = int.tryParse(numericPartStr);
    if (numeric == null) return '010A';
    
    int letterCode = letterPartStr.codeUnitAt(0);
    if (letterCode < 65 || letterCode > 90) return '010A'; // 'A' is 65, 'Z' is 90
    
    if (letterCode == 90) { // 'Z'
      numeric += 1;
      letterCode = 65; // Reset to 'A'
    } else {
      letterCode += 1;
    }
    
    final nextNumericPart = numeric.toString().padLeft(3, '0');
    final nextLetterPart = String.fromCharCode(letterCode);
    return '$nextNumericPart$nextLetterPart';
  }

  Future<String> generateQuoteNumber() async {
    String highestQuoteNum = '';
    final regex = RegExp(r'^\d{3}[A-Z]$');
    
    String startQuoteNum = '010A';
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStart = prefs.getString('start_quote_number')?.trim();
      if (savedStart != null && regex.hasMatch(savedStart)) {
        startQuoteNum = savedStart;
      }
    } catch (_) {
      // Ignore
    }
    
    try {
      final maps = await _dbHelper.query(
        'quotes',
        columns: ['quote_number'],
      );
      
      for (var row in maps) {
        final quoteNum = row['quote_number'] as String?;
        if (quoteNum != null && regex.hasMatch(quoteNum)) {
          if (highestQuoteNum.isEmpty || quoteNum.compareTo(highestQuoteNum) > 0) {
            highestQuoteNum = quoteNum;
          }
        }
      }
      
      if (await isOnline) {
        try {
          final response = await _supabase.client
              .from(SupabaseService.quotesTable)
              .select('quote_number');
              
          for (var row in response) {
            final quoteNum = row['quote_number']?.toString() ?? '';
            if (regex.hasMatch(quoteNum)) {
              if (highestQuoteNum.isEmpty || quoteNum.compareTo(highestQuoteNum) > 0) {
                highestQuoteNum = quoteNum;
              }
            }
          }
        } catch (e) {
          _log('⚠️ Error querying Supabase for max quote number: $e');
        }
      }
    } catch (e) {
      _log('⚠️ Error generating quote number: $e');
    }
    
    if (highestQuoteNum.isEmpty || highestQuoteNum.compareTo(startQuoteNum) < 0) {
      return startQuoteNum;
    }
    return incrementAlphanumericQuoteNumber(highestQuoteNum);
  }

  String incrementInvoiceNumber(String invoiceNumber) {
    if (invoiceNumber.length != 8 || !invoiceNumber.startsWith('QPN')) return 'QPN00001';
    final numericPartStr = invoiceNumber.substring(3);
    final number = int.tryParse(numericPartStr);
    if (number == null) return 'QPN00001';
    final nextNumber = number + 1;
    return 'QPN${nextNumber.toString().padLeft(5, '0')}';
  }

  Future<String> generateInvoiceNumber() async {
    String highestInvoiceNum = '';
    final regex = RegExp(r'^QPN\d{5}$');
    
    String startInvoiceNum = 'QPN00001';
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStart = prefs.getString('start_invoice_number')?.trim();
      if (savedStart != null && regex.hasMatch(savedStart)) {
        startInvoiceNum = savedStart;
      }
    } catch (_) {
      // Ignore
    }
    
    try {
      final maps = await _dbHelper.query(
        'invoices',
        columns: ['invoice_number'],
      );
      
      for (var row in maps) {
        final invoiceNum = row['invoice_number'] as String?;
        if (invoiceNum != null && regex.hasMatch(invoiceNum)) {
          if (highestInvoiceNum.isEmpty || invoiceNum.compareTo(highestInvoiceNum) > 0) {
            highestInvoiceNum = invoiceNum;
          }
        }
      }
      
      if (await isOnline) {
        try {
          final response = await _supabase.client
              .from(SupabaseService.invoicesTable)
              .select('invoice_number');
              
          for (var row in response) {
            final invoiceNum = row['invoice_number']?.toString() ?? '';
            if (regex.hasMatch(invoiceNum)) {
              if (highestInvoiceNum.isEmpty || invoiceNum.compareTo(highestInvoiceNum) > 0) {
                highestInvoiceNum = invoiceNum;
              }
            }
          }
        } catch (e) {
          _log('⚠️ Error querying Supabase for max invoice number: $e');
        }
      }
    } catch (e) {
      _log('⚠️ Error generating invoice number: $e');
    }
    
    if (highestInvoiceNum.isEmpty || highestInvoiceNum.compareTo(startInvoiceNum) < 0) {
      return startInvoiceNum;
    }
    return incrementInvoiceNumber(highestInvoiceNum);
  }

  Future<String> generateNextProductCode() async {
    try {
      final maps = await _dbHelper.query(
        'products',
        columns: ['sku'],
      );

      int maxNumber = 0;
      final numericRegex = RegExp(r'^\d+$');

      for (var row in maps) {
        final sku = row['sku'] as String?;
        if (sku != null && numericRegex.hasMatch(sku)) {
          final number = int.tryParse(sku);
          if (number != null && number > maxNumber) {
            maxNumber = number;
          }
        }
      }

      if (await isOnline) {
        try {
          final supabaseResponse = await _supabase.client
              .from(SupabaseService.productsTable)
              .select('sku');

          for (var row in supabaseResponse) {
            final sku = row['sku']?.toString() ?? '';
            if (numericRegex.hasMatch(sku)) {
              final number = int.tryParse(sku);
              if (number != null && number > maxNumber) {
                maxNumber = number;
              }
            }
          }
        } catch (_) {}
      }

      final nextNumber = maxNumber + 1;
      return nextNumber.toString().padLeft(4, '0');
    } catch (e) {
      _log('⚠️ Error generating product code: $e');
      return '0001';
    }
  }

  Future<String> _generateSku(String name) async {
    return await generateNextProductCode();
  }

  Future<void> migrateProductCodesToIncremental() async {
    try {
      final db = await _dbHelper.database;

      final productsList = await db.query(
        'products',
        orderBy: 'created_at ASC, id ASC',
      );

      if (productsList.isEmpty) return;

      bool needsMigration = productsList.asMap().entries.any((entry) {
        final index = entry.key + 1;
        final sku = entry.value['sku'] as String?;
        final expectedSku = index.toString().padLeft(4, '0');
        return sku != expectedSku;
      });

      if (!needsMigration) {
        return;
      }

      _log('🔄 Migrating product codes to incremental 4-digit format...');
      final now = DateTime.now().toIso8601String();

      // Step 1: Assign temp SKUs to avoid unique constraints
      for (int i = 0; i < productsList.length; i++) {
        final id = productsList[i]['id'] as String;
        await db.update(
          'products',
          {'sku': 'TEMP-P-$i', 'updated_at': now},
          where: 'id = ?',
          whereArgs: [id],
        );
      }

      // Step 2: Assign final sequential numbers
      for (int i = 0; i < productsList.length; i++) {
        final id = productsList[i]['id'] as String;
        final newSku = (i + 1).toString().padLeft(4, '0');

        await db.update(
          'products',
          {'sku': newSku, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [id],
        );

        if (await isOnline && _isValidUuid(id)) {
          try {
            await _supabase.client
                .from(SupabaseService.productsTable)
                .update({'sku': newSku, 'updated_at': now})
                .eq('id', id);
          } catch (e) {
            await _dbHelper.addToSyncQueue(
              tableName: 'products',
              operation: 'update',
              recordId: id,
              data: {'sku': newSku, 'updated_at': now},
            );
          }
        } else {
          await _dbHelper.addToSyncQueue(
            tableName: 'products',
            operation: 'update',
            recordId: id,
            data: {'sku': newSku, 'updated_at': now},
          );
        }
      }
      _log('✅ Product code migration complete.');
    } catch (e) {
      _log('❌ Error migrating product codes: $e');
    }
  }

  Map<String, dynamic> _buildSafeProductData(
    Map<String, dynamic> data,
    String sku,
  ) {
    final safeData = <String, dynamic>{
      'id': data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'name': data['name'] ?? '',
      'category': data['category'] ?? '',
      'unit_price': data['unit_price']?.toDouble() ?? 0,
      'quantity': data['quantity']?.toInt() ?? 0,
      'min_stock': data['min_stock']?.toInt() ?? 5,
      'sku': sku,
      'created_at': data['created_at'] ?? DateTime.now().toIso8601String(),
      'updated_at': data['updated_at'] ?? DateTime.now().toIso8601String(),
    };

    final optionalFields = {
      'description': data['description'],
      'subcategory': data['subcategory'],
      'barcode': data['barcode'],
      'cost_price': data['cost_price']?.toDouble(),
      'max_stock': data['max_stock']?.toInt(),
      'unit': data['unit'],
      'weight': data['weight']?.toDouble(),
      'width': data['width']?.toDouble(),
      'height': data['height']?.toDouble(),
      'length': data['length']?.toDouble(),
      'brand': data['brand'],
      'supplier': data['supplier'],
      'location': data['location'],
      'is_active': data['is_active'] ?? true,
      'is_taxable': data['is_taxable'] ?? true,
      'tax_rate': data['tax_rate']?.toDouble() ?? 16,
      'image_url': data['image_url'],
      'notes': data['notes'],
    };

    for (var entry in optionalFields.entries) {
      if (entry.value != null) {
        safeData[entry.key] = entry.value;
      }
    }

    return safeData;
  }

  // ============================================
  // SYNC STATUS
  // ============================================

  Future<int> getPendingSyncCount() async {
    return await _dbHelper.getPendingSyncCount();
  }

  Future<List<Map<String, dynamic>>> getFailedSyncItems() async {
    return await _dbHelper.getFailedSyncItems();
  }

  Future<void> resetFailedSyncItem(int id) async {
    await _dbHelper.resetSyncItem(id);
  }

  Future<void> syncNow() async {
    if (_isSyncing) {
      _log('⚠️ Sync already in progress, skipping syncNow...');
      return;
    }

    if (await isOnline) {
      _log('🔄 Manual sync triggered...');
      await fullSync();
      _log('✅ Manual sync completed');
    } else {
      _log('📴 Cannot sync - offline');
      throw Exception('Cannot sync while offline');
    }
  }

  Future<bool> get isSynced async {
    final pendingCount = await getPendingSyncCount();
    return pendingCount == 0;
  }

  Future<void> resetSystemForProduction() async {
    _log('🧹 Wiping development data for Production Reset...');
    await _dbHelper.resetForProduction();

    if (await isOnline && _supabase.client.auth.currentUser != null) {
      try {
        _log('☁️ Cleaning Supabase cloud tables for Production Reset...');
        await _supabase.client.from('quote_items').delete().neq('id', '00000000-0000-0000-0000-000000000000');
        await _supabase.client.from('invoices').delete().neq('id', '00000000-0000-0000-0000-000000000000');
        await _supabase.client.from('quotes').delete().neq('id', '00000000-0000-0000-0000-000000000000');
        await _supabase.client.from('photos').delete().neq('id', '00000000-0000-0000-0000-000000000000');
        await _supabase.client.from('sites').delete().neq('id', '00000000-0000-0000-0000-000000000000');
        await _supabase.client.from('products').delete().neq('id', '00000000-0000-0000-0000-000000000000');
        await _supabase.client.from('customers').delete().neq('id', '00000000-0000-0000-0000-000000000000');
        _log('✅ Supabase cloud tables reset successfully.');
      } catch (e) {
        _log('⚠️ Warning cleaning cloud data: $e');
      }
    }
  }
}
