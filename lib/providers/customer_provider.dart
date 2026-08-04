import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/customer.dart';
import '../services/database_service.dart';
import '../services/log_service.dart';

class CustomerProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  StreamSubscription<void>? _syncSubscription;

  CustomerProvider() {
    _syncSubscription = _databaseService.onSyncCompleteStream.listen((_) {
      refreshFromLocal();
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  Future<void> refreshFromLocal() async {
    try {
      final updated = await _databaseService.getCustomersOnlyLocal();
      _customers = updated;
      _applySearchFilter();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to refresh customers from local database: $e';
      notifyListeners();
    }
  }

  List<Customer> _customers = [];
  List<Customer> _filteredCustomers = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;
  String _searchQuery = '';

  // ============================================
  // GETTERS
  // ============================================

  List<Customer> get customers =>
      _searchQuery.isNotEmpty ? _filteredCustomers : _customers;

  List<Customer> get allCustomers => _customers;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;

  int get totalCount => _customers.length;
  int get filteredCount => _filteredCustomers.isNotEmpty
      ? _filteredCustomers.length
      : _customers.length;

  bool get hasCustomers => _customers.isNotEmpty;
  bool get hasFilteredCustomers => _filteredCustomers.isNotEmpty;

  // ============================================
  // LOAD METHODS
  // ============================================

  Future<void> loadCustomers({bool forceRefresh = false}) async {
    if (!forceRefresh && _isInitialized && _customers.isNotEmpty) {
      return;
    }

    _setLoading(true);
    _clearError();

    try {
      _customers = await _databaseService.getCustomers(
        onSyncComplete: () async {
          final updated = await _databaseService.getCustomersOnlyLocal();
          _customers = updated;
          _applySearchFilter();
          notifyListeners();
        },
      );
      _applySearchFilter();
      _isInitialized = true;
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load customers: $e');
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> refreshCustomers() async {
    await loadCustomers(forceRefresh: true);
  }

  // ============================================
  // SEARCH METHODS
  // ============================================

  void searchCustomers(String query) {
    _searchQuery = query.trim();
    _applySearchFilter();
    notifyListeners();
  }

  void clearSearch() {
    if (_searchQuery.isNotEmpty) {
      _searchQuery = '';
      _filteredCustomers = [];
      notifyListeners();
    }
  }

  void _applySearchFilter() {
    if (_searchQuery.isEmpty) {
      _filteredCustomers = [];
      return;
    }

    final searchTerm = _searchQuery.toLowerCase();
    _filteredCustomers = _customers.where((customer) {
      return customer.name.toLowerCase().contains(searchTerm) ||
          (customer.phone?.toLowerCase().contains(searchTerm) ?? false) ||
          (customer.email?.toLowerCase().contains(searchTerm) ?? false) ||
          (customer.address?.toLowerCase().contains(searchTerm) ?? false) ||
          (customer.siteLocation?.toLowerCase().contains(searchTerm) ?? false) ||
          (customer.remarks?.toLowerCase().contains(searchTerm) ?? false);
    }).toList();
  }

  List<Customer> searchCustomersStatic(String query) {
    if (query.isEmpty) return _customers;

    final searchTerm = query.toLowerCase().trim();
    return _customers.where((customer) {
      return customer.name.toLowerCase().contains(searchTerm) ||
          (customer.phone?.toLowerCase().contains(searchTerm) ?? false) ||
          (customer.email?.toLowerCase().contains(searchTerm) ?? false) ||
          (customer.address?.toLowerCase().contains(searchTerm) ?? false) ||
          (customer.siteLocation?.toLowerCase().contains(searchTerm) ?? false) ||
          (customer.remarks?.toLowerCase().contains(searchTerm) ?? false);
    }).toList();
  }

  // ============================================
  // CRUD OPERATIONS
  // ============================================

  Future<Customer?> getCustomer(String id) async {
    try {
      // Check if customer exists in local list first
      final localCustomer = _customers.firstWhere(
        (c) => c.id == id,
        orElse: () => throw Exception('Customer not found locally'),
      );
      return localCustomer;
    } catch (_) {
      // Fall back to database
      try {
        return await _databaseService.getCustomer(id);
      } catch (e) {
        _setError('Failed to get customer: $e');
        notifyListeners();
        return null;
      }
    }
  }

  Future<Customer?> createCustomer({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? siteLocation,
    String? siteNotes,
    String? remarks,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      if (name.trim().isEmpty) {
        throw Exception('Customer name is required');
      }

      final data = {
        'name': name.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (address != null && address.trim().isNotEmpty)
          'address': address.trim(),
        if (siteLocation != null && siteLocation.trim().isNotEmpty)
          'site_location': siteLocation.trim(),
        if (siteNotes != null && siteNotes.trim().isNotEmpty)
          'site_notes': siteNotes.trim(),
        if (remarks != null && remarks.trim().isNotEmpty)
          'remarks': remarks.trim(),
      };

      final customer = await _databaseService.createCustomer(data);

      if (customer != null) {
        _customers.insert(0, customer);
        _applySearchFilter();
        await LogService().logEvent(
          action: 'CREATE_CUSTOMER',
          description: 'Created customer ${customer.name}',
          status: 'info',
        );
        _setLoading(false);
        notifyListeners();
        return customer;
      } else {
        _setError('Failed to create customer');
        _setLoading(false);
        notifyListeners();
        return null;
      }
    } catch (e) {
      _setError('Failed to add customer: $e');
      _setLoading(false);
      notifyListeners();
      return null;
    }
  }

  Future<bool> addCustomer({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? siteLocation,
    String? siteNotes,
    String? remarks,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Validate input
      if (name.trim().isEmpty) {
        throw Exception('Customer name is required');
      }

      final data = {
        'name': name.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (address != null && address.trim().isNotEmpty)
          'address': address.trim(),
        if (siteLocation != null && siteLocation.trim().isNotEmpty)
          'site_location': siteLocation.trim(),
        if (siteNotes != null && siteNotes.trim().isNotEmpty)
          'site_notes': siteNotes.trim(),
        if (remarks != null && remarks.trim().isNotEmpty)
          'remarks': remarks.trim(),
      };

      final customer = await _databaseService.createCustomer(data);

      if (customer != null) {
        _customers.insert(0, customer);
        _applySearchFilter();
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError('Failed to create customer');
        _setLoading(false);
        notifyListeners();
        return false;
      }
    } catch (e) {
      _setError('Failed to add customer: $e');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCustomer({
    required String id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? siteLocation,
    String? siteNotes,
    String? remarks,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final data = <String, dynamic>{};

      if (name != null && name.trim().isNotEmpty) data['name'] = name.trim();
      if (phone != null) {
        data['phone'] = phone.trim().isEmpty ? null : phone.trim();
      }
      if (email != null) {
        data['email'] = email.trim().isEmpty ? null : email.trim();
      }
      if (address != null) {
        data['address'] = address.trim().isEmpty ? null : address.trim();
      }
      if (siteLocation != null) {
        data['site_location'] = siteLocation.trim().isEmpty
            ? null
            : siteLocation.trim();
      }
      if (siteNotes != null) {
        data['site_notes'] = siteNotes.trim().isEmpty ? null : siteNotes.trim();
      }
      if (remarks != null) {
        data['remarks'] = remarks.trim().isEmpty ? null : remarks.trim();
      }

      if (data.isEmpty) {
        throw Exception('No fields to update');
      }

      final updated = await _databaseService.updateCustomer(id, data);

      if (updated != null) {
        final index = _customers.indexWhere((c) => c.id == id);
        if (index != -1) {
          _customers[index] = updated;
        }
        _applySearchFilter();
        await LogService().logEvent(
          action: 'UPDATE_CUSTOMER',
          description: 'Updated customer record $id',
          status: 'info',
        );
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError('Failed to update customer');
        _setLoading(false);
        notifyListeners();
        return false;
      }
    } catch (e) {
      _setError('Failed to update customer: $e');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCustomer(String id) async {
    _setLoading(true);
    _clearError();

    try {
      final success = await _databaseService.deleteCustomer(id);

      if (success) {
        _customers.removeWhere((c) => c.id == id);
        _applySearchFilter();
        await LogService().logEvent(
          action: 'DELETE_CUSTOMER',
          description: 'Deleted customer record $id',
          status: 'warning',
        );
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError('Failed to delete customer');
        _setLoading(false);
        notifyListeners();
        return false;
      }
    } catch (e) {
      _setError('Failed to delete customer: $e');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAllCustomers() async {
    _setLoading(true);
    _clearError();

    try {
      // Delete all customers one by one
      for (final customer in _customers) {
        await _databaseService.deleteCustomer(customer.id);
      }

      _customers.clear();
      _filteredCustomers.clear();
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to delete all customers: $e');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  // ============================================
  // FILTER METHODS
  // ============================================

  List<Customer> getCustomersWithPhone() {
    return _customers.where((c) => c.hasPhone).toList();
  }

  List<Customer> getCustomersWithEmail() {
    return _customers.where((c) => c.hasEmail).toList();
  }

  List<Customer> getCustomersWithAddress() {
    return _customers.where((c) => c.hasAddress).toList();
  }

  List<Customer> getCustomersWithSiteLocation() {
    return _customers.where((c) => c.hasSiteLocation).toList();
  }

  // ============================================
  // SORTING METHODS
  // ============================================

  void sortByName({bool ascending = true}) {
    _customers.sort(
      (a, b) => ascending ? a.name.compareTo(b.name) : b.name.compareTo(a.name),
    );
    _applySearchFilter();
    notifyListeners();
  }

  void sortByDate({bool ascending = false}) {
    _customers.sort((a, b) {
      final aDate = a.createdAt ?? DateTime(1970);
      final bDate = b.createdAt ?? DateTime(1970);
      return ascending ? aDate.compareTo(bDate) : bDate.compareTo(aDate);
    });
    _applySearchFilter();
    notifyListeners();
  }

  // ============================================
  // UTILITY METHODS
  // ============================================

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearAll() {
    _customers.clear();
    _filteredCustomers.clear();
    _searchQuery = '';
    _isInitialized = false;
    _errorMessage = null;
    notifyListeners();
  }

  // ============================================
  // PRIVATE METHODS
  // ============================================

  void _setLoading(bool loading) {
    _isLoading = loading;
    if (loading) {
      _errorMessage = null;
    }
  }

  void _setError(String message) {
    _errorMessage = message;
  }

  void _clearError() {
    _errorMessage = null;
  }

  // ============================================
  // STATISTICS
  // ============================================

  Map<String, dynamic> getStatistics() {
    final withPhone = _customers.where((c) => c.hasPhone).length;
    final withEmail = _customers.where((c) => c.hasEmail).length;
    final withAddress = _customers.where((c) => c.hasAddress).length;
    final withSite = _customers.where((c) => c.hasSiteLocation).length;

    return {
      'total': _customers.length,
      'with_phone': withPhone,
      'with_email': withEmail,
      'with_address': withAddress,
      'with_site_location': withSite,
      'phone_percentage': _customers.isEmpty
          ? 0
          : (withPhone / _customers.length * 100),
      'email_percentage': _customers.isEmpty
          ? 0
          : (withEmail / _customers.length * 100),
    };
  }
}

// ============================================
// EXTENSIONS
// ============================================

extension CustomerProviderExtensions on BuildContext {
  CustomerProvider get customerProvider =>
      Provider.of<CustomerProvider>(this, listen: false);

  CustomerProvider get customerProviderWatch =>
      Provider.of<CustomerProvider>(this, listen: true);

  List<Customer> get customers => customerProvider.customers;
  bool get isLoadingCustomers => customerProvider.isLoading;
  bool get hasCustomers => customerProvider.hasCustomers;

  void loadCustomers() => customerProvider.loadCustomers();
  void searchCustomers(String query) => customerProvider.searchCustomers(query);
  void clearCustomerSearch() => customerProvider.clearSearch();
}
