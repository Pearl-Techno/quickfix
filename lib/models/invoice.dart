import 'package:flutter/material.dart';
import 'package:quickfix/config/constants.dart';
import 'package:quickfix/models/customer.dart';
import 'package:quickfix/models/quote.dart';

class Invoice {
  final String id;
  final String invoiceNumber;
  final String quoteId;
  final String customerId;
  final double subtotal;
  final double tax;
  final double discount;
  final double total;
  final double amountPaid;
  final double balanceDue;
  final String paymentStatus;
  final DateTime? paymentDate;
  final DateTime? dueDate;
  final DateTime? issuedDate;
  final String? scope;
  final String? notes;
  final String? terms;
  final String? currency;
  final bool isVoid;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? customerName; // For display
  final String? quoteNumber; // For display
  final Customer? customer; // Full customer object
  final Quote? quote; // Full quote object

  Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.quoteId,
    required this.customerId,
    this.subtotal = 0,
    this.tax = 0,
    this.discount = 0,
    required this.total,
    this.amountPaid = 0,
    this.balanceDue = 0,
    this.paymentStatus = Constants.invoiceStatusUnpaid,
    this.paymentDate,
    this.dueDate,
    this.issuedDate,
    this.scope,
    this.notes,
    this.terms,
    this.currency = 'KES',
    this.isVoid = false,
    this.createdAt,
    this.updatedAt,
    this.customerName,
    this.quoteNumber,
    this.customer,
    this.quote,
  });

  // ============= FACTORY METHODS =============
  factory Invoice.fromJson(Map<String, dynamic> json) {
    Customer? customerObj;
    if (json['customers'] != null) {
      customerObj = Customer.fromJson(json['customers']);
    }

    Quote? quoteObj;
    if (json['quotes'] != null) {
      quoteObj = Quote.fromJson(json['quotes']);
    }

    return Invoice(
      id: json['id']?.toString() ?? '',
      invoiceNumber: json['invoice_number']?.toString() ?? '',
      quoteId: json['quote_id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      tax: (json['tax'] ?? 0).toDouble(),
      discount: (json['discount'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      amountPaid: (json['amount_paid'] ?? 0).toDouble(),
      balanceDue: (json['balance_due'] ?? json['total'] ?? 0).toDouble(),
      paymentStatus:
          json['payment_status']?.toString() ?? Constants.invoiceStatusUnpaid,
      paymentDate: _parseDateTime(json['payment_date']),
      dueDate: _parseDateTime(json['due_date']),
      issuedDate: _parseDateTime(json['issued_date']),
      scope: json['scope']?.toString(),
      notes: json['notes']?.toString(),
      terms: json['terms']?.toString(),
      currency: json['currency']?.toString() ?? 'KES',
      isVoid: json['is_void'] == 1 || json['is_void'] == true,
      createdAt: _parseDateTime(json['created_at']) ??
          _parseDateTime(json['issued_date']) ??
          _parseDateTime(json['due_date']) ??
          DateTime.now(),
      updatedAt: _parseDateTime(json['updated_at']) ??
          _parseDateTime(json['created_at']) ??
          DateTime.now(),
      customerName: customerObj?.name ?? json['customer_name']?.toString(),
      quoteNumber: quoteObj?.quoteNumber ?? json['quote_number']?.toString(),
      customer: customerObj,
      quote: quoteObj,
    );
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id']?.toString() ?? '',
      invoiceNumber: map['invoice_number']?.toString() ?? '',
      quoteId: map['quote_id']?.toString() ?? '',
      customerId: map['customer_id']?.toString() ?? '',
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      tax: (map['tax'] ?? 0).toDouble(),
      discount: (map['discount'] ?? 0).toDouble(),
      total: (map['total'] ?? 0).toDouble(),
      amountPaid: (map['amount_paid'] ?? 0).toDouble(),
      balanceDue: (map['balance_due'] ?? map['total'] ?? 0).toDouble(),
      paymentStatus:
          map['payment_status']?.toString() ?? Constants.invoiceStatusUnpaid,
      paymentDate: _parseDateTime(map['payment_date']),
      dueDate: _parseDateTime(map['due_date']),
      issuedDate: _parseDateTime(map['issued_date']),
      scope: map['scope']?.toString(),
      notes: map['notes']?.toString(),
      terms: map['terms']?.toString(),
      currency: map['currency']?.toString() ?? 'KES',
      isVoid: map['is_void'] == 1 || map['is_void'] == true,
      createdAt: _parseDateTime(map['created_at']) ??
          _parseDateTime(map['issued_date']) ??
          _parseDateTime(map['due_date']) ??
          DateTime.now(),
      updatedAt: _parseDateTime(map['updated_at']) ??
          _parseDateTime(map['created_at']) ??
          DateTime.now(),
      customerName: map['customer_name']?.toString(),
      quoteNumber: map['quote_number']?.toString(),
    );
  }

  factory Invoice.empty() {
    return Invoice(
      id: '',
      invoiceNumber: '',
      quoteId: '',
      customerId: '',
      total: 0,
    );
  }

  // ============= JSON SERIALIZATION (for API) =============
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'quote_id': quoteId,
      'customer_id': customerId,
      'subtotal': subtotal,
      'tax': tax,
      'total': total,
      'amount_paid': amountPaid,
      'balance_due': balanceDue,
      'payment_status': paymentStatus,
      'payment_date': paymentDate?.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'issued_date': issuedDate?.toIso8601String(),
      'scope': scope,
      'notes': notes,
      'terms': terms,
      'currency': currency,
      'is_void': isVoid, // Keep as bool for API
    };
  }

  // ============= DATABASE SERIALIZATION (for local DB) =============
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'quote_id': quoteId,
      'customer_id': customerId,
      'subtotal': subtotal,
      'tax': tax,
      'discount': discount,
      'total': total,
      'amount_paid': amountPaid,
      'balance_due': balanceDue,
      'payment_status': paymentStatus,
      'payment_date': paymentDate?.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'issued_date': issuedDate?.toIso8601String(),
      'scope': scope,
      'notes': notes,
      'terms': terms,
      'currency': currency,
      'is_void': isVoid
          ? 1
          : 0, // CRITICAL FIX: Convert bool to int for database
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // ============= COPY WITH =============
  Invoice copyWith({
    String? id,
    String? invoiceNumber,
    String? quoteId,
    String? customerId,
    double? subtotal,
    double? tax,
    double? discount,
    double? total,
    double? amountPaid,
    double? balanceDue,
    String? paymentStatus,
    DateTime? paymentDate,
    DateTime? dueDate,
    DateTime? issuedDate,
    String? scope,
    String? notes,
    String? terms,
    String? currency,
    bool? isVoid,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? customerName,
    String? quoteNumber,
    Customer? customer,
    Quote? quote,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      quoteId: quoteId ?? this.quoteId,
      customerId: customerId ?? this.customerId,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      amountPaid: amountPaid ?? this.amountPaid,
      balanceDue: balanceDue ?? this.balanceDue,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentDate: paymentDate ?? this.paymentDate,
      dueDate: dueDate ?? this.dueDate,
      issuedDate: issuedDate ?? this.issuedDate,
      scope: scope ?? this.scope,
      notes: notes ?? this.notes,
      terms: terms ?? this.terms,
      currency: currency ?? this.currency,
      isVoid: isVoid ?? this.isVoid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customerName: customerName ?? this.customerName,
      quoteNumber: quoteNumber ?? this.quoteNumber,
      customer: customer ?? this.customer,
      quote: quote ?? this.quote,
    );
  }

  // ============= PAYMENT STATUS CHECKS =============
  bool get isUnpaid => paymentStatus == Constants.invoiceStatusUnpaid;
  bool get isPartial => paymentStatus == Constants.invoiceStatusPartial;
  bool get isPaid => paymentStatus == Constants.invoiceStatusPaid;
  bool get isOverdue =>
      dueDate != null && dueDate!.isBefore(DateTime.now()) && !isPaid;
  bool get isVoided => isVoid;
  bool get isActive => !isVoided && !isPaid;

  bool get isPayable => !isPaid && !isVoided;
  bool get canRecordPayment => !isPaid && !isVoided && total > 0;
  bool get canVoid => !isVoided && !isPaid;

  // ============= CALCULATIONS =============
  double get paidPercentage {
    if (total <= 0) return 0;
    return (amountPaid / total) * 100;
  }

  double get remainingPercentage {
    if (total <= 0) return 0;
    return ((total - amountPaid) / total) * 100;
  }

  double get taxAmount => subtotal * Constants.taxRate;
  double get discountAmount => subtotal * (discount / 100);
  double get calculatedSubtotal => subtotal - discountAmount;
  double get calculatedTotal => calculatedSubtotal + taxAmount;
  double get calculatedBalanceDue => total - amountPaid;

  // ============= VALIDATION =============
  bool get isValid {
    return id.isNotEmpty &&
        invoiceNumber.isNotEmpty &&
        quoteId.isNotEmpty &&
        customerId.isNotEmpty &&
        total > 0;
  }

  bool get hasNotes => notes != null && notes!.isNotEmpty;
  bool get hasTerms => terms != null && terms!.isNotEmpty;
  bool get hasCustomer => customer != null;
  bool get hasQuote => quote != null;
  bool get hasPaymentDate => paymentDate != null;

  bool get isPaymentComplete => amountPaid >= total;
  bool get hasPartialPayment => amountPaid > 0 && amountPaid < total;

  // ============= DISPLAY PROPERTIES =============
  String get displayStatus => Constants.getInvoiceStatusDisplay(paymentStatus);

  Color get statusColor => Constants.getInvoiceStatusColor(paymentStatus);

  IconData get statusIcon => Constants.getInvoiceStatusIcon(paymentStatus);

  String get displayTotal => formatCurrency(total);
  String get displaySubtotal => formatCurrency(subtotal);
  String get displayTax => formatCurrency(tax);
  String get displayDiscount => formatCurrency(discount);
  String get displayAmountPaid => formatCurrency(amountPaid);
  String get displayBalanceDue => formatCurrency(balanceDue);

  String get displayCreatedAt {
    if (createdAt == null) return 'N/A';
    return Constants.formatDate(createdAt!);
  }

  String get displayUpdatedAt {
    if (updatedAt == null) return 'N/A';
    return Constants.formatDate(updatedAt!);
  }

  String get displayDueDate {
    if (dueDate == null) return 'N/A';
    return Constants.formatDate(dueDate!);
  }

  String get displayIssuedDate {
    if (issuedDate == null) return 'N/A';
    return Constants.formatDate(issuedDate!);
  }

  String get displayPaymentDate {
    if (paymentDate == null) return 'Not paid yet';
    return Constants.formatDate(paymentDate!);
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
    if (dueDate == null) return 'N/A';
    final days = DateTime.now().difference(dueDate!).inDays;
    if (days < 0) return 'Overdue by ${days.abs()} days';
    if (days == 0) return 'Due today';
    return '$days day${days > 1 ? 's' : ''} remaining';
  }

  String get displayPaymentProgress {
    return '${paidPercentage.toStringAsFixed(0)}% paid';
  }

  // ============= FORMATTED INFO =============
  String get formattedSummary {
    final parts = <String>[];
    parts.add('Invoice #$invoiceNumber');
    parts.add('Status: $displayStatus');
    parts.add('Customer: ${customerName ?? customer?.name ?? 'N/A'}');
    parts.add('Total: $displayTotal');
    parts.add('Paid: $displayAmountPaid');
    parts.add('Balance: $displayBalanceDue');
    parts.add('Due: $displayDueDate');
    if (isOverdue) parts.add('⚠️ OVERDUE!');
    return parts.join('\n');
  }

  String get formattedPaymentInfo {
    final parts = <String>[];
    parts.add('Invoice #$invoiceNumber');
    parts.add('Total: $displayTotal');
    parts.add('Amount Paid: $displayAmountPaid');
    parts.add('Balance Due: $displayBalanceDue');
    parts.add('Payment Status: $displayStatus');
    parts.add('Progress: $displayPaymentProgress');
    if (isOverdue) {
      parts.add('⚠️ OVERDUE - $displayDaysRemaining');
    }
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

  Invoice recordPayment(double amount) {
    final newAmountPaid = (amountPaid + amount).clamp(0.0, total);
    final newBalanceDue = total - newAmountPaid;
    final newStatus = _determinePaymentStatus(newAmountPaid, total);

    return copyWith(
      amountPaid: newAmountPaid,
      balanceDue: newBalanceDue,
      paymentStatus: newStatus,
      paymentDate: newStatus == Constants.invoiceStatusPaid
          ? DateTime.now()
          : paymentDate,
      updatedAt: DateTime.now(),
    );
  }

  String _determinePaymentStatus(double amountPaid, double total) {
    if (amountPaid >= total) {
      return Constants.invoiceStatusPaid;
    } else if (amountPaid > 0) {
      return Constants.invoiceStatusPartial;
    } else {
      return Constants.invoiceStatusUnpaid;
    }
  }

  Invoice voidInvoice() {
    return copyWith(
      isVoid: true,
      paymentStatus: Constants.invoiceStatusUnpaid,
      updatedAt: DateTime.now(),
    );
  }

  Invoice unvoidInvoice() {
    return copyWith(isVoid: false, updatedAt: DateTime.now());
  }

  // ============= COMPARISON =============
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Invoice && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // ============= SORTING & FILTERING =============
  static int compareByNumber(Invoice a, Invoice b) {
    return a.invoiceNumber.compareTo(b.invoiceNumber);
  }

  static int compareByDate(Invoice a, Invoice b) {
    final aDate = a.createdAt ?? DateTime(1970);
    final bDate = b.createdAt ?? DateTime(1970);
    return bDate.compareTo(aDate);
  }

  static int compareByDueDate(Invoice a, Invoice b) {
    final aDate = a.dueDate ?? DateTime(2970);
    final bDate = b.dueDate ?? DateTime(2970);
    return aDate.compareTo(bDate);
  }

  static int compareByTotal(Invoice a, Invoice b) {
    return a.total.compareTo(b.total);
  }

  static int compareByStatus(Invoice a, Invoice b) {
    final aPriority = Constants.invoiceStatusList.indexOf(a.paymentStatus);
    final bPriority = Constants.invoiceStatusList.indexOf(b.paymentStatus);
    return aPriority.compareTo(bPriority);
  }

  static bool filterBySearch(Invoice invoice, String query) {
    if (query.isEmpty) return true;
    final searchTerm = query.toLowerCase();
    return invoice.invoiceNumber.toLowerCase().contains(searchTerm) ||
        (invoice.customerName?.toLowerCase().contains(searchTerm) ?? false) ||
        (invoice.customer?.name.toLowerCase().contains(searchTerm) ?? false) ||
        (invoice.quoteNumber?.toLowerCase().contains(searchTerm) ?? false) ||
        Constants.getInvoiceStatusDisplay(
          invoice.paymentStatus,
        ).toLowerCase().contains(searchTerm) ||
        (invoice.notes?.toLowerCase().contains(searchTerm) ?? false);
  }

  static bool filterByStatus(Invoice invoice, String status) {
    if (status.isEmpty) return true;
    return invoice.paymentStatus == status;
  }

  static bool filterByDateRange(Invoice invoice, DateTime start, DateTime end) {
    if (invoice.createdAt == null) return false;
    return invoice.createdAt!.isAfter(start) &&
        invoice.createdAt!.isBefore(end);
  }

  // ============= TO STRING =============
  @override
  String toString() {
    return 'Invoice(id: $id, number: $invoiceNumber, status: $paymentStatus, total: $total)';
  }
}

// ============= EXTENSIONS =============
extension InvoiceListExtensions on List<Invoice> {
  List<Invoice> search(String query) {
    if (query.isEmpty) return this;
    return where((invoice) => Invoice.filterBySearch(invoice, query)).toList();
  }

  List<Invoice> filterByStatus(String status) {
    if (status.isEmpty) return this;
    return where((invoice) => invoice.paymentStatus == status).toList();
  }

  List<Invoice> filterByDateRange(DateTime start, DateTime end) {
    return where(
      (invoice) => Invoice.filterByDateRange(invoice, start, end),
    ).toList();
  }

  List<Invoice> sortByNumber() {
    final sorted = List<Invoice>.from(this);
    sorted.sort(Invoice.compareByNumber);
    return sorted;
  }

  List<Invoice> sortByDate() {
    final sorted = List<Invoice>.from(this);
    sorted.sort(Invoice.compareByDate);
    return sorted;
  }

  List<Invoice> sortByDueDate() {
    final sorted = List<Invoice>.from(this);
    sorted.sort(Invoice.compareByDueDate);
    return sorted;
  }

  List<Invoice> sortByTotal() {
    final sorted = List<Invoice>.from(this);
    sorted.sort(Invoice.compareByTotal);
    return sorted;
  }

  List<Invoice> sortByStatus() {
    final sorted = List<Invoice>.from(this);
    sorted.sort(Invoice.compareByStatus);
    return sorted;
  }

  List<Invoice> get unpaid => where((i) => i.isUnpaid).toList();
  List<Invoice> get partial => where((i) => i.isPartial).toList();
  List<Invoice> get paid => where((i) => i.isPaid).toList();
  List<Invoice> get overdue => where((i) => i.isOverdue).toList();
  List<Invoice> get voided => where((i) => i.isVoided).toList();
  List<Invoice> get active => where((i) => i.isActive).toList();
  List<Invoice> get payable => where((i) => i.isPayable).toList();

  double get totalAmount => fold(0, (sum, invoice) => sum + invoice.total);
  double get totalPaid => fold(0, (sum, invoice) => sum + invoice.amountPaid);
  double get totalBalance =>
      fold(0, (sum, invoice) => sum + invoice.balanceDue);

  double get averageAmount => isEmpty ? 0 : totalAmount / length;
  double get collectionRate {
    if (totalAmount <= 0) return 0;
    return (totalPaid / totalAmount) * 100;
  }
}
