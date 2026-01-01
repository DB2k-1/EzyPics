import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/media_item.dart';

/// Simplified preview card with pre-loaded thumbnail
class YearPreviewCard extends StatelessWidget {
  final int year;
  final int totalItemsForYear;
  final Uint8List? thumbnailData; // Pre-loaded thumbnail
  final bool isVideo;
  final Animation<double> fadeAnimation;

  const YearPreviewCard({
    super.key,
    required this.year,
    required this.totalItemsForYear,
    required this.thumbnailData,
    required this.isVideo,
    required this.fadeAnimation,
  });

  @override
  Widget build(BuildContext context) {
    const cardHeight = 300.0 + 16.0 + 24.0 + 4.0 + 16.0 + 16.0; // Image + padding + text

    // Use AnimatedBuilder to rebuild when animation changes
    return AnimatedBuilder(
      animation: fadeAnimation,
      builder: (context, child) {
        // Calculate opacity: quick fade in (150ms) -> full opacity (700ms) -> quick fade out (150ms)
        // Total: 1000ms
        // Fade in: 0.0 to 0.15 (150ms)
        // Full opacity: 0.15 to 0.85 (700ms)
        // Fade out: 0.85 to 1.0 (150ms)
        final animValue = fadeAnimation.value;
        final opacityValue = animValue <= 0.15
            ? animValue / 0.15 // Fade in: 0 to 1
            : animValue >= 0.85
                ? (1.0 - animValue) / 0.15 // Fade out: 1 to 0
                : 1.0; // Full opacity in middle

        // White overlay opacity (visible during transitions)
        final whiteOverlayOpacity = animValue <= 0.15
            ? 1.0 - (animValue / 0.15) // Fade out white during fade in
            : animValue >= 0.85
                ? (animValue - 0.85) / 0.15 // Fade in white during fade out
                : 0.0; // No white overlay during full opacity
        
        // Debug logging (remove after testing)
        if (animValue % 0.1 < 0.02 || animValue == 0.0 || animValue == 1.0) {
          print('[PREVIEW] Year $year: animValue=${animValue.toStringAsFixed(3)}, cardOpacity=${opacityValue.toStringAsFixed(3)}, whiteOpacity=${whiteOverlayOpacity.toStringAsFixed(3)}');
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth - 32; // Account for horizontal margin

            return Stack(
              alignment: Alignment.center,
              children: [
                // White background during transitions - only show when card is fading
                if (whiteOverlayOpacity > 0.0)
                  Opacity(
                    opacity: whiteOverlayOpacity.clamp(0.0, 1.0),
                    child: Container(
                      width: cardWidth,
                      height: cardHeight,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                // The actual card with photo
                Opacity(
                  opacity: opacityValue.clamp(0.0, 1.0),
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 300,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: thumbnailData != null
                                ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.memory(
                                        thumbnailData!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      ),
                                      if (isVideo)
                                        const Center(
                                          child: Icon(
                                            Icons.play_circle_filled,
                                            color: Colors.white,
                                            size: 60,
                                          ),
                                        ),
                                    ],
                                  )
                                : const Center(child: CircularProgressIndicator()),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$year',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$totalItemsForYear ${totalItemsForYear == 1 ? 'item' : 'items'}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

