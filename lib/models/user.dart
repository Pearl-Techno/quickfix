import 'package:flutter/material.dart';
import 'package:quickfix/config/app_colors.dart';
import 'package:quickfix/config/constants.dart';

class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final String? avatarUrl;
  final bool isActive;
  final DateTime? lastLogin;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.avatarUrl,
    this.isActive = true,
    this.lastLogin,
    this.createdAt,
    this.updatedAt,
  });

  // ============= FACTORY METHODS =============
  factory User.fromJson(Map<String, dynamic> json) {
    final rawIsActive = json['is_active'];
    bool isActiveBool = true;
    if (rawIsActive is bool) {
      isActiveBool = rawIsActive;
    } else if (rawIsActive is int) {
      isActiveBool = rawIsActive == 1;
    } else if (rawIsActive is String) {
      isActiveBool = rawIsActive == '1' || rawIsActive.toLowerCase() == 'true';
    }

    return User(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? Constants.roleTechnician,
      phone: json['phone']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      isActive: isActiveBool,
      lastLogin: _parseDateTime(json['last_login']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  factory User.empty() {
    return User(id: '', name: '', email: '', role: Constants.roleTechnician);
  }

  factory User.fromMap(Map<String, dynamic> map) {
    final rawIsActive = map['is_active'];
    bool isActiveBool = true;
    if (rawIsActive is bool) {
      isActiveBool = rawIsActive;
    } else if (rawIsActive is int) {
      isActiveBool = rawIsActive == 1;
    } else if (rawIsActive is String) {
      isActiveBool = rawIsActive == '1' || rawIsActive.toLowerCase() == 'true';
    }

    return User(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      role: map['role']?.toString() ?? Constants.roleTechnician,
      phone: map['phone']?.toString(),
      avatarUrl: map['avatar_url']?.toString(),
      isActive: isActiveBool,
      lastLogin: _parseDateTime(map['last_login']),
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  // ============= JSON SERIALIZATION =============
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'avatar_url': avatarUrl,
      'is_active': isActive,
      'last_login': lastLogin?.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'avatar_url': avatarUrl,
      'is_active': isActive,
      'last_login': lastLogin?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // ============= COPY WITH =============
  User copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? phone,
    String? avatarUrl,
    bool? isActive,
    DateTime? lastLogin,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isActive: isActive ?? this.isActive,
      lastLogin: lastLogin ?? this.lastLogin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ============= ROLE CHECK METHODS =============
  bool get isSuperAdmin => role == Constants.roleSuperadmin;
  bool get isAdmin => role == Constants.roleAdmin || role == Constants.roleSuperadmin;
  bool get isManager => role == Constants.roleManager;
  bool get isTechnician => role == Constants.roleTechnician;
  bool get isViewer => role == Constants.roleViewer;

  bool get isAdminOrManager => isAdmin || isManager;
  bool get isTechnicianOrAdmin => isTechnician || isAdmin;

  bool hasPermission(String requiredRole) {
    final priority = Constants.rolePriority[role] ?? 0;
    final requiredPriority = Constants.rolePriority[requiredRole] ?? 0;
    return priority >= requiredPriority;
  }

  bool get canManageUsers => isAdmin || isManager;
  bool get canManageQuotes => isAdmin || isManager || isTechnician;
  bool get canManageInvoices => isAdmin || isManager;
  bool get canManageCustomers => isAdmin || isManager || isTechnician;
  bool get canManageProducts => isAdmin || isManager;
  bool get canViewReports => isAdmin || isManager;

  // ============= VALIDATION METHODS =============
  bool get isValid {
    return id.isNotEmpty &&
        name.isNotEmpty &&
        email.isNotEmpty &&
        role.isNotEmpty;
  }

  bool get hasPhone => phone != null && phone!.isNotEmpty;
  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;

  bool get isEmailValid => Constants.isValidEmail(email);
  bool get isPhoneValid {
    if (!hasPhone) return false;
    return Constants.isValidPhone(phone!);
  }

  // ============= DISPLAY PROPERTIES =============
  String get displayName => name;

  String get displayEmail {
    if (email.endsWith('@quickfix.local')) {
      return email.split('@').first;
    }
    return email;
  }

  String get displayPhone => hasPhone ? phone! : 'No phone';

  String get displayRole {
    return Constants.getRoleDisplay(role);
  }

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

  Color get roleColor {
    switch (role) {
      case Constants.roleSuperadmin:
        return const Color(0xFF7C3AED); // Deep Violet
      case Constants.roleAdmin:
        return AppColors.error;
      case Constants.roleManager:
        return AppColors.warning;
      case Constants.roleTechnician:
        return AppColors.info;
      case Constants.roleViewer:
        return AppColors.textLight;
      default:
        return AppColors.textLight;
    }
  }

  IconData get roleIcon {
    switch (role) {
      case Constants.roleSuperadmin:
        return Icons.security;
      case Constants.roleAdmin:
        return Icons.admin_panel_settings;
      case Constants.roleManager:
        return Icons.manage_accounts;
      case Constants.roleTechnician:
        return Icons.build;
      case Constants.roleViewer:
        return Icons.visibility;
      default:
        return Icons.person;
    }
  }

  String get displayCreatedAt {
    if (createdAt == null) return 'N/A';
    return Constants.formatDate(createdAt!);
  }

  String get displayUpdatedAt {
    if (updatedAt == null) return 'N/A';
    return Constants.formatDate(updatedAt!);
  }

  String get displayLastLogin {
    if (lastLogin == null) return 'Never';
    return Constants.formatDateTime(lastLogin!);
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

  // ============= FORMATTED INFO =============
  String get formattedContactInfo {
    final parts = <String>[email];
    if (hasPhone) parts.add(phone!);
    return parts.join(' • ');
  }

  String get formattedFullInfo {
    final parts = <String>[];
    parts.add('Name: $name');
    parts.add('Email: $email');
    parts.add('Role: ${Constants.getRoleDisplay(role)}');
    if (hasPhone) parts.add('Phone: $phone');
    parts.add('Status: ${isActive ? 'Active' : 'Inactive'}');
    if (lastLogin != null) {
      parts.add('Last Login: $displayLastLogin');
    }
    parts.add('Joined: $displayCreatedAt');
    return parts.join('\n');
  }

  // ============= COMPARISON =============
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

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

  // ============= SORTING & FILTERING =============
  static int compareByName(User a, User b) {
    return a.name.compareTo(b.name);
  }

  static int compareByRole(User a, User b) {
    final aPriority = Constants.rolePriority[a.role] ?? 0;
    final bPriority = Constants.rolePriority[b.role] ?? 0;
    return bPriority.compareTo(aPriority); // Higher priority first
  }

  static int compareByDate(User a, User b) {
    final aDate = a.createdAt ?? DateTime(1970);
    final bDate = b.createdAt ?? DateTime(1970);
    return bDate.compareTo(aDate); // Newest first
  }

  static bool filterBySearch(User user, String query) {
    if (query.isEmpty) return true;
    final searchTerm = query.toLowerCase();
    return user.name.toLowerCase().contains(searchTerm) ||
        user.email.toLowerCase().contains(searchTerm) ||
        (user.phone?.toLowerCase().contains(searchTerm) ?? false) ||
        Constants.getRoleDisplay(user.role).toLowerCase().contains(searchTerm);
  }

  // ============= TO STRING =============
  @override
  String toString() {
    return 'User(id: $id, name: $name, email: $email, role: $role)';
  }
}

// ============= EXTENSIONS =============
extension UserListExtensions on List<User> {
  List<User> search(String query) {
    if (query.isEmpty) return this;
    return where((user) => User.filterBySearch(user, query)).toList();
  }

  List<User> sortByName() {
    final sorted = List<User>.from(this);
    sorted.sort(User.compareByName);
    return sorted;
  }

  List<User> sortByRole() {
    final sorted = List<User>.from(this);
    sorted.sort(User.compareByRole);
    return sorted;
  }

  List<User> sortByDate() {
    final sorted = List<User>.from(this);
    sorted.sort(User.compareByDate);
    return sorted;
  }

  List<User> get admins => where((u) => u.isAdmin).toList();
  List<User> get managers => where((u) => u.isManager).toList();
  List<User> get technicians => where((u) => u.isTechnician).toList();
  List<User> get viewers => where((u) => u.isViewer).toList();
  List<User> get active => where((u) => u.isActive).toList();
  List<User> get inactive => where((u) => !u.isActive).toList();
  List<User> get withPhone => where((u) => u.hasPhone).toList();
}

// ============= USER ROLE EXTENSION =============
extension UserRoleExtension on String {
  bool get isAdminRole => this == Constants.roleAdmin;
  bool get isManagerRole => this == Constants.roleManager;
  bool get isTechnicianRole => this == Constants.roleTechnician;
  bool get isViewerRole => this == Constants.roleViewer;

  String get displayRole => Constants.getRoleDisplay(this);

  Color get roleColor {
    switch (this) {
      case Constants.roleAdmin:
        return AppColors.error;
      case Constants.roleManager:
        return AppColors.warning;
      case Constants.roleTechnician:
        return AppColors.info;
      case Constants.roleViewer:
        return AppColors.textLight;
      default:
        return AppColors.textLight;
    }
  }

  IconData get roleIcon {
    switch (this) {
      case Constants.roleAdmin:
        return Icons.admin_panel_settings;
      case Constants.roleManager:
        return Icons.manage_accounts;
      case Constants.roleTechnician:
        return Icons.build;
      case Constants.roleViewer:
        return Icons.visibility;
      default:
        return Icons.person;
    }
  }
}
