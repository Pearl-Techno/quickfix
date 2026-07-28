// lib/providers/log_provider.dart
import 'package:flutter/material.dart';
import '../models/system_log.dart';
import '../models/user.dart';
import '../services/log_service.dart';

class LogProvider extends ChangeNotifier {
  final LogService _logService = LogService();

  List<SystemLog> _logs = [];
  bool _isLoading = false;
  String? _searchQuery;
  String? _selectedStatus;

  List<SystemLog> get logs => _logs;
  bool get isLoading => _isLoading;
  String? get searchQuery => _searchQuery;
  String? get selectedStatus => _selectedStatus;

  Future<void> loadLogs() async {
    _isLoading = true;
    notifyListeners();

    _logs = await _logService.fetchLogs(
      searchQuery: _searchQuery,
      status: _selectedStatus,
    );

    _isLoading = false;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    loadLogs();
  }

  void setStatusFilter(String? status) {
    _selectedStatus = status;
    loadLogs();
  }

  Future<void> logEvent({
    User? currentUser,
    required String action,
    required String description,
    String? details,
    String status = 'info',
  }) async {
    await _logService.logEvent(
      currentUser: currentUser,
      action: action,
      description: description,
      details: details,
      status: status,
    );
    await loadLogs();
  }

  Future<void> clearAllLogs() async {
    await _logService.clearLogs();
    await loadLogs();
  }
}
