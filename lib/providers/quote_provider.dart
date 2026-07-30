import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/quote.dart';
import '../models/quote_item.dart';
import '../models/invoice.dart';
import '../services/database_service.dart';
import '../services/log_service.dart';
import '../config/constants.dart';

class QuoteProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  StreamSubscription<void>? _syncSubscription;

  QuoteProvider() {
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
      final updated = await _databaseService.getQuotesOnlyLocal();
      _quotes = updated;
      _applyFilters();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to refresh quotes from local database: $e';
      notifyListeners();
    }
  }

  List<Quote> _quotes = [];
  List<Quote> _filteredQuotes = [];
  Quote? _currentQuote;
  List<QuoteItem> _currentQuoteItems = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedStatus = '';

  // ============================================
  // GETTERS
  // ============================================

  List<Quote> get quotes =>
      _searchQuery.isNotEmpty || _selectedStatus.isNotEmpty
          ? _filteredQuotes
          : _quotes;

  List<Quote> get allQuotes => _quotes;
  Quote? get currentQuote => _currentQuote;
  List<QuoteItem> get currentQuoteItems => _currentQuoteItems;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String get selectedStatus => _selectedStatus;

  int get totalCount => _quotes.length;
  int get filteredCount =>
      _filteredQuotes.isNotEmpty ? _filteredQuotes.length : _quotes.length;

  bool get hasQuotes => _quotes.isNotEmpty;
  bool get hasFilteredQuotes => _filteredQuotes.isNotEmpty;

  // ============================================
  // LOAD METHODS
  // ============================================

  Future<void> loadQuotes({bool forceRefresh = false}) async {
    if (!forceRefresh && _isInitialized && _quotes.isNotEmpty) {
      return;
    }

    _setLoading(true);
    _clearError();

    try {
      _quotes = await _databaseService.getQuotes(
        onSyncComplete: () async {
          final updated = await _databaseService.getQuotesOnlyLocal();
          _quotes = updated;
          _applyFilters();
          notifyListeners();
        },
      );
      _applyFilters();
      _isInitialized = true;
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load quotes: $e');
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> refreshQuotes() async {
    await loadQuotes(forceRefresh: true);
  }

  Future<void> loadQuotesByUser(String userId) async {
    _setLoading(true);
    _clearError();

    try {
      _quotes = await _databaseService.getQuotesByUser(userId);
      _applyFilters();
      _isInitialized = true;
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load quotes: $e');
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> loadQuotesByCustomer(String customerId) async {
    _setLoading(true);
    _clearError();

    try {
      _quotes = await _databaseService.getQuotesByCustomer(customerId);
      _applyFilters();
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load quotes: $e');
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> loadQuotesByStatus(String status) async {
    _selectedStatus = status;
    _applyFilters();
    notifyListeners();
  }

  // ============================================
  // SEARCH METHODS
  // ============================================

  void searchQuotes(String query) {
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

  void clearAllFilters() {
    _searchQuery = '';
    _selectedStatus = '';
    _filteredQuotes = [];
    notifyListeners();
  }

  void _applyFilters() {
    List<Quote> result = List.from(_quotes);

    // Apply status filter
    if (_selectedStatus.isNotEmpty) {
      result = result.where((q) => q.status == _selectedStatus).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final searchTerm = _searchQuery.toLowerCase();
      result = result.where((quote) {
        return quote.quoteNumber.toLowerCase().contains(searchTerm) ||
            (quote.customerName?.toLowerCase().contains(searchTerm) ?? false) ||
            (quote.customer?.name.toLowerCase().contains(searchTerm) ??
                false) ||
            Constants.getQuoteStatusDisplay(
              quote.status,
            ).toLowerCase().contains(searchTerm) ||
            (quote.notes?.toLowerCase().contains(searchTerm) ?? false);
      }).toList();
    }

    _filteredQuotes = result;
  }

  // ============================================
  // QUOTE ITEM METHODS
  // ============================================

  Future<List<QuoteItem>> getQuoteItems(String quoteId) async {
    try {
      if (_currentQuote != null && _currentQuote!.id == quoteId) {
        return _currentQuoteItems;
      }

      final items = await _databaseService.getQuoteItems(quoteId);

      // Cache items if this is the current quote
      if (_currentQuote != null && _currentQuote!.id == quoteId) {
        _currentQuoteItems = items;
      }

      return items;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting quote items: $e');
      }
      return [];
    }
  }

  Future<QuoteItem?> createQuoteItem(Map<String, dynamic> data) async {
    _setLoading(true);
    _clearError();

    try {
      final item = await _databaseService.createQuoteItem(data);

      if (item != null) {
        // Refresh items for the quote
        final quoteId = data['quote_id'];
        if (quoteId != null) {
          _currentQuoteItems = await _databaseService.getQuoteItems(quoteId);

          // Update the quote in the list
          final quote = await _databaseService.getQuote(quoteId);
          if (quote != null) {
            final index = _quotes.indexWhere((q) => q.id == quoteId);
            if (index != -1) {
              _quotes[index] = quote.copyWith(items: _currentQuoteItems);
            }
            if (_currentQuote?.id == quoteId) {
              _currentQuote = quote.copyWith(items: _currentQuoteItems);
            }
          }
          _applyFilters();
        }

        _setLoading(false);
        notifyListeners();
        return item;
      }

      _setLoading(false);
      return null;
    } catch (e) {
      _setError('Failed to create quote item: $e');
      _setLoading(false);
      notifyListeners();
      return null;
    }
  }

  Future<QuoteItem?> updateQuoteItem(
    String itemId,
    Map<String, dynamic> data,
  ) async {
    _setLoading(true);
    _clearError();

    try {
      final item = await _databaseService.updateQuoteItem(itemId, data);

      if (item != null) {
        // Refresh items for the quote
        final quoteId = data['quote_id'] ?? item.quoteId;
        if (quoteId.isNotEmpty) {
          _currentQuoteItems = await _databaseService.getQuoteItems(quoteId);

          // Update the quote in the list
          final quote = await _databaseService.getQuote(quoteId);
          if (quote != null) {
            final index = _quotes.indexWhere((q) => q.id == quoteId);
            if (index != -1) {
              _quotes[index] = quote.copyWith(items: _currentQuoteItems);
            }
            if (_currentQuote?.id == quoteId) {
              _currentQuote = quote.copyWith(items: _currentQuoteItems);
            }
          }
          _applyFilters();
        }

        _setLoading(false);
        notifyListeners();
        return item;
      }

      _setLoading(false);
      return null;
    } catch (e) {
      _setError('Failed to update quote item: $e');
      _setLoading(false);
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteQuoteItem(String itemId) async {
    _setLoading(true);
    _clearError();

    try {
      // Get quote ID before deleting
      final item = await _databaseService.getQuoteItems(
        _currentQuote?.id ?? '',
      );
      // Find matching item safely without returning null from firstWhere
      final matching = item.where((i) => i.id == itemId).toList();
      final quoteId = matching.isNotEmpty ? matching.first.quoteId : null;

      final success = await _databaseService.deleteQuoteItem(itemId);

      if (success && quoteId != null) {
        // Refresh items for the quote
        _currentQuoteItems = await _databaseService.getQuoteItems(quoteId);

        // Update the quote in the list
        final quote = await _databaseService.getQuote(quoteId);
        if (quote != null) {
          final index = _quotes.indexWhere((q) => q.id == quoteId);
          if (index != -1) {
            _quotes[index] = quote.copyWith(items: _currentQuoteItems);
          }
          if (_currentQuote?.id == quoteId) {
            _currentQuote = quote.copyWith(items: _currentQuoteItems);
          }
        }
        _applyFilters();

        _setLoading(false);
        notifyListeners();
        return true;
      }

      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to delete quote item: $e');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteQuoteItemsByQuoteId(String quoteId) async {
    try {
      await _databaseService.deleteQuoteItemsByQuoteId(quoteId);

      if (_currentQuote?.id == quoteId) {
        _currentQuoteItems = [];
        if (_currentQuote != null) {
          _currentQuote = _currentQuote!.copyWith(items: []);
        }
      }

      // Update the quote in the list
      final index = _quotes.indexWhere((q) => q.id == quoteId);
      if (index != -1) {
        final quote = _quotes[index];
        _quotes[index] = quote.copyWith(items: []);
      }

      _applyFilters();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting quote items: $e');
      }
    }
  }

  // ============================================
  // GET SINGLE QUOTE WITH ITEMS
  // ============================================

  Future<Quote?> getQuote(String id) async {
    _setLoading(true);
    _clearError();

    try {
      // Get the quote from the database service which should include items
      final quote = await _databaseService.getQuote(id);

      if (quote != null) {
        // Update the quote in the list if it exists
        final index = _quotes.indexWhere((q) => q.id == id);
        if (index != -1) {
          _quotes[index] = quote;
          _applyFilters();
        }
        _currentQuote = quote;

        // Load items for the quote
        if (quote.items != null) {
          _currentQuoteItems = quote.items!;
        } else {
          _currentQuoteItems = await _databaseService.getQuoteItems(id);
        }

        _setLoading(false);
        notifyListeners();
        return quote;
      }

      _setLoading(false);
      notifyListeners();
      return null;
    } catch (e) {
      _setError('Failed to get quote: $e');
      _setLoading(false);
      notifyListeners();
      return null;
    }
  }

  // ============================================
  // CRUD OPERATIONS
  // ============================================

  Future<Quote?> createQuote({
    required String customerId,
    required String userId,
    List<QuoteItem>? items,
    String? scope,
    String? notes,
    String? terms,
    String? siteMeasurements,
    DateTime? expiryDate,
    DateTime? dueDate,
    int validityDays = Constants.defaultQuoteValidityDays,
    bool applyTax = false,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Validate input
      if (customerId.isEmpty) {
        throw Exception('Customer ID is required');
      }
      if (userId.isEmpty) {
        throw Exception('User ID is required');
      }

      // Calculate totals
      double subtotal = 0;
      if (items != null) {
        for (var item in items) {
          subtotal += item.total;
        }
      }

      final tax = applyTax ? subtotal * Constants.taxRate : 0.0;
      final total = subtotal + tax;
      final grandTotal = total; // No discount initially

      final data = {
        'customer_id': customerId,
        'user_id': userId,
        'status': Constants.quoteStatusDraft,
        'subtotal': subtotal,
        'tax': tax,
        'total': total,
        'grand_total': grandTotal,
        'discount': 0,
        'validity_days': validityDays,
        'scope': scope,
        'notes': notes,
        'terms': terms,
        'site_measurements': siteMeasurements,
        'expiry_date': (expiryDate ?? dueDate)?.toIso8601String(),
        'due_date': (expiryDate ?? dueDate)?.toIso8601String(),
      };

      final quote = await _databaseService.createQuote(data);

      if (quote != null && items != null) {
        // Add items to quote
        for (var item in items) {
          final itemData = {
            'quote_id': quote.id,
            'product_id': item.productId,
            'item_type': item.itemType,
            'description': item.description,
            'quantity': item.quantity,
            'unit_price': item.unitPrice,
            'total': item.total,
            'discount': item.discount,
            'tax': item.tax,
            'unit': item.unit,
            'section': item.section,
          };
          await _databaseService.createQuoteItem(itemData);
        }

        // Refresh quote with items
        _currentQuote = await _databaseService.getQuote(quote.id);
        if (_currentQuote != null && _currentQuote!.items != null) {
          _currentQuoteItems = _currentQuote!.items!;
        }
        await loadQuotes(forceRefresh: true);
        await LogService().logEvent(
          action: 'CREATE_QUOTE',
          description: 'Created quotation ${_currentQuote?.quoteNumber ?? quote.quoteNumber} for KSh ${(_currentQuote?.grandTotal ?? grandTotal).toStringAsFixed(2)}',
          status: 'info',
        );
        _setLoading(false);
        notifyListeners();
        return _currentQuote;
      }

      _setLoading(false);
      notifyListeners();
      return quote;
    } catch (e) {
      _setError('Failed to create quote: $e');
      _setLoading(false);
      notifyListeners();
      return null;
    }
  }

  Future<Quote?> updateQuote({
    required String quoteId,
    List<QuoteItem>? items,
    String? scope,
    String? notes,
    String? terms,
    String? siteMeasurements,
    DateTime? expiryDate,
    DateTime? dueDate,
    double? discount,
    bool applyTax = false,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Get existing quote
      final existingQuote = await _databaseService.getQuote(quoteId);
      if (existingQuote == null) {
        throw Exception('Quote not found');
      }

      // Calculate totals
      double subtotal = 0;
      if (items != null) {
        for (var item in items) {
          subtotal += item.total;
        }
      }

      final tax = applyTax ? subtotal * Constants.taxRate : 0.0;
      final total = subtotal + tax;
      final grandTotal = total - (discount ?? 0);

      // Update quote
      final data = {
        'subtotal': subtotal,
        'tax': tax,
        'total': total,
        'grand_total': grandTotal,
        'discount': discount,
        'scope': scope,
        'notes': notes,
        'terms': terms,
        'site_measurements': siteMeasurements,
        'expiry_date': (expiryDate ?? dueDate)?.toIso8601String(),
        'due_date': (expiryDate ?? dueDate)?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final updated = await _databaseService.updateQuote(quoteId, data);

      if (updated != null && items != null) {
        // Delete existing items
        await _databaseService.deleteQuoteItemsByQuoteId(quoteId);

        // Add new items
        for (var item in items) {
          final itemData = {
            'quote_id': quoteId,
            'product_id': item.productId,
            'item_type': item.itemType,
            'description': item.description,
            'quantity': item.quantity,
            'unit_price': item.unitPrice,
            'total': item.total,
            'discount': item.discount,
            'tax': item.tax,
            'unit': item.unit,
            'section': item.section,
          };
          await _databaseService.createQuoteItem(itemData);
        }

        // Refresh quote
        _currentQuote = await _databaseService.getQuote(quoteId);
        if (_currentQuote != null && _currentQuote!.items != null) {
          _currentQuoteItems = _currentQuote!.items!;
        }
        await loadQuotes(forceRefresh: true);
        _setLoading(false);
        notifyListeners();
        return _currentQuote;
      }

      _setLoading(false);
      notifyListeners();
      return updated;
    } catch (e) {
      _setError('Failed to update quote: $e');
      _setLoading(false);
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteQuote(String quoteId) async {
    _setLoading(true);
    _clearError();

    try {
      final success = await _databaseService.deleteQuote(quoteId);

      if (success) {
        _quotes.removeWhere((q) => q.id == quoteId);
        if (_currentQuote?.id == quoteId) {
          _currentQuote = null;
          _currentQuoteItems = [];
        }
        _applyFilters();
        await LogService().logEvent(
          action: 'DELETE_QUOTE',
          description: 'Deleted quotation $quoteId',
          status: 'warning',
        );
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError('Failed to delete quote');
        _setLoading(false);
        notifyListeners();
        return false;
      }
    } catch (e) {
      _setError('Failed to delete quote: $e');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAllQuotes() async {
    _setLoading(true);
    _clearError();

    try {
      for (final quote in _quotes) {
        await _databaseService.deleteQuote(quote.id);
      }

      _quotes.clear();
      _filteredQuotes.clear();
      _currentQuote = null;
      _currentQuoteItems = [];
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to delete all quotes: $e');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  // ============================================
  // STATUS MANAGEMENT
  // ============================================

  Future<Quote?> updateQuoteStatus(String quoteId, String status) async {
    _setLoading(true);
    _clearError();

    try {
      final updated = await _databaseService.updateQuoteStatus(quoteId, status);

      if (updated != null) {
        // Update in list
        final index = _quotes.indexWhere((q) => q.id == quoteId);
        if (index != -1) {
          _quotes[index] = updated;
        }
        if (_currentQuote?.id == quoteId) {
          _currentQuote = updated;
        }
        _applyFilters();
        _setLoading(false);
        notifyListeners();
        return updated;
      } else {
        _setError('Failed to update quote status');
        _setLoading(false);
        notifyListeners();
        return null;
      }
    } catch (e) {
      _setError('Failed to update quote status: $e');
      _setLoading(false);
      notifyListeners();
      return null;
    }
  }

  Future<Quote?> sendQuote(String quoteId) async {
    return await updateQuoteStatus(quoteId, Constants.quoteStatusSent);
  }

  Future<Quote?> approveQuote(String quoteId) async {
    return await updateQuoteStatus(quoteId, Constants.quoteStatusApproved);
  }

  Future<Quote?> rejectQuote(String quoteId) async {
    return await updateQuoteStatus(quoteId, Constants.quoteStatusRejected);
  }

  Future<Invoice?> convertQuoteToInvoice(String quoteId) async {
    _setLoading(true);
    _clearError();

    try {
      // Get quote
      final quote = await _databaseService.getQuote(quoteId);
      if (quote == null) {
        throw Exception('Quote not found');
      }

      if (!quote.canConvertToInvoice) {
        throw Exception(
          'Quote cannot be converted to invoice. Status: ${quote.displayStatus}',
        );
      }

      // Create invoice
      final invoice = await _databaseService.createInvoiceFromQuote(quoteId);

      if (invoice != null) {
        // Update quote status to converted
        await updateQuoteStatus(quoteId, Constants.quoteStatusConverted);
        await LogService().logEvent(
          action: 'CONVERT_QUOTE_TO_INVOICE',
          description: 'Converted quote ${quote.quoteNumber} to invoice ${invoice.invoiceNumber}',
          status: 'info',
        );
        _setLoading(false);
        notifyListeners();
        return invoice;
      } else {
        _setError('Failed to create invoice');
        _setLoading(false);
        notifyListeners();
        return null;
      }
    } catch (e) {
      _setError('Failed to convert quote to invoice: $e');
      _setLoading(false);
      notifyListeners();
      return null;
    }
  }

  // ============================================
  // FILTER METHODS
  // ============================================

  List<Quote> get draftQuotes => _quotes.where((q) => q.isDraft).toList();

  List<Quote> get sentQuotes => _quotes.where((q) => q.isSent).toList();

  List<Quote> get approvedQuotes => _quotes.where((q) => q.isApproved).toList();

  List<Quote> get convertedQuotes =>
      _quotes.where((q) => q.isConverted).toList();

  List<Quote> get rejectedQuotes => _quotes.where((q) => q.isRejected).toList();

  List<Quote> get expiredQuotes => _quotes.where((q) => q.isExpired).toList();

  List<Quote> get activeQuotes => _quotes.where((q) => q.isActive).toList();

  List<Quote> getQuotesByStatus(String status) {
    if (status.isEmpty) return _quotes;
    return _quotes.where((quote) => quote.status == status).toList();
  }

  // ============================================
  // SORTING METHODS
  // ============================================

  void sortByNumber({bool ascending = true}) {
    _quotes.sort(
      (a, b) => ascending
          ? a.quoteNumber.compareTo(b.quoteNumber)
          : b.quoteNumber.compareTo(a.quoteNumber),
    );
    _applyFilters();
    notifyListeners();
  }

  void sortByDate({bool ascending = false}) {
    _quotes.sort((a, b) {
      final aDate = a.createdAt ?? DateTime(1970);
      final bDate = b.createdAt ?? DateTime(1970);
      return ascending ? aDate.compareTo(bDate) : bDate.compareTo(aDate);
    });
    _applyFilters();
    notifyListeners();
  }

  void sortByStatus() {
    _quotes.sort(Quote.compareByStatus);
    _applyFilters();
    notifyListeners();
  }

  void sortByTotal({bool ascending = true}) {
    _quotes.sort(
      (a, b) => ascending
          ? a.grandTotal.compareTo(b.grandTotal)
          : b.grandTotal.compareTo(a.grandTotal),
    );
    _applyFilters();
    notifyListeners();
  }

  // ============================================
  // SYNC METHODS
  // ============================================

  Future<void> syncPendingQuotes() async {
    _setLoading(true);
    _clearError();

    try {
      await _databaseService.syncNow();
      await loadQuotes(forceRefresh: true);
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Sync failed: $e');
      _setLoading(false);
      notifyListeners();
    }
  }

  // ============================================
  // STATISTICS
  // ============================================

  Map<String, dynamic> getStatistics() {
    final totalValue = _quotes.fold(0.0, (sum, q) => sum + q.grandTotal);
    final draftCount = _quotes.where((q) => q.isDraft).length;
    final sentCount = _quotes.where((q) => q.isSent).length;
    final approvedCount = _quotes.where((q) => q.isApproved).length;
    final convertedCount = _quotes.where((q) => q.isConverted).length;
    final rejectedCount = _quotes.where((q) => q.isRejected).length;
    final expiredCount = _quotes.where((q) => q.isExpired).length;
    final activeCount = _quotes.where((q) => q.isActive).length;

    return {
      'total_quotes': _quotes.length,
      'total_value': totalValue,
      'average_value': _quotes.isEmpty ? 0 : totalValue / _quotes.length,
      'draft_count': draftCount,
      'sent_count': sentCount,
      'approved_count': approvedCount,
      'converted_count': convertedCount,
      'rejected_count': rejectedCount,
      'expired_count': expiredCount,
      'active_count': activeCount,
      'conversion_rate': _quotes.isEmpty
          ? 0
          : (convertedCount / _quotes.length) * 100,
    };
  }

  // ============================================
  // UTILITY METHODS
  // ============================================

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearCurrentQuote() {
    _currentQuote = null;
    _currentQuoteItems = [];
    notifyListeners();
  }

  void clearAll() {
    _quotes.clear();
    _filteredQuotes.clear();
    _searchQuery = '';
    _selectedStatus = '';
    _currentQuote = null;
    _currentQuoteItems = [];
    _isInitialized = false;
    _errorMessage = null;
    notifyListeners();
  }

  bool hasItemsForQuote(String quoteId) {
    if (_currentQuote != null && _currentQuote!.id == quoteId) {
      return _currentQuoteItems.isNotEmpty;
    }
    return false;
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
}

// ============================================
// EXTENSIONS
// ============================================

extension QuoteProviderExtensions on BuildContext {
  QuoteProvider get quoteProvider =>
      Provider.of<QuoteProvider>(this, listen: false);

  QuoteProvider get quoteProviderWatch =>
      Provider.of<QuoteProvider>(this, listen: true);

  List<Quote> get quotes => quoteProvider.quotes;
  bool get isLoadingQuotes => quoteProvider.isLoading;
  bool get hasQuotes => quoteProvider.hasQuotes;
  List<Quote> get draftQuotes => quoteProvider.draftQuotes;
  List<Quote> get sentQuotes => quoteProvider.sentQuotes;
  List<Quote> get approvedQuotes => quoteProvider.approvedQuotes;

  Future<void> loadQuotes() => quoteProvider.loadQuotes();
  Future<void> refreshQuotes() => quoteProvider.refreshQuotes();
  void searchQuotes(String query) => quoteProvider.searchQuotes(query);
  void clearQuoteSearch() => quoteProvider.clearSearch();
  void filterByStatus(String status) => quoteProvider.filterByStatus(status);
  void clearStatusFilter() => quoteProvider.clearStatusFilter();
}
