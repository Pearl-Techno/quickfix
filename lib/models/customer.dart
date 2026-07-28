import 'package:flutter/material.dart';
import 'package:quickfix/config/constants.dart';

class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? siteLocation;
  final String? siteNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.siteLocation,
    this.siteNotes,
    this.createdAt,
    this.updatedAt,
  });

  // ============= FACTORY METHODS =============
  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      address: json['address']?.toString(),
      siteLocation: json['site_location']?.toString(),
      siteNotes: json['site_notes']?.toString(),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  factory Customer.empty() {
    return Customer(id: '', name: '');
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      address: map['address']?.toString(),
      siteLocation: map['site_location']?.toString(),
      siteNotes: map['site_notes']?.toString(),
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  // ============= JSON SERIALIZATION =============
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'site_location': siteLocation,
      'site_notes': siteNotes,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'site_location': siteLocation,
      'site_notes': siteNotes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // ============= COPY WITH =============
  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? siteLocation,
    String? siteNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      siteLocation: siteLocation ?? this.siteLocation,
      siteNotes: siteNotes ?? this.siteNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ============= VALIDATION METHODS =============
  bool get isValid {
    return id.isNotEmpty && name.isNotEmpty;
  }

  bool get hasPhone => phone != null && phone!.isNotEmpty;
  bool get hasEmail => email != null && email!.isNotEmpty;
  bool get hasAddress => address != null && address!.isNotEmpty;
  bool get hasSiteLocation => siteLocation != null && siteLocation!.isNotEmpty;
  bool get hasSiteNotes => siteNotes != null && siteNotes!.isNotEmpty;

  bool get isEmailValid {
    if (!hasEmail) return false;
    return Constants.isValidEmail(email!);
  }

  bool get isPhoneValid {
    if (!hasPhone) return false;
    return Constants.isValidPhone(phone!);
  }

  // ============= DISPLAY PROPERTIES =============
  String get displayName => name;

  String get displayPhone => hasPhone ? phone! : 'No phone';

  String get displayEmail => hasEmail ? email! : 'No email';

  String get displayAddress => hasAddress ? address! : 'No address';

  String get displaySiteLocation =>
      hasSiteLocation ? siteLocation! : 'No site location';

  String get displayShortName {
    if (name.length <= 20) return name;
    return '${name.substring(0, 20)}...';
  }

  String get displayInitials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    return '${parts[0].substring(0, 1)}${parts[parts.length - 1].substring(0, 1)}'
        .toUpperCase();
  }

  Color get displayColor {
    // Generate a consistent color based on the name
    final hash = name.hashCode.abs();
    final hue = hash % 360;
    return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.7, 0.6).toColor();
  }

  String get displayCreatedAt {
    if (createdAt == null) return 'N/A';
    return Constants.formatDate(createdAt!);
  }

  String get displayUpdatedAt {
    if (updatedAt == null) return 'N/A';
    return Constants.formatDate(updatedAt!);
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

  // ============= FORMATTED CONTACT INFO =============
  String get formattedContactInfo {
    final parts = <String>[];
    if (hasPhone) parts.add(phone!);
    if (hasEmail) parts.add(email!);
    return parts.join(' • ');
  }

  String get formattedAddress {
    final parts = <String>[];
    if (hasAddress) parts.add(address!);
    if (hasSiteLocation) parts.add(siteLocation!);
    return parts.join(' • ');
  }

  String get formattedFullInfo {
    final parts = <String>[];
    parts.add('Name: $name');
    if (hasPhone) parts.add('Phone: $phone');
    if (hasEmail) parts.add('Email: $email');
    if (hasAddress) parts.add('Address: $address');
    if (hasSiteLocation) parts.add('Site: $siteLocation');
    if (hasSiteNotes) parts.add('Notes: $siteNotes');
    return parts.join('\n');
  }

  // ============= COMPARISON =============
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Customer && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // ============= HELPER METHODS =============
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    try {
      if (value is DateTime) return value;
      if (value is String) {
        // Try parsing ISO format
        return DateTime.parse(value);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ============= SORTING & FILTERING =============
  static int compareByName(Customer a, Customer b) {
    return a.name.compareTo(b.name);
  }

  static int compareByDate(Customer a, Customer b) {
    final aDate = a.createdAt ?? DateTime(1970);
    final bDate = b.createdAt ?? DateTime(1970);
    return bDate.compareTo(aDate); // Newest first
  }

  static bool filterBySearch(Customer customer, String query) {
    if (query.isEmpty) return true;
    final searchTerm = query.toLowerCase();
    return customer.name.toLowerCase().contains(searchTerm) ||
        (customer.phone?.toLowerCase().contains(searchTerm) ?? false) ||
        (customer.email?.toLowerCase().contains(searchTerm) ?? false) ||
        (customer.address?.toLowerCase().contains(searchTerm) ?? false);
  }

  // ============= TO STRING =============
  @override
  String toString() {
    return 'Customer(id: $id, name: $name, phone: $phone, email: $email)';
  }
}

// ============= EXTENSIONS =============
extension CustomerListExtensions on List<Customer> {
  List<Customer> search(String query) {
    if (query.isEmpty) return this;
    return where(
      (customer) => Customer.filterBySearch(customer, query),
    ).toList();
  }

  List<Customer> sortByName() {
    final sorted = List<Customer>.from(this);
    sorted.sort(Customer.compareByName);
    return sorted;
  }

  List<Customer> sortByDate() {
    final sorted = List<Customer>.from(this);
    sorted.sort(Customer.compareByDate);
    return sorted;
  }

  List<Customer> get withPhone => where((c) => c.hasPhone).toList();
  List<Customer> get withEmail => where((c) => c.hasEmail).toList();
  List<Customer> get withAddress => where((c) => c.hasAddress).toList();
}
