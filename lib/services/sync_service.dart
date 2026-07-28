import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:quickfix/services/supabase_service.dart';

class SyncService {
  final SupabaseService _supabase = SupabaseService();
  Box? _syncBox;
  bool _isSyncing = false;
  bool _isInitialized = false;
  bool _isInitializing = false;

  // ============================================
  // INITIALIZATION
  // ============================================

  SyncService() {
    _initBox();
  }

  Future<void> _initBox() async {
    if (_isInitialized || _isInitializing) return;

    _isInitializing = true;
    try {
      _syncBox = await Hive.openBox('sync_queue');
      _isInitialized = true;
      if (kDebugMode) {
        print('✅ Sync box initialized with ${_syncBox?.length ?? 0} entries');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialize sync box: $e');
      }
      _syncBox = null;
      _isInitialized = false;
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _initBox();
    }
  }

  // ============================================
  // CONNECTIVITY
  // ============================================

  Future<bool> isConnected() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult.any(
        (result) => result != ConnectivityResult.none,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Connectivity check error: $e');
      }
      return false;
    }
  }

  Stream<ConnectivityResult> get connectivityStream {
    return Connectivity().onConnectivityChanged.map(
      (results) => results.isNotEmpty ? results.first : ConnectivityResult.none,
    );
  }

  // ============================================
  // QUEUE OPERATIONS
  // ============================================

  Future<void> addToQueue({
    required String table,
    required String operation,
    required String recordId,
    required Map<String, dynamic> data,
    int retryCount = 0,
  }) async {
    try {
      await _ensureInitialized();
      if (_syncBox == null) {
        return;
      }

      await _syncBox!.add({
        'table': table,
        'operation': operation,
        'record_id': recordId,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
        'synced': false,
        'retry_count': retryCount,
        'max_retries': 3,
      });

      if (kDebugMode) {
        print('📝 Added to sync queue: $operation on $table (ID: $recordId)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to add to queue: $e');
      }
      rethrow;
    }
  }

  Future<void> addInsertToQueue({
    required String table,
    required Map<String, dynamic> data,
  }) async {
    // Extract ID from data or generate one
    final recordId =
        data['id']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();
    await addToQueue(
      table: table,
      operation: 'insert',
      recordId: recordId,
      data: data,
    );
  }

  Future<void> addUpdateToQueue({
    required String table,
    required String recordId,
    required Map<String, dynamic> data,
  }) async {
    await addToQueue(
      table: table,
      operation: 'update',
      recordId: recordId,
      data: data,
    );
  }

  Future<void> addDeleteToQueue({
    required String table,
    required String recordId,
  }) async {
    await addToQueue(
      table: table,
      operation: 'delete',
      recordId: recordId,
      data: {},
    );
  }

  // ============================================
  // SYNC OPERATIONS
  // ============================================

  Future<void> syncAll() async {
    if (_isSyncing) {
      if (kDebugMode) {
        print('⚠️ Sync already in progress');
      }
      return;
    }

    if (!await isConnected()) {
      if (kDebugMode) {
        print('⚠️ No internet connection. Sync postponed.');
      }
      return;
    }

    _isSyncing = true;

    try {
      final pendingEntries = await _getPendingEntries();

      if (pendingEntries.isEmpty) {
        if (kDebugMode) {
          print('✅ No pending entries to sync');
        }
        return;
      }

      if (kDebugMode) {
        print('🔄 Syncing ${pendingEntries.length} entries...');
      }

      int successCount = 0;
      int failCount = 0;

      for (var entry in pendingEntries) {
        final key = entry['key'];
        final data = entry['data'];

        try {
          await _processOperation(data);
          await _markAsSynced(key);
          successCount++;

          if (kDebugMode) {
            print('✅ Synced: ${data['operation']} on ${data['table']}');
          }
        } catch (e) {
          failCount++;
          await _handleSyncError(key, data, e);
        }
      }

      if (kDebugMode) {
        print('📊 Sync completed: $successCount succeeded, $failCount failed');
      }

      // Clean up synced entries
      await clearSynced();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Sync error: $e');
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> syncSpecificTable(String table) async {
    if (!await isConnected()) return;

    try {
      final pendingEntries = (await _getPendingEntries())
          .where((entry) => entry['data']['table'] == table)
          .toList();

      if (pendingEntries.isEmpty) return;

      if (kDebugMode) {
        print('🔄 Syncing ${pendingEntries.length} entries for table: $table');
      }

      for (var entry in pendingEntries) {
        final key = entry['key'];
        final data = entry['data'];

        try {
          await _processOperation(data);
          await _markAsSynced(key);
        } catch (e) {
          await _handleSyncError(key, data, e);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Sync table error: $e');
      }
    }
  }

  // ============================================
  // PRIVATE METHODS
  // ============================================

  Future<List<Map<String, dynamic>>> _getPendingEntries() async {
    await _ensureInitialized();

    final box = _syncBox;
    if (box == null) return [];

    final entries = <Map<String, dynamic>>[];

    for (var key in box.keys) {
      final entry = box.get(key);
      if (entry != null && entry['synced'] == false) {
        entries.add({'key': key, 'data': entry});
      }
    }

    // Sort by timestamp (oldest first)
    entries.sort((a, b) {
      final aTime = a['data']['timestamp'] ?? '';
      final bTime = b['data']['timestamp'] ?? '';
      return aTime.compareTo(bTime);
    });

    return entries;
  }

  Future<void> _processOperation(Map<String, dynamic> entry) async {
    final table = entry['table'];
    final operation = entry['operation'];
    final data = entry['data'];
    final recordId = entry['record_id'];

    switch (operation) {
      case 'insert':
        await _supabase.client.from(table).insert(data);
        break;
      case 'update':
        await _supabase.client.from(table).update(data).eq('id', recordId);
        break;
      case 'delete':
        await _supabase.client.from(table).delete().eq('id', recordId);
        break;
      default:
        throw Exception('Unknown operation: $operation');
    }
  }

  Future<void> _markAsSynced(dynamic key) async {
    await _ensureInitialized();
    final box = _syncBox;
    if (box == null) return;

    final entry = box.get(key);
    if (entry != null) {
      await box.put(key, {
        ...entry,
        'synced': true,
        'synced_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> _handleSyncError(
    dynamic key,
    Map<String, dynamic> entry,
    dynamic error,
  ) async {
    final retryCount = (entry['retry_count'] ?? 0) + 1;
    final maxRetries = entry['max_retries'] ?? 3;

    if (kDebugMode) {
      print(
        '❌ Sync error for ${entry['operation']} on ${entry['table']}: $error',
      );
      print('🔄 Retry attempt $retryCount of $maxRetries');
    }

    await _ensureInitialized();
    final box = _syncBox;
    if (box == null) return;

    if (retryCount >= maxRetries) {
      // Mark as failed after max retries
      await box.put(key, {
        ...entry,
        'synced': true, // Mark as processed (failed)
        'failed': true,
        'error': error.toString(),
        'retry_count': retryCount,
      });

      if (kDebugMode) {
        debugPrint('❌ Entry failed after $maxRetries retries');
      }
    } else {
      // Update retry count and keep in queue
      await box.put(key, {...entry, 'retry_count': retryCount});
    }
  }

  // ============================================
  // CLEANUP METHODS
  // ============================================

  Future<void> clearSynced() async {
    try {
      await _ensureInitialized();
      final box = _syncBox;
      if (box == null) return;

      final keysToDelete = <dynamic>[];

      for (var key in box.keys) {
        final entry = box.get(key);
        if (entry != null && entry['synced'] == true) {
          keysToDelete.add(key);
        }
      }

      for (var key in keysToDelete) {
        await box.delete(key);
      }

      if (kDebugMode && keysToDelete.isNotEmpty) {
        debugPrint('🧹 Cleared ${keysToDelete.length} synced entries');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Clear synced error: $e');
      }
    }
  }

  Future<void> clearFailedEntries() async {
    try {
      await _ensureInitialized();
      final box = _syncBox;
      if (box == null) return;

      final keysToDelete = <dynamic>[];

      for (var key in box.keys) {
        final entry = box.get(key);
        if (entry != null && entry['failed'] == true) {
          keysToDelete.add(key);
        }
      }

      for (var key in keysToDelete) {
        await box.delete(key);
      }

      if (kDebugMode && keysToDelete.isNotEmpty) {
        debugPrint('🧹 Cleared ${keysToDelete.length} failed entries');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Clear failed entries error: $e');
      }
    }
  }

  Future<void> clearAll() async {
    try {
      await _ensureInitialized();
      final box = _syncBox;
      if (box == null) return;

      await box.clear();
      if (kDebugMode) {
        debugPrint('🧹 Cleared all sync entries');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Clear all error: $e');
      }
    }
  }

  // ============================================
  // QUERY METHODS
  // ============================================

  Future<int> getPendingCount() async {
    try {
      await _ensureInitialized();
      final box = _syncBox;
      if (box == null) return 0;

      int count = 0;
      for (var key in box.keys) {
        final entry = box.get(key);
        if (entry != null &&
            entry['synced'] == false &&
            entry['failed'] != true) {
          count++;
        }
      }
      return count;
    } catch (e) {
      return 0;
    }
  }

  Future<int> getFailedCount() async {
    try {
      await _ensureInitialized();
      final box = _syncBox;
      if (box == null) return 0;

      int count = 0;
      for (var key in box.keys) {
        final entry = box.get(key);
        if (entry != null && entry['failed'] == true) {
          count++;
        }
      }
      return count;
    } catch (e) {
      return 0;
    }
  }

  Future<int> getTotalCount() async {
    try {
      await _ensureInitialized();
      return _syncBox?.length ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<Map<String, dynamic>> getSyncStats() async {
    try {
      final total = await getTotalCount();
      final pending = await getPendingCount();
      final failed = await getFailedCount();

      return {
        'total': total,
        'pending': pending,
        'failed': failed,
        'synced': total - pending - failed,
        'is_syncing': _isSyncing,
        'is_connected': await isConnected(),
        'last_updated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'last_updated': DateTime.now().toIso8601String(),
      };
    }
  }

  // ============================================
  // LISTENERS
  // ============================================

  void listenToConnectivity({
    required VoidCallback onConnected,
    required VoidCallback onDisconnected,
  }) {
    Connectivity().onConnectivityChanged.listen((results) {
      final isConnected = results.any(
        (result) => result != ConnectivityResult.none,
      );

      if (isConnected) {
        onConnected.call();
      } else {
        onDisconnected.call();
      }
    });
  }

  // ============================================
  // DISPOSAL
  // ============================================

  Future<void> dispose() async {
    try {
      await _syncBox?.close();
      if (kDebugMode) {
        print('🔄 Sync service disposed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Dispose error: $e');
      }
    }
  }
}
