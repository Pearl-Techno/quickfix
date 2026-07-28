// lib/providers/invoice_provider.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickfix/config/constants.dart';
import 'dart:async';
import '../models/invoice.dart';
import '../models/quote_item.dart';
import '../services/database_service.dart';
import '../services/log_service.dart';
import '../utils/helpers.dart';

class InvoiceProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  StreamSubscription<void>? _syncSubscription;

  InvoiceProvider() {
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
      final updated = await _databaseService.getInvoicesOnlyLocal();
      _invoices = updated;
      _applyFilters();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to refresh invoices from local database: $e';
      notifyListeners();
    }
  }

  List<Invoice> _invoices = [];
  List<Invoice> _filteredInvoices = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedStatus = '';

  // ============================================
  // GETTERS
  // ============================================

  List<Invoice> get invoices =>
      _searchQuery.isNotEmpty || _selectedStatus.isNotEmpty
          ? _filteredInvoices
          : _invoices;

  List<Invoice> get allInvoices => _invoices;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String get selectedStatus => _selectedStatus;

  int get totalCount => _invoices.length;
  int get filteredCount => _filteredInvoices.isNotEmpty
      ? _filteredInvoices.length
      : _invoices.length;

  bool get hasInvoices => _invoices.isNotEmpty;
  bool get hasFilteredInvoices => _filteredInvoices.isNotEmpty;

  // ============================================
  // LOAD METHODS
  // ============================================

  Future<void> loadInvoices({bool forceRefresh = false}) async {
    if (!forceRefresh && _isInitialized && _invoices.isNotEmpty) {
      return;
    }

    _setLoading(true);
    _clearError();

    try {
      _invoices = await _databaseService.getInvoices(
        onSyncComplete: () async {
          final updated = await _databaseService.getInvoicesOnlyLocal();
          _invoices = updated;
          _applyFilters();
          notifyListeners();
        },
      );
      _applyFilters();
      _isInitialized = true;
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load invoices: $e');
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> refreshInvoices() async {
    await loadInvoices(forceRefresh: true);
  }

  // ============================================
  // SEARCH & FILTER
  // ============================================

  void searchInvoices(String query) {
    _searchQuery = query.trim();
    _applyFilters();
    notifyListeners();
  }

  void clearSearch() {
    if (_searchQuery.isNotEmpty) {
      _searchQuery = '';
      _applyFilters();
      notifyListeners();
    }
  }

  void filterByStatus(String status) {
    _selectedStatus = status;
    _applyFilters();
    notifyListeners();
  }

  void clearStatusFilter() {
    if (_selectedStatus.isNotEmpty) {
      _selectedStatus = '';
      _applyFilters();
      notifyListeners();
    }
  }

  void _applyFilters() {
    List<Invoice> result = List.from(_invoices);

    if (_selectedStatus.isNotEmpty) {
      result = result.where((i) => i.paymentStatus == _selectedStatus).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final searchTerm = _searchQuery.toLowerCase();
      result = result.where((invoice) {
        return invoice.invoiceNumber.toLowerCase().contains(searchTerm) ||
            (invoice.customerName?.toLowerCase().contains(searchTerm) ??
                false) ||
            invoice.displayStatus.toLowerCase().contains(searchTerm);
      }).toList();
    }

    _filteredInvoices = result;
  }

  // ============================================
  // CRUD OPERATIONS
  // ============================================

  Future<Invoice?> getInvoiceById(String id) async {
    try {
      // Try to find locally first
      final localInvoice = _invoices.firstWhere(
        (i) => i.id == id,
        orElse: () => throw Exception('Invoice not found locally'),
      );
      return localInvoice;
    } catch (_) {
      // If not found locally, fetch from database
      try {
        final invoice = await _databaseService.getInvoice(id);
        if (invoice != null) {
          // Update local list if found
          final index = _invoices.indexWhere((i) => i.id == id);
          if (index != -1) {
            _invoices[index] = invoice;
          } else {
            _invoices.add(invoice);
          }
          _applyFilters();
          notifyListeners();
        }
        return invoice;
      } catch (e) {
        _setError('Failed to get invoice: $e');
        notifyListeners();
        return null;
      }
    }
  }

  Future<Invoice?> getInvoice(String id) async {
    return await getInvoiceById(id);
  }

  Future<bool> updatePaymentStatus(
    String id,
    String status, {
    double? amountPaid,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final updated = await _databaseService.updateInvoicePayment(
        id,
        status,
        amountPaid: amountPaid,
      );

      if (updated != null) {
        final index = _invoices.indexWhere((i) => i.id == id);
        if (index != -1) {
          _invoices[index] = updated;
        } else {
          _invoices.add(updated);
        }
        _applyFilters();
        await LogService().logEvent(
          action: 'RECORD_PAYMENT',
          description: 'Updated payment status for invoice $id to $status (Amount: KSh ${amountPaid ?? 0.0})',
          status: 'info',
        );
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError('Failed to update payment status');
        _setLoading(false);
        notifyListeners();
        return false;
      }
    } catch (e) {
      _setError('Failed to update payment status: $e');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteInvoice(String id) async {
    _setLoading(true);
    _clearError();

    try {
      // Delete from database
      final success = await _databaseService.deleteInvoice(id);

      if (success) {
        _invoices.removeWhere((i) => i.id == id);
        _applyFilters();
        await LogService().logEvent(
          action: 'DELETE_INVOICE',
          description: 'Deleted invoice $id',
          status: 'warning',
        );
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError('Failed to delete invoice');
        _setLoading(false);
        notifyListeners();
        return false;
      }
    } catch (e) {
      _setError('Failed to delete invoice: $e');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  // ============================================
  // FILTER METHODS
  // ============================================

  List<Invoice> get unpaidInvoices =>
      _invoices.where((i) => i.isUnpaid).toList();

  List<Invoice> get partialInvoices =>
      _invoices.where((i) => i.isPartial).toList();

  List<Invoice> get paidInvoices => _invoices.where((i) => i.isPaid).toList();

  List<Invoice> get overdueInvoices =>
      _invoices.where((i) => i.isOverdue).toList();

  // ============================================
  // STATISTICS
  // ============================================

  Map<String, dynamic> getStatistics() {
    final total = _invoices.length;
    final unpaid = _invoices.where((i) => i.isUnpaid).length;
    final partial = _invoices.where((i) => i.isPartial).length;
    final paid = _invoices.where((i) => i.isPaid).length;
    final overdue = _invoices.where((i) => i.isOverdue).length;
    final totalAmount = _invoices.fold(0.0, (sum, i) => sum + i.total);
    final totalPaid = _invoices.fold(0.0, (sum, i) => sum + i.amountPaid);

    return {
      'total': total,
      'unpaid': unpaid,
      'partial': partial,
      'paid': paid,
      'overdue': overdue,
      'total_amount': totalAmount,
      'total_paid': totalPaid,
      'balance_due': totalAmount - totalPaid,
      'collection_rate': totalAmount > 0 ? (totalPaid / totalAmount) * 100 : 0,
    };
  }

  // ============================================
  // SORTING METHODS
  // ============================================

  void sortByNumber({bool ascending = true}) {
    _invoices.sort(
      (a, b) => ascending
          ? a.invoiceNumber.compareTo(b.invoiceNumber)
          : b.invoiceNumber.compareTo(a.invoiceNumber),
    );
    _applyFilters();
    notifyListeners();
  }

  void sortByDate({bool ascending = false}) {
    _invoices.sort((a, b) {
      final aDate = a.createdAt ?? DateTime(1970);
      final bDate = b.createdAt ?? DateTime(1970);
      return ascending ? aDate.compareTo(bDate) : bDate.compareTo(aDate);
    });
    _applyFilters();
    notifyListeners();
  }

  void sortByTotal({bool ascending = true}) {
    _invoices.sort(
      (a, b) =>
          ascending ? a.total.compareTo(b.total) : b.total.compareTo(a.total),
    );
    _applyFilters();
    notifyListeners();
  }

  void sortByStatus() {
    _invoices.sort((a, b) {
      final aPriority = Constants.invoiceStatusList.indexOf(a.paymentStatus);
      final bPriority = Constants.invoiceStatusList.indexOf(b.paymentStatus);
      return aPriority.compareTo(bPriority);
    });
    _applyFilters();
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
    _invoices.clear();
    _filteredInvoices.clear();
    _searchQuery = '';
    _selectedStatus = '';
    _isInitialized = false;
    _errorMessage = null;
    notifyListeners();
  }

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
  // SYNC STATUS
  // ============================================

  Future<int> getPendingSyncCount() async {
    return await _databaseService.getPendingSyncCount();
  }

  Future<void> syncNow() async {
    _setLoading(true);
    try {
      await _databaseService.syncNow();
      await refreshInvoices();
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to sync: $e');
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<Invoice?> createDirectInvoice({
    required String customerId,
    required String userId,
    List<QuoteItem>? items,
    String? scope,
    String? notes,
    double? discount,
    bool applyTax = true,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      double subtotal = 0;
      if (items != null) {
        for (var item in items) {
          subtotal += item.total;
        }
      }
      final tax = applyTax ? subtotal * Constants.taxRate : 0.0;
      final total = subtotal + tax;
      final grandTotal = total - (discount ?? 0);
      final placeholderQuoteId = Helpers.generateId();

      final data = {
        'quote_id': placeholderQuoteId,
        'customer_id': customerId,
        'user_id': userId,
        'subtotal': subtotal,
        'tax': tax,
        'discount': discount ?? 0.0,
        'total': grandTotal,
        'amount_paid': 0.0,
        'balance_due': grandTotal,
        'payment_status': Constants.invoiceStatusUnpaid,
        'due_date': DateTime.now().add(const Duration(days: 14)).toIso8601String(),
        'issued_date': DateTime.now().toIso8601String(),
        'scope': scope,
        'notes': notes,
        'items': items,
      };

      final invoice = await _databaseService.createDirectInvoice(data);
      if (invoice != null) {
        await loadInvoices(forceRefresh: true);
        await LogService().logEvent(
          action: 'CREATE_INVOICE',
          description: 'Created direct invoice ${invoice.invoiceNumber} for KSh ${invoice.total.toStringAsFixed(2)}',
          status: 'info',
        );
      }
      _setLoading(false);
      notifyListeners();
      return invoice;
    } catch (e) {
      _setError('Failed to create direct invoice: $e');
      _setLoading(false);
      notifyListeners();
      return null;
    }
  }

  bool get isSynced => _invoices.isNotEmpty && _filteredInvoices.isNotEmpty;
}

// ============================================
// EXTENSIONS
// ============================================

extension InvoiceProviderExtensions on BuildContext {
  InvoiceProvider get invoiceProvider =>
      Provider.of<InvoiceProvider>(this, listen: false);

  InvoiceProvider get invoiceProviderWatch =>
      Provider.of<InvoiceProvider>(this, listen: true);

  List<Invoice> get invoices => invoiceProvider.invoices;
  bool get isLoadingInvoices => invoiceProvider.isLoading;
  bool get hasInvoices => invoiceProvider.hasInvoices;
  List<Invoice> get unpaidInvoices => invoiceProvider.unpaidInvoices;
  List<Invoice> get overdueInvoices => invoiceProvider.overdueInvoices;

  void loadInvoices() => invoiceProvider.loadInvoices();
  void refreshInvoices() => invoiceProvider.refreshInvoices();
  void searchInvoices(String query) => invoiceProvider.searchInvoices(query);
  void clearInvoiceSearch() => invoiceProvider.clearSearch();
  void filterInvoicesByStatus(String status) =>
      invoiceProvider.filterByStatus(status);
  void clearInvoiceStatusFilter() => invoiceProvider.clearStatusFilter();

  Future<Invoice?> getInvoice(String id) => invoiceProvider.getInvoice(id);

  Future<bool> updateInvoicePayment(
    String id,
    String status, {
    double? amountPaid,
  }) => invoiceProvider.updatePaymentStatus(id, status, amountPaid: amountPaid);

  Future<bool> deleteInvoice(String id) => invoiceProvider.deleteInvoice(id);

  Future<void> syncInvoices() => invoiceProvider.syncNow();
  Future<int> getPendingSyncCount() => invoiceProvider.getPendingSyncCount();
}
