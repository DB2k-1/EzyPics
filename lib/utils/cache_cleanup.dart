import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

/// Keeps "Documents & Data" under control by clearing all writable disk caches.
///
/// **Why it grows:** When you review photos/videos, photo_manager and video_player
/// write thumbnails and decoded frames to:
/// - [getApplicationCacheDirectory] (Library/Caches)
/// - [getTemporaryDirectory] (tmp)
/// - [getApplicationSupportDirectory] (Library/Application Support — plugin caches)
/// We don't use Application Support for app data; SharedPreferences uses
/// UserDefaults (Library/Preferences), so clearing Support is safe.
///
/// **When we clear:** On background, after deletion, when leaving media screens,
/// and periodically during long review sessions.
class CacheCleanup {
  /// Clears every disk location that contributes to "Documents & Data":
  /// Cache, Temp, and Application Support (plugin caches).
  /// Call on background, after deletion, when leaving media screens, and periodically.
  static Future<void> clearAllDiskCaches() async {
    try {
      await _clearDirectory(await getApplicationCacheDirectory(), 'Cache');
      await _clearDirectory(await getTemporaryDirectory(), 'Temp');
      // iOS: Application Support holds plugin caches (video_player, etc.); safe to clear.
      // Android: Support dir can hold SharedPreferences; skip to avoid data loss.
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final supportDir = await getApplicationSupportDirectory();
        await _clearDirectory(supportDir, 'ApplicationSupport');
      }
    } catch (e) {
      debugPrint('CacheCleanup: clearAllDiskCaches failed: $e');
    }
  }

  static Future<void> _clearDirectory(Directory dir, String label) async {
    if (!await dir.exists()) return;
    try {
      final entities = dir.listSync();
      for (final entity in entities) {
        try {
          if (entity is Directory) {
            entity.deleteSync(recursive: true);
          } else if (entity is File) {
            entity.deleteSync();
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('CacheCleanup: _clearDirectory $label failed: $e');
    }
  }

  /// Legacy name: same as [clearAllDiskCaches]. Kept for existing call sites.
  static Future<void> clearTempFilesOnStartup() async {
    await clearAllDiskCaches();
  }

  /// Frees decoded images from Flutter's in-memory image cache.
  /// Call when leaving media-heavy screens.
  static void clearImageCache() {
    try {
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (e) {
      debugPrint('CacheCleanup: clearImageCache failed: $e');
    }
  }
}
