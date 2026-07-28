// lib/services/log_service.dart
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/system_log.dart';
import '../models/user.dart';
import 'database_helper.dart';

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();

  Future<void> logEvent({
    User? currentUser,
    required String action,
    required String description,
    String? details,
    String status = 'info',
  }) async {
    try {
      final id = _uuid.v4();
      final log = SystemLog(
        id: id,
        userId: currentUser?.id,
        userName: currentUser?.name ?? 'System',
        userRole: currentUser?.role ?? 'system',
        action: action,
        description: description,
        details: details,
        timestamp: DateTime.now(),
        status: status,
      );

      await _dbHelper.saveSystemLog(log.toMap());
      if (kDebugMode) {
        print('[LOG][$status] ${currentUser?.name ?? "System"}: $action - $description');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving log event: $e');
      }
    }
  }

  Future<List<SystemLog>> fetchLogs({
    String? searchQuery,
    String? status,
    int limit = 100,
  }) async {
    try {
      final rows = await _dbHelper.getSystemLogs(
        searchQuery: searchQuery,
        status: status,
        limit: limit,
      );
      return rows.map((r) => SystemLog.fromMap(r)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching logs: $e');
      }
      return [];
    }
  }

  Future<void> clearLogs() async {
    await _dbHelper.clearSystemLogs();
  }
}
