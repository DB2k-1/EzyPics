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
  static void _log(String message) {
    // Logging disabled. Uncomment to debug storage cleanup:
    // debugPrint('CacheCleanup: $message');
  }

  /// Clears every disk location that contributes to "Documents & Data":
  /// Cache, Temp, Application Support, and (on iOS) the real tmp and Documents.
  /// Call on background, after deletion, when leaving media screens, and periodically.
  static Future<void> clearAllDiskCaches() async {
    _log('clearAllDiskCaches START');
    try {
      final cacheDir = await getApplicationCacheDirectory();
      _log('Cache path: ${cacheDir.path}');
      await _clearDirectory(cacheDir, 'Cache');

      final tempDir = await getTemporaryDirectory();
      _log('Temp path (path_provider): ${tempDir.path}');
      // On iOS, getTemporaryDirectory() often returns the same path as Cache (Library/Caches).
      // If so, skip duplicate clear and explicitly clear the real tmp: .../Application/UUID/tmp
      if (tempDir.path != cacheDir.path) {
        await _clearDirectory(tempDir, 'Temp');
      } else {
        _log('Temp same as Cache, skipping duplicate; clearing real tmp dir on iOS');
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          // Cache is .../Application/UUID/Library/Caches → parent.parent = .../UUID, then tmp
          final containerPath = cacheDir.parent.parent.path;
          final realTmp = Directory('$containerPath/tmp');
          await _clearDirectory(realTmp, 'Tmp');
        }
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final supportDir = await getApplicationSupportDirectory();
        _log('ApplicationSupport path: ${supportDir.path}');
        await _clearDirectory(supportDir, 'ApplicationSupport');

        // Documents often holds the bulk of "Documents & Data" (plugin caches, exports, etc.)
        final documentsDir = await getApplicationDocumentsDirectory();
        _log('Documents path: ${documentsDir.path}');
        await _clearDirectory(documentsDir, 'Documents');
      }

      _log('clearAllDiskCaches DONE');
    } catch (e, stack) {
      _log('clearAllDiskCaches FAILED: $e');
      _log('$stack');
    }
  }

  static Future<void> _clearDirectory(Directory dir, String label) async {
    if (!await dir.exists()) {
      _log('$label: directory does not exist, skip');
      return;
    }
    int filesDeleted = 0;
    int dirsDeleted = 0;
    int failed = 0;
    int bytesFreed = 0;
    final failures = <String>[];

    try {
      final entities = dir.listSync();
      _log('$label: found ${entities.length} items in ${dir.path}');

      for (final entity in entities) {
        try {
          if (entity is File) {
            final len = entity.lengthSync();
            entity.deleteSync();
            filesDeleted++;
            bytesFreed += len;
            _log('$label: deleted file ${entity.path} ($len bytes)');
          } else if (entity is Directory) {
            final size = _dirSizeSync(entity);
            entity.deleteSync(recursive: true);
            dirsDeleted++;
            bytesFreed += size;
            _log('$label: deleted dir ${entity.path} ($size bytes)');
          }
        } catch (e) {
          failed++;
          final msg = '${entity.path}: $e';
          failures.add(msg);
          _log('$label: FAILED to delete $msg');
        }
      }

      final mb = (bytesFreed / (1024 * 1024)).toStringAsFixed(2);
      _log('$label: summary — $filesDeleted files, $dirsDeleted dirs removed, $mb MB freed, $failed failures');
      if (failures.isNotEmpty) {
        _log('$label: failures: $failures');
      }
    } catch (e) {
      _log('$label: _clearDirectory error: $e');
    }
  }

  static int _dirSizeSync(Directory dir) {
    int total = 0;
    try {
      for (final entity in dir.listSync()) {
        if (entity is File) {
          total += entity.lengthSync();
        } else if (entity is Directory) {
          total += _dirSizeSync(entity);
        }
      }
    } catch (_) {}
    return total;
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
      _log('clearImageCache: done');
    } catch (e) {
      _log('clearImageCache failed: $e');
    }
  }
}
