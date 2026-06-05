// Date Formatter
// Date and time formatting utilities

import 'package:intl/intl.dart';

class DateFormatter {
  // Global formatting settings that can be updated from system settings
  static String _dateFormatStr = 'MMM dd, yyyy';
  static String _timeFormatStr = 'HH:mm';

  static void setFormats({String? dateFormat, String? timeFormat}) {
    if (dateFormat != null && dateFormat.isNotEmpty) {
      _dateFormatStr = dateFormat;
    }
    if (timeFormat != null && timeFormat.isNotEmpty) {
      _timeFormatStr = timeFormat;
    }
  }

  static String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat(_dateFormatStr).format(date);
    } catch (_) {
      return dateStr;
    }
  }

  static String formatDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('$_dateFormatStr $_timeFormatStr').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  static String formatTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat(_timeFormatStr).format(date);
    } catch (_) {
      return dateStr;
    }
  }

  static String timeAgo(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      var diff = now.difference(date);

      if (diff.isNegative) {
        diff = diff.abs();
      }

      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours} hour ago';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
      if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} months ago';
      return '${(diff.inDays / 365).floor()} years ago';
    } catch (_) {
      return dateStr;
    }
  }

  static String formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return 'N/A';
    if (seconds < 3600) return '${(seconds / 60).round()} min';
    if (seconds < 86400) return '${(seconds / 3600).toStringAsFixed(1)} hrs';
    return '${(seconds / 86400).toStringAsFixed(1)} days';
  }

  static String formatDateRange(String? start, String? end) {
    final s = formatDate(start);
    final e = end != null ? formatDate(end) : 'Present';
    return '$s — $e';
  }

  static DateTime? parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.isUtc ? value.toLocal() : value;

    if (value is int) {
      final millis = value < 1000000000000 ? value * 1000 : value;
      final parsed = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
      return parsed.toLocal();
    }

    final dateStr = value.toString().trim();
    if (dateStr.isEmpty) return null;

    // ignore: deprecated_member_use
    if (RegExp(r'^\d{10,13}$').hasMatch(dateStr)) {
      final epoch = int.tryParse(dateStr);
      if (epoch != null) {
        final millis = dateStr.length == 10 ? epoch * 1000 : epoch;
        final parsed = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
        return parsed.toLocal();
      }
    }

    DateTime? parsed = DateTime.tryParse(dateStr);
    if (parsed == null) {
      var normalized = dateStr;

      if (normalized.contains(' ') && !normalized.contains('T')) {
        normalized = normalized.replaceFirst(' ', 'T');
      }

      normalized = normalized.replaceFirstMapped(
        // ignore: deprecated_member_use
        RegExp(r'([+-]\d{2})$'),
        (match) => '${match.group(1)}:00',
      );

      normalized = normalized.replaceFirstMapped(
        // ignore: deprecated_member_use
        RegExp(r'\.(\d{6})\d+(?=(Z|[+-]\d{2}:?\d{2})?$)'),
        (match) => '.${match.group(1)}',
      );

      parsed = DateTime.tryParse(normalized);
    }

    if (parsed == null) return null;

    return parsed.isUtc ? parsed.toLocal() : parsed;
  }
}
