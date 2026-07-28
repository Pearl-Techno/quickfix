import 'package:flutter/material.dart';
import 'package:quickfix/config/constants.dart';

class QuoteItem {
  final String id;
  final String quoteId;
  final String? productId;
  final String itemType;
  final String description;
  final int quantity;
  final double unitPrice;
  final double discount;
  final double tax;
  final double total;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? productName; // For display
  final String? unit;
  final String? section; // Added: Section/Category for the item

  QuoteItem({
    required this.id,
    required this.quoteId,
    this.productId,
    required this.itemType,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0,
    this.tax = 0,
    this.total = 0,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.productName,
    this.unit,
    this.section,
  });

  // ============= FACTORY METHODS =============
  factory QuoteItem.fromJson(Map<String, dynamic> json) {
    return QuoteItem(
      id: json['id']?.toString() ?? '',
      quoteId: json['quote_id']?.toString() ?? '',
      productId: json['product_id']?.toString(),
      itemType: json['item_type']?.toString() ?? Constants.itemTypeStock,
      description: json['description']?.toString() ?? '',
      quantity: (json['quantity'] ?? 0).toInt(),
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      discount: (json['discount'] ?? 0).toDouble(),
      tax: (json['tax'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      notes: json['notes']?.toString(),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      productName: json['products'] != null
          ? json['products']['name']?.toString()
          : json['product_name']?.toString(),
      unit: json['unit']?.toString(),
      section: json['section']?.toString(),
    );
  }

  factory QuoteItem.fromMap(Map<String, dynamic> map) {
    return QuoteItem(
      id: map['id']?.toString() ?? '',
      quoteId: map['quote_id']?.toString() ?? '',
      productId: map['product_id']?.toString(),
      itemType: map['item_type']?.toString() ?? Constants.itemTypeStock,
      description: map['description']?.toString() ?? '',
      quantity: (map['quantity'] ?? 0).toInt(),
      unitPrice: (map['unit_price'] ?? 0).toDouble(),
      discount: (map['discount'] ?? 0).toDouble(),
      tax: (map['tax'] ?? 0).toDouble(),
      total: (map['total'] ?? 0).toDouble(),
      notes: map['notes']?.toString(),
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
      productName: map['product_name']?.toString(),
      unit: map['unit']?.toString(),
      section: map['section']?.toString(),
    );
  }

  factory QuoteItem.empty() {
    return QuoteItem(
      id: '',
      quoteId: '',
      description: '',
      quantity: 0,
      unitPrice: 0,
      itemType: Constants.itemTypeStock,
    );
  }

  // ============= JSON SERIALIZATION (for API) =============
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quote_id': quoteId,
      'product_id': productId,
      'item_type': itemType,
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice,
      'discount': discount,
      'tax': tax,
      'total': total,
      'notes': notes,
      'unit': unit,
      'section': section,
    };
  }

  // ============= DATABASE SERIALIZATION (for local DB) =============
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'quote_id': quoteId,
      'item_type': itemType,
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice,
      'discount': discount,
      'tax': tax,
      'total': total,
      'unit': unit,
      'section': section,
    };

    // Only add optional fields if they have values
    if (productId != null && productId!.isNotEmpty) {
      map['product_id'] = productId;
    }
    if (notes != null && notes!.isNotEmpty) {
      map['notes'] = notes;
    }
    if (createdAt != null) {
      map['created_at'] = createdAt!.toIso8601String();
    }
    if (updatedAt != null) {
      map['updated_at'] = updatedAt!.toIso8601String();
    }

    return map;
  }

  // ============= COPY WITH =============
  QuoteItem copyWith({
    String? id,
    String? quoteId,
    String? productId,
    String? itemType,
    String? description,
    int? quantity,
    double? unitPrice,
    double? discount,
    double? tax,
    double? total,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? productName,
    String? unit,
    String? section,
  }) {
    return QuoteItem(
      id: id ?? this.id,
      quoteId: quoteId ?? this.quoteId,
      productId: productId ?? this.productId,
      itemType: itemType ?? this.itemType,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      productName: productName ?? this.productName,
      unit: unit ?? this.unit,
      section: section ?? this.section,
    );
  }

  // ============= CALCULATIONS =============
  double get subtotal => quantity * unitPrice;

  double get totalWithDiscount => subtotal - discount;

  double get totalWithTax => totalWithDiscount + tax;

  double get discountPercentage {
    if (subtotal <= 0) return 0;
    return (discount / subtotal) * 100;
  }

  double get taxPercentage {
    if (subtotal <= 0) return 0;
    return (tax / subtotal) * 100;
  }

  double get effectiveUnitPrice {
    if (quantity <= 0) return 0;
    return total / quantity;
  }

  double get profitMargin {
    if (unitPrice <= 0) return 0;
    return ((unitPrice - (unitPrice * 0.7)) / unitPrice) * 100;
  }

  // ============= VALIDATION =============
  bool get isValid {
    return id.isNotEmpty &&
        quoteId.isNotEmpty &&
        description.isNotEmpty &&
        quantity > 0 &&
        unitPrice >= 0;
  }

  bool get hasProduct => productId != null && productId!.isNotEmpty;
  bool get hasNotes => notes != null && notes!.isNotEmpty;
  bool get hasUnit => unit != null && unit!.isNotEmpty;
  bool get hasDiscount => discount > 0;
  bool get hasTax => tax > 0;
  bool get hasSection => section != null && section!.isNotEmpty;

  // ============= TYPE CHECKS =============
  bool get isStockItem => itemType == Constants.itemTypeStock;
  bool get isOutsourcedItem => itemType == Constants.itemTypeOutsourced;
  bool get isServiceItem => itemType == Constants.itemTypeService;

  bool get isPhysicalItem => isStockItem || isOutsourcedItem;
  bool get isServiceOnly => isServiceItem;

  // ============= DISPLAY PROPERTIES =============
  String get itemTypeDisplay => Constants.getItemTypeDisplay(itemType);

  IconData get itemTypeIcon => Constants.getItemTypeIcon(itemType);

  String get displayTotal => formatCurrency(total);
  String get displaySubtotal => formatCurrency(subtotal);
  String get displayDiscount => formatCurrency(discount);
  String get displayTax => formatCurrency(tax);
  String get displayUnitPrice => formatCurrency(unitPrice);
  String get displayEffectiveUnitPrice => formatCurrency(effectiveUnitPrice);

  String get displayQuantity {
    if (hasUnit) {
      return '$quantity $unit';
    }
    return quantity.toString();
  }

  String get displayName {
    if (productName != null && productName!.isNotEmpty) {
      return productName!;
    }
    return description;
  }

  String get displayShortDescription {
    if (description.length <= 30) return description;
    return '${description.substring(0, 30)}...';
  }

  String get displayCreatedAt {
    if (createdAt == null) return 'N/A';
    return Constants.formatDate(createdAt!);
  }

  String get displaySection => section ?? 'Uncategorized';

  // ============= FORMATTED INFO =============
  String get formattedSummary {
    final parts = <String>[];
    parts.add('Item: $description');
    parts.add('Type: $itemTypeDisplay');
    parts.add('Quantity: $displayQuantity');
    parts.add('Unit Price: $displayUnitPrice');
    if (hasDiscount) parts.add('Discount: $displayDiscount');
    if (hasTax) parts.add('Tax: $displayTax');
    parts.add('Total: $displayTotal');
    if (hasSection) parts.add('Section: $section');
    return parts.join('\n');
  }

  String get formattedCompact {
    return '$description x$quantity - $displayTotal';
  }

  // ============= HELPER METHODS =============
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

  static String formatCurrency(double amount) {
    return 'KSh ${amount.toStringAsFixed(2)}';
  }

  QuoteItem recalculate() {
    final newSubtotal = quantity * unitPrice;
    final newTotal = newSubtotal - discount + tax;
    return copyWith(total: newTotal);
  }

  QuoteItem applyDiscount(double discountAmount) {
    final newDiscount = discountAmount.clamp(0.0, subtotal);
    final newTotal = subtotal - newDiscount + tax;
    return copyWith(discount: newDiscount, total: newTotal);
  }

  QuoteItem applyTax(double taxAmount) {
    final newTax = taxAmount.clamp(0.0, subtotal);
    final newTotal = subtotal - discount + newTax;
    return copyWith(tax: newTax, total: newTotal);
  }

  // ============= COMPARISON =============
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QuoteItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // ============= SORTING & FILTERING =============
  static int compareByDescription(QuoteItem a, QuoteItem b) {
    return a.description.compareTo(b.description);
  }

  static int compareByQuantity(QuoteItem a, QuoteItem b) {
    return a.quantity.compareTo(b.quantity);
  }

  static int compareByUnitPrice(QuoteItem a, QuoteItem b) {
    return a.unitPrice.compareTo(b.unitPrice);
  }

  static int compareByTotal(QuoteItem a, QuoteItem b) {
    return a.total.compareTo(b.total);
  }

  static int compareBySection(QuoteItem a, QuoteItem b) {
    final aSection = a.section ?? '';
    final bSection = b.section ?? '';
    return aSection.compareTo(bSection);
  }

  static bool filterBySearch(QuoteItem item, String query) {
    if (query.isEmpty) return true;
    final searchTerm = query.toLowerCase();
    return item.description.toLowerCase().contains(searchTerm) ||
        (item.productName?.toLowerCase().contains(searchTerm) ?? false) ||
        item.itemTypeDisplay.toLowerCase().contains(searchTerm) ||
        (item.notes?.toLowerCase().contains(searchTerm) ?? false) ||
        (item.section?.toLowerCase().contains(searchTerm) ?? false);
  }

  static bool filterByType(QuoteItem item, String type) {
    if (type.isEmpty) return true;
    return item.itemType == type;
  }

  static bool filterBySection(QuoteItem item, String section) {
    if (section.isEmpty) return true;
    return item.section == section;
  }

  // ============= TO STRING =============
  @override
  String toString() {
    return 'QuoteItem(id: $id, description: $description, quantity: $quantity, total: $total${section != null ? ', section: $section' : ''})';
  }
}

// ============= EXTENSIONS =============
extension QuoteItemListExtensions on List<QuoteItem> {
  double get totalAmount => fold(0, (sum, item) => sum + item.total);

  double get subtotalAmount => fold(0, (sum, item) => sum + item.subtotal);

  int get totalQuantity => fold(0, (sum, item) => sum + item.quantity);

  double get totalDiscount => fold(0, (sum, item) => sum + item.discount);

  double get totalTax => fold(0, (sum, item) => sum + item.tax);

  List<String> get sections {
    final Set<String> uniqueSections = {};
    for (final item in this) {
      if (item.section != null && item.section!.isNotEmpty) {
        uniqueSections.add(item.section!);
      }
    }
    return uniqueSections.toList()..sort();
  }

  List<QuoteItem> search(String query) {
    if (query.isEmpty) return this;
    return where((item) => QuoteItem.filterBySearch(item, query)).toList();
  }

  List<QuoteItem> filterByType(String type) {
    if (type.isEmpty) return this;
    return where((item) => item.itemType == type).toList();
  }

  List<QuoteItem> filterBySection(String section) {
    if (section.isEmpty) return this;
    return where((item) => item.section == section).toList();
  }

  List<QuoteItem> get stockItems => where((item) => item.isStockItem).toList();
  List<QuoteItem> get outsourcedItems =>
      where((item) => item.isOutsourcedItem).toList();
  List<QuoteItem> get serviceItems =>
      where((item) => item.isServiceItem).toList();
  List<QuoteItem> get physicalItems =>
      where((item) => item.isPhysicalItem).toList();

  List<QuoteItem> sortByDescription() {
    final sorted = List<QuoteItem>.from(this);
    sorted.sort(QuoteItem.compareByDescription);
    return sorted;
  }

  List<QuoteItem> sortByQuantity() {
    final sorted = List<QuoteItem>.from(this);
    sorted.sort(QuoteItem.compareByQuantity);
    return sorted;
  }

  List<QuoteItem> sortByPrice() {
    final sorted = List<QuoteItem>.from(this);
    sorted.sort(QuoteItem.compareByUnitPrice);
    return sorted;
  }

  List<QuoteItem> sortByTotal() {
    final sorted = List<QuoteItem>.from(this);
    sorted.sort(QuoteItem.compareByTotal);
    return sorted;
  }

  List<QuoteItem> sortBySection() {
    final sorted = List<QuoteItem>.from(this);
    sorted.sort(QuoteItem.compareBySection);
    return sorted;
  }

  Map<String, List<QuoteItem>> groupByType() {
    final Map<String, List<QuoteItem>> groups = {};
    for (final item in this) {
      groups.putIfAbsent(item.itemType, () => []);
      groups[item.itemType]!.add(item);
    }
    return groups;
  }

  Map<int, List<QuoteItem>> groupByQuantity() {
    final Map<int, List<QuoteItem>> groups = {};
    for (final item in this) {
      groups.putIfAbsent(item.quantity, () => []);
      groups[item.quantity]!.add(item);
    }
    return groups;
  }

  Map<String, List<QuoteItem>> groupBySection() {
    final Map<String, List<QuoteItem>> groups = {};
    for (final item in this) {
      final section = item.section ?? 'Uncategorized';
      groups.putIfAbsent(section, () => []);
      groups[section]!.add(item);
    }
    return groups;
  }

  Map<String, double> get sectionTotals {
    final Map<String, double> totals = {};
    for (final item in this) {
      final section = item.section ?? 'Uncategorized';
      totals[section] = (totals[section] ?? 0) + item.total;
    }
    return totals;
  }

  // ============= CONVERSION TO MAPS FOR DATABASE =============
  List<Map<String, dynamic>> toMaps() {
    return map((item) => item.toMap()).toList();
  }
}
