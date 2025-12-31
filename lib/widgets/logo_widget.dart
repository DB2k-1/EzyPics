import 'package:flutter/material.dart';
import '../utils/date_utils.dart';

class LogoWidget extends StatelessWidget {
  final String? selectedDateKey;
  
  const LogoWidget({super.key, this.selectedDateKey});

  @override
  Widget build(BuildContext context) {
    final todayKey = AppDateUtils.getTodayDateKey();
    final showDate = selectedDateKey != null && selectedDateKey != todayKey;
    
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 20.0, bottom: 12.0),
        child: Column(
          children: [
            Text(
              'EzyPics',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (showDate)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  AppDateUtils.formatDateForDisplay(selectedDateKey!),
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

