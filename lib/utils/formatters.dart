import 'package:intl/intl.dart';

class Formatters {
  // Format currency (Kenyan Shillings)
  static String currency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_KE',
      symbol: 'KSh ',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  // Format currency without symbol
  static String currencyNoSymbol(double amount) {
    final formatter = NumberFormat('#,##0.00', 'en_KE');
    return formatter.format(amount);
  }

  // Format date
  static String date(DateTime? date) {
    if (date == null) return 'N/A';
    final formatter = DateFormat('dd MMM yyyy', 'en_KE');
    return formatter.format(date);
  }

  // Format date with time
  static String dateTime(DateTime? date) {
    if (date == null) return 'N/A';
    final formatter = DateFormat('dd MMM yyyy HH:mm', 'en_KE');
    return formatter.format(date);
  }

  // Format time
  static String time(DateTime? date) {
    if (date == null) return 'N/A';
    final formatter = DateFormat('HH:mm', 'en_KE');
    return formatter.format(date);
  }

  // Format short date (dd/mm/yyyy)
  static String shortDate(DateTime? date) {
    if (date == null) return 'N/A';
    final formatter = DateFormat('dd/MM/yyyy', 'en_KE');
    return formatter.format(date);
  }

  // Format day and month
  static String dayMonth(DateTime? date) {
    if (date == null) return 'N/A';
    final formatter = DateFormat('dd MMM', 'en_KE');
    return formatter.format(date);
  }

  // Format month year
  static String monthYear(DateTime? date) {
    if (date == null) return 'N/A';
    final formatter = DateFormat('MMM yyyy', 'en_KE');
    return formatter.format(date);
  }

  // Format percentage
  static String percentage(double value) {
    return '${value.toStringAsFixed(1)}%';
  }

  // Format phone number (Kenyan)
  static String phoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) return 'N/A';

    // Remove all non-digit characters
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');

    // Format as 07XX XXX XXX
    if (cleaned.length == 10 && cleaned.startsWith('07')) {
      return '${cleaned.substring(0, 4)} ${cleaned.substring(4, 7)} ${cleaned.substring(7)}';
    }

    // Format as 2547XX XXX XXX
    if (cleaned.length == 12 && cleaned.startsWith('2547')) {
      return '${cleaned.substring(0, 3)} ${cleaned.substring(3, 6)} ${cleaned.substring(6, 9)} ${cleaned.substring(9)}';
    }

    return phone;
  }

  // Format file size
  static String fileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  // Format number with commas
  static String number(int number) {
    final formatter = NumberFormat('#,##0', 'en_KE');
    return formatter.format(number);
  }

  // Format decimal number
  static String decimal(double number, {int decimalPlaces = 2}) {
    final formatter = NumberFormat('#,##0.${'0' * decimalPlaces}', 'en_KE');
    return formatter.format(number);
  }

  // Format duration (in minutes to hours/minutes)
  static String duration(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return '$hours hr${hours > 1 ? 's' : ''}';
    }
    return '$hours hr${hours > 1 ? 's' : ''} $remainingMinutes min';
  }

  // Format abbreviation (e.g., "John Doe" -> "J. Doe")
  static String abbreviatedName(String name) {
    if (name.isEmpty) return '';

    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}. ${parts.sublist(1).join(' ')}';
    }
    return name;
  }

  // Format initials with full name (e.g., "JD")
  static String initials(String name) {
    if (name.isEmpty) return '?';

    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  // Format quote number (e.g., "010A")
  static String quoteNumber(int sequence, String letter) {
    return '${sequence.toString().padLeft(3, '0')}$letter';
  }

  // Format invoice number (e.g., "QPN00001")
  static String invoiceNumber(int sequence) {
    return 'QPN${sequence.toString().padLeft(5, '0')}';
  }

  // Format status title (e.g., "draft" -> "Draft")
  static String statusTitle(String status) {
    if (status.isEmpty) return '';
    return status[0].toUpperCase() + status.substring(1);
  }

  // Format search query (remove extra spaces, lowercase)
  static String searchQuery(String query) {
    return query.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  // Format text for display (capitalize first letter)
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  // Format list to comma-separated string
  static String listToCommaString(List<String> items) {
    return items.join(', ');
  }

  // Format address
  static String address({
    String? street,
    String? city,
    String? county,
    String? country,
  }) {
    final parts = <String>[];
    if (street != null && street.isNotEmpty) parts.add(street);
    if (city != null && city.isNotEmpty) parts.add(city);
    if (county != null && county.isNotEmpty) parts.add(county);
    if (country != null && country.isNotEmpty) parts.add(country);
    return parts.join(', ');
  }
}
