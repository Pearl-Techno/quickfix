import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/product.dart';
import '../services/database_service.dart';

class ProductProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  StreamSubscription<void>? _syncSubscription;

  ProductProvider() {
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
      final updated = await _databaseService.getProductsOnlyLocal();
      _products = updated;
      _applyFilters();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to refresh products from local database: $e';
      notifyListeners();
    }
  }

  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedCategory = '';

  // ============================================
  // GETTERS
  // ============================================

  List<Product> get products =>
      _searchQuery.isNotEmpty || _selectedCategory.isNotEmpty
          ? _filteredProducts
          : _products;

  List<Product> get allProducts => _products;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;

  int get totalCount => _products.length;
  int get filteredCount => _filteredProducts.isNotEmpty
      ? _filteredProducts.length
      : _products.length;

  bool get hasProducts => _products.isNotEmpty;
  bool get hasFilteredProducts => _filteredProducts.isNotEmpty;

  // ============================================
  // LOAD METHODS
  // ============================================

  Future<void> loadProducts({bool forceRefresh = false}) async {
    if (!forceRefresh && _isInitialized && _products.isNotEmpty) {
      return;
    }

    _setLoading(true);
    _clearError();

    try {
      _products = await _databaseService.getProducts(
        onSyncComplete: () async {
          final updated = await _databaseService.getProductsOnlyLocal();
          _products = updated;
          _applyFilters();
          notifyListeners();
        },
      );
      _applyFilters();
      _isInitialized = true;
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load products: $e');
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> refreshProducts() async {
    await loadProducts(forceRefresh: true);
  }

  // ============================================
  // SEARCH METHODS
  // ============================================

  void searchProducts(String query) {
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

  void filterByCategory(String category) {
    _selectedCategory = category;
    _applyFilters();
    notifyListeners();
  }

  void clearCategoryFilter() {
    if (_selectedCategory.isNotEmpty) {
      _selectedCategory = '';
      _applyFilters();
      notifyListeners();
    }
  }

  void clearAllFilters() {
    _searchQuery = '';
    _selectedCategory = '';
    _filteredProducts = [];
    notifyListeners();
  }

  void _applyFilters() {
    List<Product> result = List.from(_products);

    // Apply category filter
    if (_selectedCategory.isNotEmpty) {
      result = result.where((p) => p.category == _selectedCategory).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final searchTerm = _searchQuery.toLowerCase();
      result = result.where((product) {
        return product.name.toLowerCase().contains(searchTerm) ||
            product.category.toLowerCase().contains(searchTerm) ||
            (product.description?.toLowerCase().contains(searchTerm) ??
                false) ||
            (product.sku?.toLowerCase().contains(searchTerm) ?? false) ||
            (product.brand?.toLowerCase().contains(searchTerm) ?? false) ||
            (product.supplier?.toLowerCase().contains(searchTerm) ?? false);
      }).toList();
    }

    _filteredProducts = result;
  }

  // ============================================
  // CRUD OPERATIONS
  // ============================================

  Future<Product?> getProduct(String id) async {
    try {
      // Check local list first
      final localProduct = _products.firstWhere(
        (p) => p.id == id,
        orElse: () => throw Exception('Product not found locally'),
      );
      return localProduct;
    } catch (_) {
      try {
        return await _databaseService.getProduct(id);
      } catch (e) {
        _setError('Failed to get product: $e');
        notifyListeners();
        return null;
      }
    }
  }

  Future<bool> addProduct({
    required String name,
    required String category,
    required double unitPrice,
    required int quantity,
    String? description,
    int minStock = 5,
    String? sku,
    String? barcode,
    double? costPrice,
    String? unit,
    String? brand,
    String? supplier,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Validate input
      if (name.trim().isEmpty) {
        throw Exception('Product name is required');
      }
      if (category.trim().isEmpty) {
        throw Exception('Category is required');
      }
      if (unitPrice <= 0) {
        throw Exception('Unit price must be greater than 0');
      }
      if (quantity < 0) {
        throw Exception('Quantity cannot be negative');
      }

      final data = {
        'name': name.trim(),
        'category': category.trim(),
        'unit_price': unitPrice,
        'quantity': quantity,
        'min_stock': minStock,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (sku != null && sku.trim().isNotEmpty) 'sku': sku.trim(),
        if (barcode != null && barcode.trim().isNotEmpty)
          'barcode': barcode.trim(),
        if (costPrice != null && costPrice > 0) 'cost_price': costPrice,
        if (unit != null && unit.trim().isNotEmpty) 'unit': unit.trim(),
        if (brand != null && brand.trim().isNotEmpty) 'brand': brand.trim(),
        if (supplier != null && supplier.trim().isNotEmpty)
          'supplier': supplier.trim(),
      };

      final product = await _databaseService.createProduct(data);

      if (product != null) {
        _products.insert(0, product);
        _applyFilters();
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError('Failed to create product');
        _setLoading(false);
        notifyListeners();
        return false;
      }
    } catch (e) {
      _setError('Failed to add product: $e');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  Future<int> bulkAddProducts(List<Map<String, dynamic>> productsData) async {
    _setLoading(true);
    _clearError();
    int successCount = 0;

    try {
      for (var data in productsData) {
        final product = await _databaseService.createProduct(data);
        if (product != null) {
          _products.insert(0, product);
          successCount++;
        }
      }
      _applyFilters();
      _setLoading(false);
      notifyListeners();
      return successCount;
    } catch (e) {
      _setError('Failed to bulk import products: $e');
      _setLoading(false);
      notifyListeners();
      return successCount;
    }
  }

  Future<bool> updateProduct({
    required String id,
    String? name,
    String? description,
    String? category,
    double? unitPrice,
    int? quantity,
    int? minStock,
    String? sku,
    String? barcode,
    double? costPrice,
    String? unit,
    String? brand,
    String? supplier,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final data = <String, dynamic>{};

      if (name != null && name.trim().isNotEmpty) data['name'] = name.trim();
      if (description != null) {
        data['description'] = description.trim().isEmpty
            ? null
            : description.trim();
      }
      if (category != null && category.trim().isNotEmpty) {
        data['category'] = category.trim();
      }
      if (unitPrice != null && unitPrice > 0) data['unit_price'] = unitPrice;
      if (quantity != null && quantity >= 0) data['quantity'] = quantity;
      if (minStock != null && minStock >= 0) data['min_stock'] = minStock;
      if (sku != null) data['sku'] = sku.trim().isEmpty ? null : sku.trim();
      if (barcode != null) {
        data['barcode'] = barcode.trim().isEmpty ? null : barcode.trim();
      }
      if (costPrice != null && costPrice >= 0) data['cost_price'] = costPrice;
      if (unit != null) data['unit'] = unit.trim().isEmpty ? null : unit.trim();
      if (brand != null) {
        data['brand'] = brand.trim().isEmpty ? null : brand.trim();
      }
      if (supplier != null) {
        data['supplier'] = supplier.trim().isEmpty ? null : supplier.trim();
      }

      if (data.isEmpty) {
        throw Exception('No fields to update');
      }

      final updated = await _databaseService.updateProduct(id, data);

      if (updated != null) {
        final index = _products.indexWhere((p) => p.id == id);
        if (index != -1) {
          _products[index] = updated;
        }
        _applyFilters();
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError('Failed to update product');
        _setLoading(false);
        notifyListeners();
        return false;
      }
    } catch (e) {
      _setError('Failed to update product: $e');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProduct(String id) async {
    _setLoading(true);
    _clearError();

    try {
      final success = await _databaseService.deleteProduct(id);

      if (success) {
        _products.removeWhere((p) => p.id == id);
        _applyFilters();
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError('Failed to delete product');
        _setLoading(false);
        notifyListeners();
        return false;
      }
    } catch (e) {
      _setError('Failed to delete product: $e');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAllProducts() async {
    _setLoading(true);
    _clearError();

    try {
      for (final product in _products) {
        await _databaseService.deleteProduct(product.id);
      }

      _products.clear();
      _filteredProducts.clear();
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to delete all products: $e');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  // ============================================
  // STOCK MANAGEMENT
  // ============================================

  Future<bool> updateStock(String id, int newQuantity) async {
    if (newQuantity < 0) {
      _setError('Quantity cannot be negative');
      notifyListeners();
      return false;
    }
    return await updateProduct(id: id, quantity: newQuantity);
  }

  Future<bool> adjustStock(String id, int adjustment) async {
    final product = _products.firstWhere((p) => p.id == id);
    final newQuantity = (product.quantity + adjustment).clamp(
      0,
      product.maxStock,
    );
    return await updateStock(id, newQuantity);
  }

  Future<bool> restockProduct(String id, int amount) async {
    if (amount <= 0) {
      _setError('Restock amount must be positive');
      notifyListeners();
      return false;
    }
    return await adjustStock(id, amount);
  }

  Future<bool> sellProduct(String id, int quantity) async {
    if (quantity <= 0) {
      _setError('Quantity must be positive');
      notifyListeners();
      return false;
    }
    return await adjustStock(id, -quantity);
  }

  // ============================================
  // FILTER METHODS
  // ============================================

  List<Product> get lowStockProducts =>
      _products.where((product) => product.isLowStock).toList();

  List<Product> get outOfStockProducts =>
      _products.where((product) => product.isOutOfStock).toList();

  List<Product> get inStockProducts =>
      _products.where((product) => product.isInStock).toList();

  List<Product> get activeProducts =>
      _products.where((product) => product.isActive).toList();

  List<Product> getProductsByCategory(String category) {
    if (category.isEmpty) return _products;
    return _products.where((product) => product.category == category).toList();
  }

  List<String> getCategories() {
    final categories = <String>{};
    for (var product in _products) {
      categories.add(product.category);
    }
    return categories.toList()..sort();
  }

  Map<String, List<Product>> getProductsGroupedByCategory() {
    final Map<String, List<Product>> grouped = {};
    for (var product in _products) {
      grouped.putIfAbsent(product.category, () => []);
      grouped[product.category]!.add(product);
    }
    return grouped;
  }

  // ============================================
  // SORTING METHODS
  // ============================================

  void sortByName({bool ascending = true}) {
    _products.sort(
      (a, b) => ascending ? a.name.compareTo(b.name) : b.name.compareTo(a.name),
    );
    _applyFilters();
    notifyListeners();
  }

  void sortByPrice({bool ascending = true}) {
    _products.sort(
      (a, b) => ascending
          ? a.unitPrice.compareTo(b.unitPrice)
          : b.unitPrice.compareTo(a.unitPrice),
    );
    _applyFilters();
    notifyListeners();
  }

  void sortByStock({bool ascending = true}) {
    _products.sort(
      (a, b) => ascending
          ? a.quantity.compareTo(b.quantity)
          : b.quantity.compareTo(a.quantity),
    );
    _applyFilters();
    notifyListeners();
  }

  void sortByCategory({bool ascending = true}) {
    _products.sort(
      (a, b) => ascending
          ? a.category.compareTo(b.category)
          : b.category.compareTo(a.category),
    );
    _applyFilters();
    notifyListeners();
  }

  // ============================================
  // STATISTICS
  // ============================================

  Map<String, dynamic> getStatistics() {
    final totalValue = _products.fold(0.0, (sum, p) => sum + p.totalValue);
    final totalCost = _products.fold(0.0, (sum, p) => sum + p.totalCost);
    final totalProfit = _products.fold(
      0.0,
      (sum, p) => sum + p.potentialProfit,
    );
    final totalQuantity = _products.fold(0, (sum, p) => sum + p.quantity);
    final lowStockCount = _products.where((p) => p.isLowStock).length;
    final outOfStockCount = _products.where((p) => p.isOutOfStock).length;
    final overStockCount = _products.where((p) => p.isOverStock).length;

    return {
      'total_products': _products.length,
      'total_quantity': totalQuantity,
      'total_value': totalValue,
      'total_cost': totalCost,
      'total_profit': totalProfit,
      'low_stock_count': lowStockCount,
      'out_of_stock_count': outOfStockCount,
      'over_stock_count': overStockCount,
      'in_stock_count': _products.length - outOfStockCount,
      'average_price': _products.isEmpty ? 0 : totalValue / _products.length,
      'categories_count': getCategories().length,
    };
  }

  // ============================================
  // UTILITY METHODS
  // ============================================

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearAll() {
    _products.clear();
    _filteredProducts.clear();
    _searchQuery = '';
    _selectedCategory = '';
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
}

// ============================================
// EXTENSIONS
// ============================================

extension ProductProviderExtensions on BuildContext {
  ProductProvider get productProvider =>
      Provider.of<ProductProvider>(this, listen: false);

  ProductProvider get productProviderWatch =>
      Provider.of<ProductProvider>(this, listen: true);

  List<Product> get products => productProvider.products;
  bool get isLoadingProducts => productProvider.isLoading;
  bool get hasProducts => productProvider.hasProducts;
  List<Product> get lowStockProducts => productProvider.lowStockProducts;
  List<String> get categories => productProvider.getCategories();

  void loadProducts() => productProvider.loadProducts();
  void searchProducts(String query) => productProvider.searchProducts(query);
  void clearProductSearch() => productProvider.clearSearch();
  void filterByCategory(String category) =>
      productProvider.filterByCategory(category);
  void clearCategoryFilter() => productProvider.clearCategoryFilter();
}
