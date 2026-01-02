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
    final day = int.parse(parts[1]);
    
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    // Get ordinal suffix for the day
    String getOrdinalSuffix(int day) {
      if (day >= 11 && day <= 13) {
        return 'th';
      }
      switch (day % 10) {
        case 1:
          return 'st';
        case 2:
          return 'nd';
        case 3:
          return 'rd';
        default:
          return 'th';
      }
    }
    
    final monthName = monthNames[month - 1];
    final dayWithSuffix = '$day${getOrdinalSuffix(day)}';
    
    return year != null ? '$dayWithSuffix $monthName, $year' : '$dayWithSuffix $monthName';
  }
}

