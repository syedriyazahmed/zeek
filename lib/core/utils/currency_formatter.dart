import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _formatter = NumberFormat.currency(
    symbol: AppConstants.currencySymbol,
    decimalDigits: 2,
    locale: 'en_IN',
  );

  static final NumberFormat _compactFormatter = NumberFormat.compactCurrency(
    symbol: AppConstants.currencySymbol,
    decimalDigits: 1,
    locale: 'en_IN',
  );

  /// Format double or integer amount to ₹1,250.00
  static String format(num amount) {
    return _formatter.format(amount);
  }

  /// Plain format for PDF generation (e.g. Rs. 1,250.00) avoiding font glyph issues
  static String formatPlain(num amount) {
    final fmt = NumberFormat("#,##,##0.00", "en_IN");
    return 'Rs. ${fmt.format(amount)}';
  }

  /// Compact format: ₹1.5K, ₹2.5L
  static String formatCompact(num amount) {
    return _compactFormatter.format(amount);
  }

  /// Round to 2 decimal places to avoid floating point precision issues
  static double round(num amount) {
    return (amount * 100).roundToDouble() / 100.0;
  }

  /// Convert paise (integer cents) to standard rupee float
  static double paiseToRupees(int paise) {
    return paise / 100.0;
  }

  /// Convert rupees float to integer paise
  static int rupeesToPaise(num rupees) {
    return (rupees * 100).round();
  }
}

