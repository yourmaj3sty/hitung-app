import 'package:intl/intl.dart';

class DateFormatter {
  static const List<String> monthsIndo = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  static const List<String> daysIndo = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
  ];

  static String formatMonthYear(DateTime date) {
    return '${monthsIndo[date.month - 1]} ${date.year}';
  }

  static String formatDailyHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diffDays = today.difference(target).inDays;

    final dayName = daysIndo[date.weekday - 1];
    final shortMonth = monthsIndo[date.month - 1].substring(0, 3);
    final dateStr = '$dayName, ${date.day} $shortMonth ${date.year}';

    if (diffDays == 0) {
      return 'Hari Ini • $dateStr';
    } else if (diffDays == 1) {
      return 'Kemarin • $dateStr';
    }
    return dateStr;
  }

  static String formatShortDate(DateTime date) {
    final shortMonth = monthsIndo[date.month - 1].substring(0, 3);
    return '${date.day} $shortMonth';
  }

  static String formatIsoDate(DateTime date) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
  }
}
