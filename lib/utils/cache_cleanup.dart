import 'dart:io';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

/// Keeps the app lean by clearing temp files and limiting caches.
/// Call from main() on startup and when leaving media-heavy screens.
class CacheCleanup {
  /// Clears app cache and temp directories (plugin caches, copied media, etc.).
  /// Call on startup and when app goes to background so "Documents & Data" drops.
  static Future<void> clearTempFilesOnStartup() async {
    try {
      // 1. Clear entire application cache directory (photo_manager, video_player, etc.).
      final cacheDir = await getApplicationCacheDirectory();
      if (await cacheDir.exists()) {
        for (final entity in cacheDir.listSync()) {
          try {
            if (entity is Directory) {
              entity.deleteSync(recursive: true);
            } else if (entity is File) {
              entity.deleteSync();
            }
          } catch (_) {}
        }
      }

      // 2. Clear entire temp directory (copied assets, branded images, etc.).
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        for (final entity in tempDir.listSync()) {
          try {
            if (entity is Directory) {
              entity.deleteSync(recursive: true);
            } else if (entity is File) {
              entity.deleteSync();
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      print('CacheCleanup: clearTempFilesOnStartup failed: $e');
    }
  }

  /// Call when leaving a media-heavy screen (e.g. SwipeScreen, CarouselScreen)
  /// to free decoded images from Flutter's image cache and keep memory/storage pressure low.
  static void clearImageCache() {
    try {
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (e) {
      print('CacheCleanup: clearImageCache failed: $e');
    }
  }
}
