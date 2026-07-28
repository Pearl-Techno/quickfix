import 'package:flutter/material.dart';
import 'package:quickfix/config/app_colors.dart';
import 'package:quickfix/config/constants.dart';

class Product {
  final String id;
  final String name;
  final String? description;
  final String category;
  final String? subcategory;
  final String? sku;
  final String? barcode;
  final double unitPrice;
  final double costPrice;
  final int quantity;
  final int minStock;
  final int maxStock;
  final String? unit;
  final double? weight;
  final double? width;
  final double? height;
  final double? length;
  final String? brand;
  final String? supplier;
  final String? location;
  final bool isActive;
  final bool isTaxable;
  final double taxRate;
  final String? imageUrl;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    this.subcategory,
    this.sku,
    this.barcode,
    required this.unitPrice,
    this.costPrice = 0,
    required this.quantity,
    this.minStock = 5,
    this.maxStock = 100,
    this.unit,
    this.weight,
    this.width,
    this.height,
    this.length,
    this.brand,
    this.supplier,
    this.location,
    this.isActive = true,
    this.isTaxable = true,
    this.taxRate = Constants.taxRate,
    this.imageUrl,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  // ============= FACTORY METHODS =============

  // Helper to convert int to bool
  static bool _toBool(dynamic value) {
    if (value == null) return true;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == '1';
    }
    return true;
  }

  // Helper to parse DateTime
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    try {
      if (value is DateTime) return value;
      if (value is String) {
        return DateTime.parse(value);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      category: json['category']?.toString() ?? '',
      subcategory: json['subcategory']?.toString(),
      sku: json['sku']?.toString(),
      barcode: json['barcode']?.toString(),
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      minStock: (json['min_stock'] as num?)?.toInt() ?? 5,
      maxStock: (json['max_stock'] as num?)?.toInt() ?? 100,
      unit: json['unit']?.toString(),
      weight: (json['weight'] as num?)?.toDouble(),
      width: (json['width'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      length: (json['length'] as num?)?.toDouble(),
      brand: json['brand']?.toString(),
      supplier: json['supplier']?.toString(),
      location: json['location']?.toString(),
      isActive: _toBool(json['is_active']),
      isTaxable: _toBool(json['is_taxable']),
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? Constants.taxRate,
      imageUrl: json['image_url']?.toString(),
      notes: json['notes']?.toString(),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString(),
      category: map['category']?.toString() ?? '',
      subcategory: map['subcategory']?.toString(),
      sku: map['sku']?.toString(),
      barcode: map['barcode']?.toString(),
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
      costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      minStock: (map['min_stock'] as num?)?.toInt() ?? 5,
      maxStock: (map['max_stock'] as num?)?.toInt() ?? 100,
      unit: map['unit']?.toString(),
      weight: (map['weight'] as num?)?.toDouble(),
      width: (map['width'] as num?)?.toDouble(),
      height: (map['height'] as num?)?.toDouble(),
      length: (map['length'] as num?)?.toDouble(),
      brand: map['brand']?.toString(),
      supplier: map['supplier']?.toString(),
      location: map['location']?.toString(),
      isActive: _toBool(map['is_active']),
      isTaxable: _toBool(map['is_taxable']),
      taxRate: (map['tax_rate'] as num?)?.toDouble() ?? Constants.taxRate,
      imageUrl: map['image_url']?.toString(),
      notes: map['notes']?.toString(),
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  factory Product.empty() {
    return Product(id: '', name: '', category: '', unitPrice: 0, quantity: 0);
  }

  // ============= JSON SERIALIZATION =============

  // Helper to convert bool to int for storage
  static int _toInt(bool value) => value ? 1 : 0;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'subcategory': subcategory,
      'sku': sku,
      'barcode': barcode,
      'unit_price': unitPrice,
      'cost_price': costPrice,
      'quantity': quantity,
      'min_stock': minStock,
      'max_stock': maxStock,
      'unit': unit,
      'weight': weight,
      'width': width,
      'height': height,
      'length': length,
      'brand': brand,
      'supplier': supplier,
      'location': location,
      'is_active': _toInt(isActive),
      'is_taxable': _toInt(isTaxable),
      'tax_rate': taxRate,
      'image_url': imageUrl,
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'subcategory': subcategory,
      'sku': sku,
      'barcode': barcode,
      'unit_price': unitPrice,
      'cost_price': costPrice,
      'quantity': quantity,
      'min_stock': minStock,
      'max_stock': maxStock,
      'unit': unit,
      'weight': weight,
      'width': width,
      'height': height,
      'length': length,
      'brand': brand,
      'supplier': supplier,
      'location': location,
      'is_active': _toInt(isActive),
      'is_taxable': _toInt(isTaxable),
      'tax_rate': taxRate,
      'image_url': imageUrl,
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // ============= COPY WITH =============
  Product copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    String? subcategory,
    String? sku,
    String? barcode,
    double? unitPrice,
    double? costPrice,
    int? quantity,
    int? minStock,
    int? maxStock,
    String? unit,
    double? weight,
    double? width,
    double? height,
    double? length,
    String? brand,
    String? supplier,
    String? location,
    bool? isActive,
    bool? isTaxable,
    double? taxRate,
    String? imageUrl,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      unitPrice: unitPrice ?? this.unitPrice,
      costPrice: costPrice ?? this.costPrice,
      quantity: quantity ?? this.quantity,
      minStock: minStock ?? this.minStock,
      maxStock: maxStock ?? this.maxStock,
      unit: unit ?? this.unit,
      weight: weight ?? this.weight,
      width: width ?? this.width,
      height: height ?? this.height,
      length: length ?? this.length,
      brand: brand ?? this.brand,
      supplier: supplier ?? this.supplier,
      location: location ?? this.location,
      isActive: isActive ?? this.isActive,
      isTaxable: isTaxable ?? this.isTaxable,
      taxRate: taxRate ?? this.taxRate,
      imageUrl: imageUrl ?? this.imageUrl,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ============= STOCK MANAGEMENT =============
  bool get isLowStock => quantity <= minStock;
  bool get isOutOfStock => quantity <= 0;
  bool get isOverStock => quantity >= maxStock;
  bool get isInStock => quantity > 0;
  bool get isActiveStock => isActive && isInStock;

  StockStatus get stockStatus {
    if (isOutOfStock) return StockStatus.outOfStock;
    if (isLowStock) return StockStatus.lowStock;
    if (isOverStock) return StockStatus.overStock;
    return StockStatus.inStock;
  }

  String get stockStatusDisplay {
    switch (stockStatus) {
      case StockStatus.inStock:
        return 'In Stock';
      case StockStatus.lowStock:
        return 'Low Stock';
      case StockStatus.outOfStock:
        return 'Out of Stock';
      case StockStatus.overStock:
        return 'Over Stock';
    }
  }

  Color get stockStatusColor {
    switch (stockStatus) {
      case StockStatus.inStock:
        return AppColors.success;
      case StockStatus.lowStock:
        return AppColors.warning;
      case StockStatus.outOfStock:
        return AppColors.error;
      case StockStatus.overStock:
        return AppColors.info;
    }
  }

  IconData get stockStatusIcon {
    switch (stockStatus) {
      case StockStatus.inStock:
        return Icons.check_circle;
      case StockStatus.lowStock:
        return Icons.warning_amber;
      case StockStatus.outOfStock:
        return Icons.cancel;
      case StockStatus.overStock:
        return Icons.inventory;
    }
  }

  // ============= CALCULATIONS =============
  double get totalValue => unitPrice * quantity;
  double get totalCost => costPrice * quantity;
  double get potentialProfit => totalValue - totalCost;
  double get profitMargin {
    if (unitPrice <= 0) return 0;
    return ((unitPrice - costPrice) / unitPrice) * 100;
  }

  double get taxAmount => unitPrice * taxRate;
  double get priceWithTax => unitPrice + taxAmount;

  double get volume {
    if (width == null || height == null || length == null) return 0;
    return width! * height! * length!;
  }

  // ============= VALIDATION =============
  bool get isValid {
    return id.isNotEmpty &&
        name.isNotEmpty &&
        category.isNotEmpty &&
        unitPrice > 0 &&
        quantity >= 0;
  }

  bool get hasDescription => description != null && description!.isNotEmpty;
  bool get hasSku => sku != null && sku!.isNotEmpty;
  bool get hasBarcode => barcode != null && barcode!.isNotEmpty;
  bool get hasUnit => unit != null && unit!.isNotEmpty;
  bool get hasWeight => weight != null && weight! > 0;
  bool get hasDimensions => width != null && height != null && length != null;
  bool get hasBrand => brand != null && brand!.isNotEmpty;
  bool get hasSupplier => supplier != null && supplier!.isNotEmpty;
  bool get hasLocation => location != null && location!.isNotEmpty;
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasNotes => notes != null && notes!.isNotEmpty;

  // ============= DISPLAY PROPERTIES =============
  String get displayName => name;
  String get displayCategory => category;
  String get displaySubcategory => subcategory ?? 'N/A';
  String get displaySku => sku ?? 'N/A';
  String get displayBarcode => barcode ?? 'N/A';
  String get displayUnit => unit ?? 'N/A';
  String get displayBrand => brand ?? 'N/A';
  String get displaySupplier => supplier ?? 'N/A';
  String get displayLocation => location ?? 'N/A';

  String get displayPrice => formatCurrency(unitPrice);
  String get displayCostPrice => formatCurrency(costPrice);
  String get displayTotalValue => formatCurrency(totalValue);
  String get displayTotalCost => formatCurrency(totalCost);
  String get displayPotentialProfit => formatCurrency(potentialProfit);
  String get displayTaxAmount => formatCurrency(taxAmount);
  String get displayPriceWithTax => formatCurrency(priceWithTax);

  String get displayQuantity {
    if (hasUnit) {
      return '$quantity $unit';
    }
    return quantity.toString();
  }

  String get displayWeight {
    if (!hasWeight) return 'N/A';
    return '${weight}kg';
  }

  String get displayDimensions {
    if (!hasDimensions) return 'N/A';
    return '$width × $height × $length';
  }

  String get displayVolume {
    if (!hasDimensions) return 'N/A';
    return '${volume.toStringAsFixed(2)} m³';
  }

  String get displayShortDescription {
    if (description == null) return '';
    if (description!.length <= 50) return description!;
    return '${description!.substring(0, 50)}...';
  }

  String get displayCreatedAt {
    if (createdAt == null) return 'N/A';
    return Constants.formatDate(createdAt!);
  }

  String get displayUpdatedAt {
    if (updatedAt == null) return 'N/A';
    return Constants.formatDate(updatedAt!);
  }

  // ============= FORMATTED INFO =============
  String get formattedSummary {
    final parts = <String>[];
    parts.add('Product: $name');
    parts.add('SKU: $displaySku');
    parts.add('Category: $displayCategory');
    parts.add('Price: $displayPrice');
    parts.add('Stock: $displayQuantity');
    parts.add('Status: $stockStatusDisplay');
    if (hasDescription) parts.add('Description: $description');
    return parts.join('\n');
  }

  String get formattedStockInfo {
    final parts = <String>[];
    parts.add('Current Stock: $quantity');
    parts.add('Min Stock: $minStock');
    parts.add('Max Stock: $maxStock');
    parts.add('Status: $stockStatusDisplay');
    if (isLowStock) {
      parts.add('⚠️ Low Stock Alert!');
    }
    if (isOutOfStock) {
      parts.add('🚫 Out of Stock!');
    }
    return parts.join('\n');
  }

  // ============= HELPER METHODS =============
  static String formatCurrency(double amount) {
    return 'KSh ${amount.toStringAsFixed(2)}';
  }

  Product adjustStock(int adjustment) {
    final newQuantity = quantity + adjustment;
    return copyWith(
      quantity: newQuantity.clamp(0, maxStock),
      updatedAt: DateTime.now(),
    );
  }

  Product increaseStock(int amount) {
    return adjustStock(amount);
  }

  Product decreaseStock(int amount) {
    return adjustStock(-amount);
  }

  Product updatePrice(double newPrice) {
    return copyWith(unitPrice: newPrice, updatedAt: DateTime.now());
  }

  // ============= COMPARISON =============
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // ============= SORTING & FILTERING =============
  static int compareByName(Product a, Product b) {
    return a.name.compareTo(b.name);
  }

  static int compareByPrice(Product a, Product b) {
    return a.unitPrice.compareTo(b.unitPrice);
  }

  static int compareByStock(Product a, Product b) {
    return a.quantity.compareTo(b.quantity);
  }

  static int compareByCategory(Product a, Product b) {
    return a.category.compareTo(b.category);
  }

  static bool filterBySearch(Product product, String query) {
    if (query.isEmpty) return true;
    final searchTerm = query.toLowerCase();
    return product.name.toLowerCase().contains(searchTerm) ||
        (product.description?.toLowerCase().contains(searchTerm) ?? false) ||
        (product.sku?.toLowerCase().contains(searchTerm) ?? false) ||
        (product.barcode?.toLowerCase().contains(searchTerm) ?? false) ||
        (product.brand?.toLowerCase().contains(searchTerm) ?? false) ||
        (product.supplier?.toLowerCase().contains(searchTerm) ?? false) ||
        product.category.toLowerCase().contains(searchTerm);
  }

  static bool filterByCategory(Product product, String category) {
    if (category.isEmpty) return true;
    return product.category == category || product.subcategory == category;
  }

  static bool filterByStockStatus(Product product, StockStatus status) {
    return product.stockStatus == status;
  }

  // ============= TO STRING =============
  @override
  String toString() {
    return 'Product(id: $id, name: $name, price: $unitPrice, stock: $quantity)';
  }
}

// ============= STOCK STATUS ENUM =============
enum StockStatus { inStock, lowStock, outOfStock, overStock }

// ============= EXTENSIONS =============
extension ProductListExtensions on List<Product> {
  List<Product> search(String query) {
    if (query.isEmpty) return this;
    return where((product) => Product.filterBySearch(product, query)).toList();
  }

  List<Product> filterByCategory(String category) {
    if (category.isEmpty) return this;
    return where((product) => product.category == category).toList();
  }

  List<Product> filterByStockStatus(StockStatus status) {
    return where((product) => product.stockStatus == status).toList();
  }

  List<Product> get inStock => where((p) => p.isInStock).toList();
  List<Product> get lowStock => where((p) => p.isLowStock).toList();
  List<Product> get outOfStock => where((p) => p.isOutOfStock).toList();
  List<Product> get overStock => where((p) => p.isOverStock).toList();
  List<Product> get active => where((p) => p.isActive).toList();

  List<Product> sortByName() {
    final sorted = List<Product>.from(this);
    sorted.sort(Product.compareByName);
    return sorted;
  }

  List<Product> sortByPrice() {
    final sorted = List<Product>.from(this);
    sorted.sort(Product.compareByPrice);
    return sorted;
  }

  List<Product> sortByStock() {
    final sorted = List<Product>.from(this);
    sorted.sort(Product.compareByStock);
    return sorted;
  }

  List<Product> sortByCategory() {
    final sorted = List<Product>.from(this);
    sorted.sort(Product.compareByCategory);
    return sorted;
  }

  double get totalValue => fold(0, (sum, p) => sum + p.totalValue);
  double get totalCost => fold(0, (sum, p) => sum + p.totalCost);
  double get totalProfit => fold(0, (sum, p) => sum + p.potentialProfit);
  int get totalQuantity => fold(0, (sum, p) => sum + p.quantity);

  Map<String, List<Product>> groupByCategory() {
    final Map<String, List<Product>> groups = {};
    for (final product in this) {
      groups.putIfAbsent(product.category, () => []);
      groups[product.category]!.add(product);
    }
    return groups;
  }

  Map<StockStatus, List<Product>> groupByStockStatus() {
    final Map<StockStatus, List<Product>> groups = {};
    for (final product in this) {
      groups.putIfAbsent(product.stockStatus, () => []);
      groups[product.stockStatus]!.add(product);
    }
    return groups;
  }
}
