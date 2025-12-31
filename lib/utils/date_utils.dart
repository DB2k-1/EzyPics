class AppDateUtils {
  static String getDateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month-$day';
  }

  static String getTodayDateKey() {
    return getDateKey(DateTime.now());
  }

  static String formatDateForDisplay(String dateKey, {int? year}) {
    final parts = dateKey.split('-');
    final month = int.parse(parts[0]);
    final day = parts[1];
    
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    final monthName = monthNames[month - 1];
    return year != null ? '$monthName $day, $year' : '$monthName $day';
  }
}

