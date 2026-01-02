import 'package:flutter/material.dart';
import '../utils/date_utils.dart';

class LogoWidget extends StatelessWidget {
  final String? selectedDateKey;
  final VoidCallback? onTap;
  
  const LogoWidget({super.key, this.selectedDateKey, this.onTap});

  @override
  Widget build(BuildContext context) {
    final todayKey = AppDateUtils.getTodayDateKey();
    final showDate = selectedDateKey != null && selectedDateKey != todayKey;
    
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Banner image positioned at top edge of screen (no SafeArea padding)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/EzyPics_big_banner_cropped.png',
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to text if image fails to load
                return Container(
                  padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                  child: Text(
                    'EzyPics',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                );
              },
            ),
          ),
          // Spacer to set Stack height - matches banner image height exactly
          // Using the banner image itself (invisible) to get exact height match
          // IgnorePointer prevents it from intercepting taps
          IgnorePointer(
            child: Opacity(
              opacity: 0,
              child: Image.asset(
                'assets/EzyPics_big_banner_cropped.png',
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(height: 60); // Fallback height
                },
              ),
            ),
          ),
        // Date text positioned below banner (maintains same position)
        if (showDate)
          Positioned(
            bottom: 0.0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  AppDateUtils.formatDateForDisplay(selectedDateKey!),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

