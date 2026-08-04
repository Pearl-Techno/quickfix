import 'package:flutter/material.dart';
import 'package:quickfix/config/constants.dart';
import 'package:quickfix/models/quote_item.dart';
import 'package:quickfix/models/customer.dart';

class Quote {
  final String id;
  final String quoteNumber;
  final String customerId;
  final String? userId;
  final String? title;
  final String status;
  final double subtotal;
  final double tax;
  final double total;
  final double discount;
  final double grandTotal;
  final int validityDays;
  final String? scope;
  final String? notes;
  final String? terms;
  final String? siteMeasurements;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? expiryDate;
  final String? customerName; // For display
  final Customer? customer; // Full customer object
  final List<QuoteItem>? items;

  Quote({
    required this.id,
    required this.quoteNumber,
    required this.customerId,
    this.userId,
    this.title,
    this.status = Constants.quoteStatusDraft,
    this.subtotal = 0,
    this.tax = 0,
    this.total = 0,
    this.discount = 0,
    this.grandTotal = 0,
    this.validityDays = Constants.defaultQuoteValidityDays,
    this.scope,
    this.notes,
    this.terms,
    this.siteMeasurements,
    this.createdAt,
    this.updatedAt,
    this.expiryDate,
    this.customerName,
    this.customer,
    this.items,
  });

  // ============= FACTORY METHODS =============
  factory Quote.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] != null
        ? (json['items'] as List)
              .map((item) => QuoteItem.fromJson(item as Map<String, dynamic>))
              .toList()
        : null;

    Customer? customerObj;
    if (json['customers'] != null) {
      customerObj = Customer.fromJson(json['customers']);
    }

    return Quote(
      id: json['id']?.toString() ?? '',
      quoteNumber: json['quote_number']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      title: json['title']?.toString(),
      status: json['status']?.toString() ?? Constants.quoteStatusDraft,
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      tax: (json['tax'] ?? 0).toDouble(),
      total: (json['total'] ?? json['grand_total'] ?? json['subtotal'] ?? 0).toDouble(),
      discount: (json['discount'] ?? 0).toDouble(),
      grandTotal: (json['grand_total'] ?? json['total'] ?? json['subtotal'] ?? 0).toDouble(),
      validityDays: json['validity_days'] ?? Constants.defaultQuoteValidityDays,
      scope: json['scope']?.toString(),
      notes: json['notes']?.toString(),
      terms: json['terms']?.toString(),
      siteMeasurements: json['site_measurements']?.toString(),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      expiryDate: _parseDateTime(json['expiry_date'] ?? json['due_date']),
      customerName: customerObj?.name ?? json['customer_name']?.toString(),
      customer: customerObj,
      items: itemsList,
    );
  }

  factory Quote.empty() {
    return Quote(id: '', quoteNumber: '', customerId: '', userId: '');
  }

  factory Quote.fromMap(Map<String, dynamic> map) {
    final itemsList = map['items'] != null
        ? (map['items'] as List)
              .map((item) => QuoteItem.fromMap(item as Map<String, dynamic>))
              .toList()
        : null;

    return Quote(
      id: map['id']?.toString() ?? '',
      quoteNumber: map['quote_number']?.toString() ?? '',
      customerId: map['customer_id']?.toString() ?? '',
      userId: map['user_id']?.toString(),
      title: map['title']?.toString(),
      status: map['status']?.toString() ?? Constants.quoteStatusDraft,
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      tax: (map['tax'] ?? 0).toDouble(),
      total: (map['total'] ?? map['grand_total'] ?? map['subtotal'] ?? 0).toDouble(),
      discount: (map['discount'] ?? 0).toDouble(),
      grandTotal: (map['grand_total'] ?? map['total'] ?? map['subtotal'] ?? 0).toDouble(),
      validityDays: map['validity_days'] ?? Constants.defaultQuoteValidityDays,
      scope: map['scope']?.toString(),
      notes: map['notes']?.toString(),
      terms: map['terms']?.toString(),
      siteMeasurements: map['site_measurements']?.toString(),
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
      expiryDate: _parseDateTime(map['expiry_date'] ?? map['due_date']),
      customerName: map['customer_name']?.toString(),
      items: itemsList,
    );
  }

  // ============= JSON SERIALIZATION (for API) =============
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quote_number': quoteNumber,
      'customer_id': customerId,
      'user_id': userId,
      'title': title,
      'status': status,
      'subtotal': subtotal,
      'tax': tax,
      'total': total,
      'discount': discount,
      'grand_total': grandTotal,
      'validity_days': validityDays,
      'scope': scope,
      'notes': notes,
      'terms': terms,
      'site_measurements': siteMeasurements,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'expiry_date': expiryDate?.toIso8601String(),
      // REMOVE items from here - they should NOT be saved to the database
      // 'items': items?.map((item) => item.toJson()).toList(),
    };
  }

  // ============= DATABASE SERIALIZATION (for local DB - NO items) =============
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'quote_number': quoteNumber,
      'customer_id': customerId,
      'user_id': userId,
      'title': title,
      'status': status,
      'subtotal': subtotal,
      'tax': tax,
      'total': total,
      'discount': discount,
      'grand_total': grandTotal,
      'validity_days': validityDays,
      'scope': scope,
      'notes': notes,
      'terms': terms,
      'site_measurements': siteMeasurements,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'expiry_date': expiryDate?.toIso8601String(),
      // DO NOT include items here
    };
  }

  // ============= JSON with Items (for display/full response) =============
  Map<String, dynamic> toJsonWithItems() {
    final json = toJson();
    if (items != null && items!.isNotEmpty) {
      json['items'] = items!.map((item) => item.toJson()).toList();
    }
    return json;
  }

  // ============= COPY WITH =============
  Quote copyWith({
    String? id,
    String? quoteNumber,
    String? customerId,
    String? userId,
    String? title,
    String? status,
    double? subtotal,
    double? tax,
    double? total,
    double? discount,
    double? grandTotal,
    int? validityDays,
    String? scope,
    String? notes,
    String? siteMeasurements,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? expiryDate,
    String? customerName,
    Customer? customer,
    List<QuoteItem>? items,
  }) {
    return Quote(
      id: id ?? this.id,
      quoteNumber: quoteNumber ?? this.quoteNumber,
      customerId: customerId ?? this.customerId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      status: status ?? this.status,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      discount: discount ?? this.discount,
      grandTotal: grandTotal ?? this.grandTotal,
      validityDays: validityDays ?? this.validityDays,
      scope: scope ?? this.scope,
      notes: notes ?? this.notes,
      siteMeasurements: siteMeasurements ?? this.siteMeasurements,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiryDate: expiryDate ?? this.expiryDate,
      customerName: customerName ?? this.customerName,
      customer: customer ?? this.customer,
      items: items ?? this.items,
    );
  }

  // ============= STATUS CHECKS =============
  bool get isDraft => status == Constants.quoteStatusDraft;
  bool get isSent => status == Constants.quoteStatusSent;
  bool get isApproved => status == Constants.quoteStatusApproved;
  bool get isConverted => status == Constants.quoteStatusConverted;
  bool get isRejected => status == Constants.quoteStatusRejected;
  bool get isExpired => status == Constants.quoteStatusExpired;

  bool get isEditable => isDraft || isSent;
  bool get canSend => isDraft;
  bool get canApprove => isSent;
  bool get canConvertToInvoice => isApproved && !isConverted;
  bool get canReject => isSent || isApproved;
  bool get canEdit => isDraft || isSent;

  bool get isActive => !isRejected && !isConverted && !isExpired;

  // ============= CALCULATIONS =============
  int get totalItems => items?.length ?? 0;

  int get totalQuantity {
    if (items == null) return 0;
    return items!.fold(0, (sum, item) => sum + item.quantity);
  }

  double get discountPercentage {
    if (subtotal <= 0) return 0;
    return (discount / subtotal) * 100;
  }

  double get taxAmount {
    if (subtotal <= 0) return 0;
    return (subtotal - discount) * Constants.taxRate;
  }

  double get calculatedTotal {
    final afterDiscount = subtotal - discount;
    final taxAmount = afterDiscount * Constants.taxRate;
    return afterDiscount + taxAmount;
  }

  double get effectiveTotal {
    if (grandTotal > 0) return grandTotal;
    if (total > 0) return total;
    if (subtotal > 0) return subtotal;
    if (items != null && items!.isNotEmpty) {
      return items!.fold(0.0, (sum, item) => sum + item.total);
    }
    return 0.0;
  }

  double get effectiveSubtotal {
    if (subtotal > 0) return subtotal;
    if (effectiveTotal > 0) {
      return tax > 0 ? effectiveTotal / (1 + Constants.taxRate) : effectiveTotal;
    }
    if (items != null && items!.isNotEmpty) {
      return items!.fold(0.0, (sum, item) => sum + item.total);
    }
    return 0.0;
  }

  // ============= VALIDATION METHODS =============
  bool get isValid {
    return id.isNotEmpty &&
        quoteNumber.isNotEmpty &&
        customerId.isNotEmpty &&
        (items?.isNotEmpty ?? false);
  }

  bool get hasItems => items != null && items!.isNotEmpty;
  bool get hasTitle => title != null && title!.isNotEmpty;
  bool get hasNotes => notes != null && notes!.isNotEmpty;
  bool get hasSiteMeasurements =>
      siteMeasurements != null && siteMeasurements!.isNotEmpty;
  bool get hasCustomer => customer != null;

  bool get isOverdue {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final daysUntilExpiry = DateTime.now().difference(expiryDate!).inDays;
    return daysUntilExpiry <= 3 && daysUntilExpiry >= 0;
  }

  // ============= DISPLAY PROPERTIES =============
  String get displayStatus => Constants.getQuoteStatusDisplay(status);

  Color get statusColor => Constants.getQuoteStatusColor(status);

  Color get statusBackgroundColor =>
      Constants.getQuoteStatusBackgroundColor(status);

  IconData get statusIcon => Constants.getQuoteStatusIcon(status);

  String get displayTotal => formatCurrency(effectiveTotal);
  String get displaySubtotal => formatCurrency(effectiveSubtotal);
  String get displayTax => formatCurrency(tax);
  String get displayDiscount => formatCurrency(discount);
  String get displayGrandTotal => formatCurrency(grandTotal);

  String get displayCreatedAt {
    if (createdAt == null) return 'N/A';
    return Constants.formatDate(createdAt!);
  }

  String get displayUpdatedAt {
    if (updatedAt == null) return 'N/A';
    return Constants.formatDate(updatedAt!);
  }

  String get displayExpiryDate {
    if (expiryDate == null) return 'N/A';
    return Constants.formatDate(expiryDate!);
  }

  String get displayTimeAgo {
    if (createdAt == null) return 'N/A';
    final difference = DateTime.now().difference(createdAt!);
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${(difference.inDays / 365).floor() > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  String get displayDaysRemaining {
    if (expiryDate == null) return 'N/A';
    final days = DateTime.now().difference(expiryDate!).inDays;
    if (days < 0) return 'Expired';
    if (days == 0) return 'Expires today';
    return '$days day${days > 1 ? 's' : ''} remaining';
  }

  // ============= FORMATTED INFO =============
  String get formattedSummary {
    final parts = <String>[];
    parts.add('Quote #$quoteNumber');
    parts.add('Status: $displayStatus');
    parts.add('Customer: ${customerName ?? customer?.name ?? 'N/A'}');
    parts.add('Total: $displayGrandTotal');
    parts.add('Items: $totalItems');
    parts.add('Created: $displayCreatedAt');
    if (expiryDate != null) {
      parts.add('Expires: $displayExpiryDate');
    }
    return parts.join('\n');
  }

  String get formattedItemsSummary {
    if (!hasItems) return 'No items';
    final parts = <String>[];
    parts.add('Quote #$quoteNumber - Items:');
    for (final item in items!) {
      parts.add(
        '  • ${item.description} x${item.quantity} - ${formatCurrency(item.total)}',
      );
    }
    parts.add('Subtotal: $displaySubtotal');
    if (discount > 0) parts.add('Discount: $displayDiscount');
    parts.add('Tax: $displayTax');
    parts.add('Total: $displayGrandTotal');
    return parts.join('\n');
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

  // ============= CALCULATION HELPERS =============
  Quote recalculate() {
    if (items == null) return this;

    double newSubtotal = 0;
    for (final item in items!) {
      newSubtotal += item.total;
    }

    final newTax = newSubtotal * Constants.taxRate;
    final newTotal = newSubtotal + newTax;
    final newGrandTotal = newTotal - discount;

    return copyWith(
      subtotal: newSubtotal,
      tax: newTax,
      total: newTotal,
      grandTotal: newGrandTotal,
    );
  }

  Quote applyDiscount(double discountAmount) {
    final newDiscount = discountAmount.clamp(0.0, total);
    final newGrandTotal = total - newDiscount;
    return copyWith(discount: newDiscount, grandTotal: newGrandTotal);
  }

  // ============= COMPARISON =============
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Quote && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // ============= SORTING & FILTERING =============
  static int compareByNumber(Quote a, Quote b) {
    return a.quoteNumber.compareTo(b.quoteNumber);
  }

  static int compareByDate(Quote a, Quote b) {
    final aDate = a.createdAt ?? DateTime(1970);
    final bDate = b.createdAt ?? DateTime(1970);
    return bDate.compareTo(aDate); // Newest first
  }

  static int compareByStatus(Quote a, Quote b) {
    final aPriority = Constants.quoteStatusList.indexOf(a.status);
    final bPriority = Constants.quoteStatusList.indexOf(b.status);
    return aPriority.compareTo(bPriority);
  }

  static int compareByTotal(Quote a, Quote b) {
    return a.grandTotal.compareTo(b.grandTotal);
  }

  static bool filterBySearch(Quote quote, String query) {
    if (query.isEmpty) return true;
    final searchTerm = query.toLowerCase();
    return quote.quoteNumber.toLowerCase().contains(searchTerm) ||
        (quote.title?.toLowerCase().contains(searchTerm) ?? false) ||
        (quote.customerName?.toLowerCase().contains(searchTerm) ?? false) ||
        (quote.customer?.name.toLowerCase().contains(searchTerm) ?? false) ||
        Constants.getQuoteStatusDisplay(
          quote.status,
        ).toLowerCase().contains(searchTerm) ||
        (quote.notes?.toLowerCase().contains(searchTerm) ?? false);
  }

  static bool filterByStatus(Quote quote, String status) {
    if (status.isEmpty) return true;
    return quote.status == status;
  }

  static bool filterByDateRange(Quote quote, DateTime start, DateTime end) {
    if (quote.createdAt == null) return false;
    return quote.createdAt!.isAfter(start) && quote.createdAt!.isBefore(end);
  }

  // ============= TO STRING =============
  @override
  String toString() {
    return 'Quote(id: $id, number: $quoteNumber, status: $status, total: $grandTotal)';
  }
}

// ============= EXTENSIONS =============
extension QuoteListExtensions on List<Quote> {
  List<Quote> search(String query) {
    if (query.isEmpty) return this;
    return where((quote) => Quote.filterBySearch(quote, query)).toList();
  }

  List<Quote> filterByStatus(String status) {
    if (status.isEmpty) return this;
    return where((quote) => quote.status == status).toList();
  }

  List<Quote> filterByDateRange(DateTime start, DateTime end) {
    return where(
      (quote) => Quote.filterByDateRange(quote, start, end),
    ).toList();
  }

  List<Quote> sortByNumber() {
    final sorted = List<Quote>.from(this);
    sorted.sort(Quote.compareByNumber);
    return sorted;
  }

  List<Quote> sortByDate() {
    final sorted = List<Quote>.from(this);
    sorted.sort(Quote.compareByDate);
    return sorted;
  }

  List<Quote> sortByStatus() {
    final sorted = List<Quote>.from(this);
    sorted.sort(Quote.compareByStatus);
    return sorted;
  }

  List<Quote> sortByTotal() {
    final sorted = List<Quote>.from(this);
    sorted.sort(Quote.compareByTotal);
    return sorted;
  }

  List<Quote> get drafts => where((q) => q.isDraft).toList();
  List<Quote> get sent => where((q) => q.isSent).toList();
  List<Quote> get approved => where((q) => q.isApproved).toList();
  List<Quote> get converted => where((q) => q.isConverted).toList();
  List<Quote> get rejected => where((q) => q.isRejected).toList();
  List<Quote> get expired => where((q) => q.isExpired).toList();
  List<Quote> get active => where((q) => q.isActive).toList();
  List<Quote> get overdue => where((q) => q.isOverdue).toList();

  double get totalGrandTotal => fold(0, (sum, quote) => sum + quote.grandTotal);

  double get averageTotal => isEmpty ? 0 : totalGrandTotal / length;
}
