import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/media_item.dart';
import '../services/notification_service.dart';
import '../services/photo_service.dart';
import '../services/streak_service.dart';
import '../services/test_photo_generator.dart';
import '../utils/date_utils.dart';
import '../utils/cache_cleanup.dart';
import '../widgets/logo_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, List<MediaItem>> _mediaMap = {};
  bool _isLoading = true;
  bool _isGenerating = false;
  DateTime _focusedDay = DateTime.now();
  int _selectDateTapCount = 0;

  Set<String> _usageDates = {};
  DateTime? _firstUseDate;

  String _notifMode = 'random';
  TimeOfDay _notifSetTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _notifRangeStart = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _notifRangeEnd = const TimeOfDay(hour: 21, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadMediaMap();
    _loadStreakData();
    _loadNotifSettings();
  }

  Future<void> _loadStreakData() async {
    final dates = await StreakService.getUsageDates();
    final firstUse = await StreakService.getFirstUseDate();
    if (mounted) {
      setState(() {
        _usageDates = dates;
        _firstUseDate = firstUse;
      });
    }
  }

  Future<void> _loadNotifSettings() async {
    final mode = await NotificationService.getMode();
    final setTime = await NotificationService.getSetTime();
    final rangeStart = await NotificationService.getRangeStart();
    final rangeEnd = await NotificationService.getRangeEnd();
    if (mounted) {
      setState(() {
        _notifMode = mode;
        _notifSetTime = setTime;
        _notifRangeStart = rangeStart;
        _notifRangeEnd = rangeEnd;
      });
    }
  }

  Future<void> _loadMediaMap() async {
    setState(() => _isLoading = true);
    try {
      final scannedMedia = await PhotoService.scanMediaByDate();
      setState(() {
        _mediaMap = scannedMedia;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Map<DateTime, List<dynamic>> _getMarkedDates() {
    final markedDates = <DateTime, List<dynamic>>{};
    final focusedYear = _focusedDay.year;
    
    // Mark dates for the focused year (for display purposes)
    _mediaMap.forEach((dateKey, mediaItems) {
      if (mediaItems.isNotEmpty) {
        final parts = dateKey.split('-');
        final month = int.parse(parts[0]);
        final day = int.parse(parts[1]);
        
        final focusedYearDate = DateTime(focusedYear, month, day);
        markedDates[focusedYearDate] = ['media'];
      }
    });
    
    return markedDates;
  }

  int _getMediaCountForDateKey(String dateKey) {
    // Get count across all years for this date
    return _mediaMap[dateKey]?.length ?? 0;
  }

  void _handleDaySelected(DateTime selectedDate, DateTime focusedDate) {
    // Get date key (MM-DD format, ignoring year)
    final dateKey = AppDateUtils.getDateKey(selectedDate);
    final media = _mediaMap[dateKey] ?? [];
    if (media.isEmpty) return;
    _startReviewForDate(dateKey);
  }

  Future<void> _startReviewForDate(String dateKey) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Preparing…'),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      await CacheCleanup.clearAllDiskCaches();
      if (!mounted) return;
      Navigator.of(context).pop(); // close dialog
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        '/carousel',
        arguments: {'dateKey': dateKey},
      );
    } catch (_) {
      if (mounted) Navigator.of(context).pop(); // close dialog on error
    }
  }

  Widget? _buildCalendarCell(DateTime date, {required bool isBold, bool isOutside = false}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayDate = DateTime(date.year, date.month, date.day);
    final iso = StreakService.isoDate(date);

    Color? ringColor;

    if (_firstUseDate != null) {
      final firstDay = DateTime(_firstUseDate!.year, _firstUseDate!.month, _firstUseDate!.day);
      final yesterday = today.subtract(const Duration(days: 1));

      if (!dayDate.isBefore(firstDay) && !dayDate.isAfter(today)) {
        if (_usageDates.contains(iso)) {
          ringColor = Colors.green;
        } else if (!dayDate.isAfter(yesterday)) {
          ringColor = Colors.red;
        }
      }
    }

    final textColor = isOutside ? Colors.grey[400] : null;

    return Center(
      child: Container(
        width: 38,
        height: 38,
        decoration: ringColor != null
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ringColor, width: 2),
              )
            : null,
        child: Center(
          child: Text(
            '${date.day}',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    final markedDates = _getMarkedDates();
    final now = DateTime.now();
    
    return TableCalendar(
      firstDay: DateTime(now.year - 10, 1, 1),
      lastDay: DateTime(now.year + 10, 12, 31),
      focusedDay: _focusedDay,
      calendarFormat: CalendarFormat.month,
      startingDayOfWeek: StartingDayOfWeek.monday,
      eventLoader: (date) => markedDates[date] ?? [],
      selectedDayPredicate: (day) => false,
      onDaySelected: _handleDaySelected,
      onPageChanged: (focusedDay) {
        setState(() {
          _focusedDay = focusedDay;
        });
      },
      calendarStyle: CalendarStyle(
        markersMaxCount: 1,
        markerDecoration: const BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
        outsideDaysVisible: false,
      ),
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextFormatter: (date, locale) {
          const monthNames = [
            'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'
          ];
          return monthNames[date.month - 1];
        },
      ),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, date, focusedDay) =>
            _buildCalendarCell(date, isBold: false),
        todayBuilder: (context, date, focusedDay) =>
            _buildCalendarCell(date, isBold: true),
        outsideBuilder: (context, date, focusedDay) =>
            _buildCalendarCell(date, isBold: false, isOutside: true),
        markerBuilder: (context, date, events) {
          final dateKey = AppDateUtils.getDateKey(date);
          final count = _getMediaCountForDateKey(dateKey);
          if (count == 0) return null;

          // Simple blue circle marker
          return Positioned(
            bottom: 1,
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
          children: [
          LogoWidget(
            onTap: () => Navigator.of(context).pushReplacementNamed('/home'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pushReplacementNamed('/home'),
                  child: const Text('← Back'),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    _selectDateTapCount++;
                    if (_selectDateTapCount >= 6) {
                      _selectDateTapCount = 0; // Reset counter
                      _showTestPhotoDialog();
                    }
                  },
                  child: const Text(
                    'Select Date',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                // Spacer to balance the layout (bug button removed)
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: _buildCalendar(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildNotifSettings(),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickTimeCupertino(
    BuildContext context,
    TimeOfDay initial,
    Future<void> Function(TimeOfDay) onPicked,
  ) async {
    DateTime picked = DateTime(2000, 1, 1, initial.hour, initial.minute);

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 280,
        color: CupertinoColors.systemBackground.resolveFrom(ctx),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(
                child: const Text('Done'),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: picked,
                use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
                onDateTimeChanged: (dt) => picked = dt,
              ),
            ),
          ],
        ),
      ),
    );

    await onPicked(TimeOfDay(hour: picked.hour, minute: picked.minute));
  }

  Widget _buildTimeTile(String label, TimeOfDay time, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              _formatTimeOfDay(time),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildNotifSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reminders',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Random fires any time 8am–9pm. Time Range lets you set the window.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final entry in [
                  ('off', 'Off'),
                  ('random', 'Random'),
                  ('setTime', 'Set Time'),
                  ('timeRange', 'Time Range'),
                ])
                  ChoiceChip(
                    label: Text(entry.$2),
                    selected: _notifMode == entry.$1,
                    onSelected: (_) async {
                      await NotificationService.setMode(entry.$1);
                      await NotificationService.requestPermission();
                      await NotificationService.scheduleReminder();
                      if (mounted) setState(() => _notifMode = entry.$1);
                    },
                  ),
              ],
            ),
            if (_notifMode == 'setTime') ...[
              const SizedBox(height: 8),
              _buildTimeTile('Remind me at', _notifSetTime, () => _pickTimeCupertino(
                context, _notifSetTime, (t) async {
                  await NotificationService.setSetTime(t.hour, t.minute);
                  await NotificationService.scheduleReminder();
                  if (mounted) setState(() => _notifSetTime = t);
                },
              )),
            ],
            if (_notifMode == 'timeRange') ...[
              const SizedBox(height: 8),
              _buildTimeTile('From', _notifRangeStart, () => _pickTimeCupertino(
                context, _notifRangeStart, (t) async {
                  await NotificationService.setRangeStart(t.hour, t.minute);
                  await NotificationService.scheduleReminder();
                  if (mounted) setState(() => _notifRangeStart = t);
                },
              )),
              _buildTimeTile('To', _notifRangeEnd, () => _pickTimeCupertino(
                context, _notifRangeEnd, (t) async {
                  await NotificationService.setRangeEnd(t.hour, t.minute);
                  await NotificationService.scheduleReminder();
                  if (mounted) setState(() => _notifRangeEnd = t);
                },
              )),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showTestPhotoDialog() async {
    final dateController = TextEditingController(
      text: AppDateUtils.getTodayDateKey(),
    );
    final yearsController = TextEditingController(text: '8');
    final minController = TextEditingController(text: '1');
    final maxController = TextEditingController(text: '4');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Test Photos'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dateController,
                decoration: const InputDecoration(
                  labelText: 'Date (MM-DD)',
                  hintText: '12-27',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: yearsController,
                decoration: const InputDecoration(
                  labelText: 'Years Back',
                  hintText: '8',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minController,
                      decoration: const InputDecoration(
                        labelText: 'Min Photos/Year',
                        hintText: '1',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: maxController,
                      decoration: const InputDecoration(
                        labelText: 'Max Photos/Year',
                        hintText: '10',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    if (result == true) {
      final dateKey = dateController.text.trim();
      final yearsBack = int.tryParse(yearsController.text) ?? 8;
      final minPhotos = int.tryParse(minController.text) ?? 1;
      final maxPhotos = int.tryParse(maxController.text) ?? 10;

      if (dateKey.isEmpty || !dateKey.contains('-')) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid date format. Use MM-DD')),
          );
        }
        return;
      }

      setState(() => _isGenerating = true);

      final success = await TestPhotoGenerator.generateTestPhotos(
        dateKey: dateKey,
        yearsBack: yearsBack,
        minPhotosPerYear: minPhotos,
        maxPhotosPerYear: maxPhotos,
      );

      setState(() => _isGenerating = false);

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Test photos generated! Reload to see them.'),
            ),
          );
          // Reload media map
          _loadMediaMap();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to generate test photos')),
          );
        }
      }
    }
  }
}

