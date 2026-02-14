import 'dart:io';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

/// Keeps the app lean by clearing temp files and limiting caches.
/// Call from main() on startup and when leaving media-heavy screens.
class CacheCleanup {
  /// Prefix for branded image temp files (from ImageBrandingService).
  static const String brandedFilePrefix = 'branded_';
  static const String brandedFileSuffix = '.png';

  /// Runs on app startup: deletes leftover temp files from sharing/branding
  /// and test photo generation. Does not block app launch.
  static Future<void> clearTempFilesOnStartup() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (!await tempDir.exists()) return;

      final entities = tempDir.listSync();
      int deleted = 0;
      for (final entity in entities) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        // Remove old branded share images and any leftover test generator files
        final isBranded = name.startsWith(brandedFilePrefix) && name.endsWith(brandedFileSuffix);
        final isTestFile = name.startsWith('test_') && (name.endsWith('.jpg') || name.endsWith('.mov'));
        if (isBranded || isTestFile) {
          try {
            await entity.delete();
            deleted++;
          } catch (_) {}
        }
      }
      if (deleted > 0) {
        print('CacheCleanup: deleted $deleted temp file(s) on startup');
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
