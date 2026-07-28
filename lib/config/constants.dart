// lib/config/constants.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quickfix/config/app_colors.dart';

class Constants {
  // ============= APP INFO =============
  static const String appName = 'Quickfix';
  static const String appVersion = '1.0.0';
  static const String appPackageName = 'com.quickfix.app';
  static const String appWebsite = 'https://quickfix.com';
  static const String appEmail = 'support@quickfix.com';
  static const String appPhone = '+254 700 000 000';

  // ============= BUSINESS RULES =============
  static const int defaultQuoteValidityDays = 14;
  static const double taxRate = 0.16; // 16% VAT
  static const double defaultDiscount = 0.0;
  static const double maxDiscount = 0.50; // 50% maximum discount
  static const int minQuoteItems = 1;
  static const int maxQuoteItems = 100;
  static const int itemsPerPage = 20;

  // ============= DATE FORMATS =============
  static const String dateFormat = 'dd/MM/yyyy';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';
  static const String timeFormat = 'HH:mm';
  static const String apiDateFormat = 'yyyy-MM-dd';
  static const String apiDateTimeFormat = 'yyyy-MM-ddTHH:mm:ss';
  static const String displayDateFormat = 'MMM dd, yyyy';
  static const String displayDateTimeFormat = 'MMM dd, yyyy • HH:mm';

  // ============= QUOTE STATUSES =============
  static const String quoteStatusDraft = 'draft';
  static const String quoteStatusSent = 'sent';
  static const String quoteStatusApproved = 'approved';
  static const String quoteStatusConverted = 'converted';
  static const String quoteStatusRejected = 'rejected';
  static const String quoteStatusExpired = 'expired';

  static const List<String> quoteStatusList = [
    quoteStatusDraft,
    quoteStatusSent,
    quoteStatusApproved,
    quoteStatusConverted,
    quoteStatusRejected,
    quoteStatusExpired,
  ];

  static const Map<String, String> quoteStatusDisplay = {
    quoteStatusDraft: 'Draft',
    quoteStatusSent: 'Sent',
    quoteStatusApproved: 'Approved',
    quoteStatusConverted: 'Converted',
    quoteStatusRejected: 'Rejected',
    quoteStatusExpired: 'Expired',
  };

  static const Map<String, Color> quoteStatusColors = {
    quoteStatusDraft: AppColors.draft,
    quoteStatusSent: AppColors.sent,
    quoteStatusApproved: AppColors.approved,
    quoteStatusConverted: AppColors.converted,
    quoteStatusRejected: AppColors.rejected,
    quoteStatusExpired: AppColors.warning,
  };

  static const Map<String, IconData> quoteStatusIcons = {
    quoteStatusDraft: Icons.edit_note,
    quoteStatusSent: Icons.send,
    quoteStatusApproved: Icons.check_circle,
    quoteStatusConverted: Icons.transform,
    quoteStatusRejected: Icons.cancel,
    quoteStatusExpired: Icons.timer_off,
  };

  static const Map<String, Color> quoteStatusBackgroundColors = {
    quoteStatusDraft: AppColors.draftBackground,
    quoteStatusSent: AppColors.sentBackground,
    quoteStatusApproved: AppColors.approvedBackground,
    quoteStatusConverted: AppColors.convertedBackground,
    quoteStatusRejected: AppColors.rejectedBackground,
    quoteStatusExpired: AppColors.warningBackground,
  };

  // ============= INVOICE STATUSES =============
  static const String invoiceStatusDraft = 'draft';
  static const String invoiceStatusUnpaid = 'unpaid';
  static const String invoiceStatusPartial = 'partial';
  static const String invoiceStatusPaid = 'paid';
  static const String invoiceStatusOverdue = 'overdue';

  static const List<String> invoiceStatusList = [
    invoiceStatusDraft,
    invoiceStatusUnpaid,
    invoiceStatusPartial,
    invoiceStatusPaid,
    invoiceStatusOverdue,
  ];

  static const Map<String, String> invoiceStatusDisplay = {
    invoiceStatusDraft: 'Draft',
    invoiceStatusUnpaid: 'Unpaid',
    invoiceStatusPartial: 'Partially Paid',
    invoiceStatusPaid: 'Paid',
    invoiceStatusOverdue: 'Overdue',
  };

  static const Map<String, Color> invoiceStatusColors = {
    invoiceStatusDraft: AppColors.draft,
    invoiceStatusUnpaid: AppColors.warning,
    invoiceStatusPartial: AppColors.info,
    invoiceStatusPaid: AppColors.success,
    invoiceStatusOverdue: AppColors.error,
  };

  static const Map<String, IconData> invoiceStatusIcons = {
    invoiceStatusDraft: Icons.edit_note,
    invoiceStatusUnpaid: Icons.pending_actions,
    invoiceStatusPartial: Icons.pending, // Fixed: Changed from partial_payment
    invoiceStatusPaid: Icons.payment,
    invoiceStatusOverdue: Icons.warning_amber,
  };

  // ============= ITEM TYPES =============
  static const String itemTypeStock = 'stock';
  static const String itemTypeOutsourced = 'outsourced';
  static const String itemTypeService = 'service';

  static const List<String> itemTypeList = [
    itemTypeStock,
    itemTypeOutsourced,
    itemTypeService,
  ];

  static const Map<String, String> itemTypeDisplay = {
    itemTypeStock: 'Stock Item',
    itemTypeOutsourced: 'Outsourced Service',
    itemTypeService: 'Service',
  };

  static const Map<String, IconData> itemTypeIcons = {
    itemTypeStock: Icons.inventory_2,
    itemTypeOutsourced: Icons.build_circle,
    itemTypeService: Icons.miscellaneous_services,
  };

  // ============= USER ROLES =============
  static const String roleSuperadmin = 'superadmin';
  static const String roleAdmin = 'admin';
  static const String roleTechnician = 'technician';
  static const String roleManager = 'manager';
  static const String roleViewer = 'viewer';

  static const List<String> roleList = [
    roleSuperadmin,
    roleAdmin,
    roleManager,
    roleTechnician,
    roleViewer,
  ];

  static const Map<String, String> roleDisplay = {
    roleSuperadmin: 'Super Admin',
    roleAdmin: 'Administrator',
    roleManager: 'Manager',
    roleTechnician: 'Technician',
    roleViewer: 'Viewer',
  };

  static const Map<String, int> rolePriority = {
    roleSuperadmin: 5,
    roleAdmin: 4,
    roleManager: 3,
    roleTechnician: 2,
    roleViewer: 1,
  };

  // ============= STORAGE BUCKETS =============
  static const String photosBucket = 'photos';
  static const String documentsBucket = 'documents';
  static const String invoicesBucket = 'invoices';
  static const String quotesBucket = 'quotes';
  static const String profilesBucket = 'profiles';

  // ============= API ENDPOINTS =============
  static const String apiBaseUrl = 'https://api.quickfix.com/v1';
  static const String apiAuthLogin = '/auth/login';
  static const String apiAuthRegister = '/auth/register';
  static const String apiAuthLogout = '/auth/logout';
  static const String apiAuthRefresh = '/auth/refresh';
  static const String apiUsers = '/users';
  static const String apiQuotes = '/quotes';
  static const String apiInvoices = '/invoices';
  static const String apiItems = '/items';
  static const String apiCustomers = '/customers';

  // ============= PAGINATION =============
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  static const int defaultPage = 1;

  // ============= ANIMATION DURATIONS =============
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  static const Duration animationVerySlow = Duration(milliseconds: 800);
  static const Duration snackBarDuration = Duration(seconds: 3);
  static const Duration snackBarLongDuration = Duration(seconds: 5);

  // ============= VALIDATION CONSTANTS =============
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 32;
  static const int maxNameLength = 50;
  static const int maxEmailLength = 100;
  static const int maxPhoneLength = 15;
  static const int maxAddressLength = 200;
  static const int maxDescriptionLength = 500;
  static const int maxNotesLength = 1000;

  // ============= CURRENCY =============
  static const String currencySymbol = 'KES';
  static const String currencyCode = 'KES';
  static const String currencyLocale = 'en-KE';
  static const int currencyDecimalPlaces = 2;

  // ============= SHARED PREFERENCES KEYS =============
  static const String prefAuthToken = 'auth_token';
  static const String prefRefreshToken = 'refresh_token';
  static const String prefUser = 'user';
  static const String prefTheme = 'theme_mode';
  static const String prefLanguage = 'language';
  static const String prefNotifications = 'notifications';
  static const String prefFirstLaunch = 'first_launch';
  static const String prefLastSync = 'last_sync';

  // ============= REGEX PATTERNS =============
  static const String emailPattern = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
  static const String phonePattern = r'^\+?[0-9]{10,15}$';
  static const String passwordPattern =
      r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d@$!%*#?&]{8,}$';

  // ============= FILE CONSTANTS =============
  static const int maxImageSizeInMB = 5;
  static const int maxDocumentSizeInMB = 10;
  static const List<String> allowedImageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
  ];
  static const List<String> allowedDocumentExtensions = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
  ];

  // ============= ERROR MESSAGES =============
  static const String errorGeneric = 'Something went wrong. Please try again.';
  static const String errorNetwork =
      'No internet connection. Please check your network.';
  static const String errorServer = 'Server error. Please try again later.';
  static const String errorUnauthorized =
      'You are not authorized to perform this action.';
  static const String errorNotFound = 'The requested resource was not found.';
  static const String errorValidation =
      'Please check your input and try again.';
  static const String errorTimeOut = 'Request timed out. Please try again.';
  static const String errorTooManyRequests =
      'Too many requests. Please try again later.';

  // ============= SUCCESS MESSAGES =============
  static const String successSave = 'Saved successfully.';
  static const String successDelete = 'Deleted successfully.';
  static const String successUpdate = 'Updated successfully.';
  static const String successSend = 'Sent successfully.';
  static const String successApprove = 'Approved successfully.';
  static const String successConvert = 'Converted successfully.';
  static const String successLogin = 'Logged in successfully.';
  static const String successLogout = 'Logged out successfully.';
  static const String successRegister = 'Registration successful.';

  // ============= HELPER METHODS =============
  static String getQuoteStatusDisplay(String status) {
    return quoteStatusDisplay[status] ?? status;
  }

  static Color getQuoteStatusColor(String status) {
    return quoteStatusColors[status] ?? AppColors.draft;
  }

  static IconData getQuoteStatusIcon(String status) {
    return quoteStatusIcons[status] ?? Icons.help;
  }

  static Color getQuoteStatusBackgroundColor(String status) {
    return quoteStatusBackgroundColors[status] ?? AppColors.background;
  }

  static String getInvoiceStatusDisplay(String status) {
    return invoiceStatusDisplay[status] ?? status;
  }

  static Color getInvoiceStatusColor(String status) {
    return invoiceStatusColors[status] ?? AppColors.textLight;
  }

  static IconData getInvoiceStatusIcon(String status) {
    return invoiceStatusIcons[status] ?? Icons.help;
  }

  static String getItemTypeDisplay(String type) {
    return itemTypeDisplay[type] ?? type;
  }

  static IconData getItemTypeIcon(String type) {
    return itemTypeIcons[type] ?? Icons.category;
  }

  static String getRoleDisplay(String role) {
    return roleDisplay[role] ?? role;
  }

  static bool isValidEmail(String email) {
    return RegExp(emailPattern).hasMatch(email);
  }

  static bool isValidPhone(String phone) {
    return RegExp(phonePattern).hasMatch(phone);
  }

  static bool isValidPassword(String password) {
    return RegExp(passwordPattern).hasMatch(password);
  }

  static String formatCurrency(double amount) {
    return '$currencySymbol ${amount.toStringAsFixed(currencyDecimalPlaces)}';
  }

  static String formatCurrencyWithCommas(double amount) {
    final formatter = NumberFormat.currency(
      symbol: currencySymbol,
      locale: currencyLocale,
      decimalDigits: currencyDecimalPlaces,
    );
    return formatter.format(amount);
  }

  static String formatDate(DateTime date, {String? format}) {
    final formatter = DateFormat(format ?? displayDateFormat);
    return formatter.format(date);
  }

  static String formatDateTime(DateTime date) {
    final formatter = DateFormat(displayDateTimeFormat);
    return formatter.format(date);
  }

  static String formatApiDate(DateTime date) {
    final formatter = DateFormat(apiDateFormat);
    return formatter.format(date);
  }

  static DateTime? parseApiDate(String dateString) {
    try {
      return DateFormat(apiDateFormat).parse(dateString);
    } catch (e) {
      return null;
    }
  }

  static DateTime? parseApiDateTime(String dateTimeString) {
    try {
      return DateFormat(apiDateTimeFormat).parse(dateTimeString);
    } catch (e) {
      return null;
    }
  }
}
