import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class Helpers {
  // Show snackbar message
  static void showSnackBar(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    int durationSeconds = 3,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? Colors.grey[800],
        duration: Duration(seconds: durationSeconds),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // Show success snackbar
  static void showSuccess(BuildContext context, String message) {
    showSnackBar(context, message, backgroundColor: Colors.green);
  }

  // Show error snackbar
  static void showError(BuildContext context, String message) {
    showSnackBar(context, message, backgroundColor: Colors.red);
  }

  // Show loading dialog
  static void showLoadingDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Text(message ?? 'Loading...'),
          ],
        ),
      ),
    );
  }

  // Hide loading dialog
  static void hideLoadingDialog(BuildContext context) {
    Navigator.of(context).pop();
  }

  // Generate cryptographically secure UUID v4 (for temporary/local use)
  static String generateId() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));

    // Set version to 4
    values[6] = (values[6] & 0x0f) | 0x40;
    // Set variant to RFC4122
    values[8] = (values[8] & 0x3f) | 0x80;

    final buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) {
        buffer.write('-');
      }
      buffer.write(values[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString().toLowerCase();
  }

  // Check if string is null or empty
  static bool isNullOrEmpty(String? str) {
    return str == null || str.trim().isEmpty;
  }

  // Format phone number
  static String formatPhoneNumber(String phone) {
    // Remove all non-digit characters
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');

    // If starts with 0, remove it
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }

    // Add 254 prefix if not present
    if (!cleaned.startsWith('254')) {
      cleaned = '254$cleaned';
    }

    return cleaned;
  }

  // Extract initials from name
  static String getInitials(String name) {
    if (name.isEmpty) return '?';

    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  // Truncate text with ellipsis
  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  // Get status color
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return Colors.grey;
      case 'sent':
        return Colors.blue;
      case 'approved':
        return Colors.green;
      case 'converted':
        return Colors.purple;
      case 'rejected':
        return Colors.red;
      case 'paid':
        return Colors.green;
      case 'unpaid':
        return Colors.orange;
      case 'partial':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  // Get status icon
  static IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return Icons.edit_note;
      case 'sent':
        return Icons.send;
      case 'approved':
        return Icons.check_circle;
      case 'converted':
        return Icons.receipt;
      case 'rejected':
        return Icons.cancel;
      case 'paid':
        return Icons.payment;
      case 'unpaid':
        return Icons.pending;
      case 'partial':
        return Icons.pending;
      default:
        return Icons.circle;
    }
  }

  // Capitalize first letter of each word
  static String capitalizeWords(String text) {
    if (text.isEmpty) return text;

    final words = text.split(' ');
    final capitalized = words.map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    });

    return capitalized.join(' ');
  }

  // Check if email is valid
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  // Check if phone is valid (Kenyan)
  static bool isValidKenyanPhone(String phone) {
    // Remove all non-digit characters
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');

    // Check if it's a valid Kenyan number
    // 07XX, 01XX, 2547XX, 2541XX
    final phoneRegex = RegExp(r'^(07|01|2547|2541)\d{8}$');
    return phoneRegex.hasMatch(cleaned);
  }

  // Get file extension from path
  static String getFileExtension(String path) {
    final parts = path.split('.');
    if (parts.length > 1) {
      return parts.last.toLowerCase();
    }
    return '';
  }

  // Check if file is an image
  static bool isImageFile(String path) {
    final extension = getFileExtension(path);
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension);
  }

  // Get device type
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= 600 &&
        MediaQuery.of(context).size.width < 1200;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1200;
  }

  // Safe cast to double
  static double toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  // Safe cast to int
  static int toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  // Download PDF file to C:\Quick fix\<Folder>
  static Future<File?> downloadPdfToLocalDisk(File sourceFile, String type) async {
    try {
      String basePath;
      if (Platform.isWindows) {
        basePath = 'C:\\Quick fix';
      } else {
        final temp = await getTemporaryDirectory();
        basePath = '${temp.path}/Quick fix';
      }

      final baseDir = Directory(basePath);
      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
      }

      String targetSubFolder;
      final cleanType = type.toLowerCase();
      if (cleanType.contains('quote') || cleanType.contains('quotation')) {
        targetSubFolder = 'Quotations';
      } else if (cleanType.contains('invoice')) {
        targetSubFolder = 'Invoices';
      } else {
        targetSubFolder = 'Receipts';
      }

      final separator = Platform.isWindows ? '\\' : '/';
      final subDir = Directory('${baseDir.path}$separator$targetSubFolder');
      if (!await subDir.exists()) {
        await subDir.create(recursive: true);
      }

      final fileName = sourceFile.path.split(RegExp(r'[\\/]')).last;
      final targetFile = File('${subDir.path}$separator$fileName');
      
      final bytes = await sourceFile.readAsBytes();
      await targetFile.writeAsBytes(bytes);
      return targetFile;
    } catch (e) {
      debugPrint('Error saving PDF locally: $e');
      return null;
    }
  }
}
