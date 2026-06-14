import 'package:shared_preferences/shared_preferences.dart';

class StreakService {
  static const String _keyFirstUseDate = 'streak_first_use_date';
  static const String _keyUsageDates = 'streak_usage_dates';

  static String isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<void> recordUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final today = isoDate(DateTime.now());

    if (!prefs.containsKey(_keyFirstUseDate)) {
      await prefs.setString(_keyFirstUseDate, today);
    }

    final dates = (prefs.getStringList(_keyUsageDates) ?? []).toSet();
    if (!dates.contains(today)) {
      dates.add(today);
      await prefs.setStringList(_keyUsageDates, dates.toList());
    }
  }

  static Future<DateTime?> getFirstUseDate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFirstUseDate);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  static Future<Set<String>> getUsageDates() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_keyUsageDates) ?? []).toSet();
  }

  static Future<int> getCurrentStreak() async {
    final dates = await getUsageDates();
    if (dates.isEmpty) return 0;

    final now = DateTime.now();
    final today = isoDate(now);
    final yesterday = isoDate(now.subtract(const Duration(days: 1)));

    // Streak must include today or yesterday to be active
    final anchor = dates.contains(today)
        ? now
        : dates.contains(yesterday)
            ? now.subtract(const Duration(days: 1))
            : null;

    if (anchor == null) return 0;

    int streak = 0;
    DateTime cursor = DateTime(anchor.year, anchor.month, anchor.day);
    while (dates.contains(isoDate(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static Future<int> getDaysUsedThisYear() async {
    final firstUse = await getFirstUseDate();
    if (firstUse == null) return 0;

    final dates = await getUsageDates();
    final now = DateTime.now();

    // Find last anniversary of firstUseDate that is <= today
    DateTime windowStart = DateTime(firstUse.year, firstUse.month, firstUse.day);
    while (true) {
      final next = DateTime(windowStart.year + 1, windowStart.month, windowStart.day);
      if (next.isAfter(now)) break;
      windowStart = next;
    }

    final windowStartIso = isoDate(windowStart);
    final nowIso = isoDate(now);

    return dates.where((d) => d.compareTo(windowStartIso) >= 0 && d.compareTo(nowIso) <= 0).length;
  }
}
