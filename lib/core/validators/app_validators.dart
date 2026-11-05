class AppValidators {
  AppValidators._();

  static String? requiredField(String? value, [String? message]) {
    if (value == null || value.trim().isEmpty) {
      return message ?? 'This field is required';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  static String? positiveNumber(String? value, [String fieldName = 'Value']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    final num? parsed = num.tryParse(value.trim());
    if (parsed == null || parsed <= 0) {
      return '$fieldName must be greater than 0';
    }
    return null;
  }

  static String? nonNegativeNumber(String? value, [String fieldName = 'Value']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    final num? parsed = num.tryParse(value.trim());
    if (parsed == null || parsed < 0) {
      return '$fieldName cannot be negative';
    }
    return null;
  }

  static String? wholeNumber(String? value, [String fieldName = 'Quantity']) {
    final nonNeg = nonNegativeNumber(value, fieldName);
    if (nonNeg != null) return nonNeg;
    final parsed = double.tryParse(value!.trim());
    if (parsed != null && parsed != parsed.truncateToDouble()) {
      return '$fieldName must be a whole number for piece-based products';
    }
    return null;
  }
}

