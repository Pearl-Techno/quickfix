class Validators {
  // Validate required field
  static String? required(String? value, {String fieldName = 'Field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  // Validate email
  static String? email(String? value) {
    if (value == null || value.isEmpty) return null;

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  // Validate phone number (Kenyan)
  static String? phone(String? value) {
    if (value == null || value.isEmpty) return null;

    final cleaned = value.replaceAll(RegExp(r'\D'), '');
    final phoneRegex = RegExp(r'^(07|01|2547|2541)\d{8}$');

    if (!phoneRegex.hasMatch(cleaned)) {
      return 'Please enter a valid Kenyan phone number';
    }
    return null;
  }

  // Validate password - No minimum length restriction
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    return null;
  }

  // Validate password confirmation
  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  // Validate number
  static String? number(String? value, {String fieldName = 'Number'}) {
    if (value == null || value.isEmpty) return null;

    if (double.tryParse(value) == null) {
      return 'Please enter a valid number';
    }
    return null;
  }

  // Validate positive number
  static String? positiveNumber(String? value, {String fieldName = 'Number'}) {
    if (value == null || value.isEmpty) return null;

    final num = double.tryParse(value);
    if (num == null) {
      return 'Please enter a valid number';
    }
    if (num <= 0) {
      return 'Please enter a number greater than 0';
    }
    return null;
  }

  // Validate integer
  static String? integer(String? value, {String fieldName = 'Number'}) {
    if (value == null || value.isEmpty) return null;

    if (int.tryParse(value) == null) {
      return 'Please enter a whole number';
    }
    return null;
  }

  // Validate positive integer
  static String? positiveInteger(String? value, {String fieldName = 'Number'}) {
    if (value == null || value.isEmpty) return null;

    final num = int.tryParse(value);
    if (num == null) {
      return 'Please enter a whole number';
    }
    if (num <= 0) {
      return 'Please enter a number greater than 0';
    }
    return null;
  }

  // Validate URL
  static String? url(String? value) {
    if (value == null || value.isEmpty) return null;

    final urlRegex = RegExp(
      r'^(https?://)?([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(/[^\s]*)?$',
    );

    if (!urlRegex.hasMatch(value)) {
      return 'Please enter a valid URL';
    }
    return null;
  }

  // Validate date
  static String? date(String? value) {
    if (value == null || value.isEmpty) return null;

    try {
      DateTime.parse(value);
      return null;
    } catch (e) {
      return 'Please enter a valid date';
    }
  }

  // Validate future date
  static String? futureDate(DateTime? date) {
    if (date == null) return null;

    if (date.isBefore(DateTime.now())) {
      return 'Date must be in the future';
    }
    return null;
  }

  // Validate past date
  static String? pastDate(DateTime? date) {
    if (date == null) return null;

    if (date.isAfter(DateTime.now())) {
      return 'Date must be in the past';
    }
    return null;
  }

  // Validate select (dropdown)
  static String? select(dynamic value, {String fieldName = 'Selection'}) {
    if (value == null || (value is String && value.isEmpty)) {
      return 'Please select a $fieldName';
    }
    if (value is List && value.isEmpty) {
      return 'Please select a $fieldName';
    }
    return null;
  }

  // Validate decimal places
  static String? decimalPlaces(String? value, int maxDecimalPlaces) {
    if (value == null || value.isEmpty) return null;

    final num = double.tryParse(value);
    if (num == null) return null;

    final decimalStr = value.split('.');
    if (decimalStr.length == 2 && decimalStr[1].length > maxDecimalPlaces) {
      return 'Maximum $maxDecimalPlaces decimal places allowed';
    }
    return null;
  }

  // Combined validator for address
  static String? address(String? value) {
    if (value == null || value.isEmpty) return null;

    if (value.trim().length < 3) {
      return 'Address must be at least 3 characters';
    }
    return null;
  }

  // Combined validator for name
  static String? name(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }

    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }

    if (value.trim().length > 100) {
      return 'Name must be less than 100 characters';
    }

    return null;
  }

  // Validate amount (money)
  static String? amount(String? value) {
    if (value == null || value.isEmpty) return null;

    final num = double.tryParse(value);
    if (num == null) {
      return 'Please enter a valid amount';
    }
    if (num < 0) {
      return 'Amount cannot be negative';
    }
    if (num > 999999999) {
      return 'Amount is too large';
    }
    return null;
  }
}
