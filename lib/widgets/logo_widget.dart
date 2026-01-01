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
        padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: Image.asset(
                'assets/EzyPics_header.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to text if image fails to load
                  return Text(
                    'EzyPics',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  );
                },
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

