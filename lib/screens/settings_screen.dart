import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/media_item.dart';
import '../services/photo_service.dart';
import '../services/test_photo_generator.dart';
import '../utils/date_utils.dart';
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

  @override
  void initState() {
    super.initState();
    _loadMediaMap();
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
    
    // Only navigate if there's media for this date
    if (media.isEmpty) {
      return;
    }
    
    // Navigate back to carousel with the selected date
    Navigator.of(context).pushReplacementNamed(
      '/carousel',
      arguments: {'dateKey': dateKey},
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
          const LogoWidget(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('← Back'),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showTestPhotoDialog(),
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
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: _buildCalendar(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
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

