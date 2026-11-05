import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _timeFormat = DateFormat('hh:mm a');
  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _isoDateFormat = DateFormat('yyyy-MM-dd');

  static String formatDate(DateTime date) => _dateFormat.format(date);
  static String formatTime(DateTime date) => _timeFormat.format(date);
  static String formatDateTime(DateTime date) => _dateTimeFormat.format(date);
  static String formatIsoDate(DateTime date) => _isoDateFormat.format(date);
  static String toIsoDate(DateTime date) => _isoDateFormat.format(date);

  static DateTime parseIsoDate(String dateStr) => _isoDateFormat.parse(dateStr);

  static String todayIso() => _isoDateFormat.format(DateTime.now());
}

