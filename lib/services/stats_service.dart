import 'package:shared_preferences/shared_preferences.dart';

class StatsService {
  static const String _keyPhotosDeleted = 'photos_deleted';
  static const String _keyVideosDeleted = 'videos_deleted';
  static const String _keyPhotoStorageRecovered = 'photo_storage_recovered';
  static const String _keyVideoStorageRecovered = 'video_storage_recovered';

  /// Get total number of photos deleted
  static Future<int> getPhotosDeleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyPhotosDeleted) ?? 0;
  }

  /// Get total number of videos deleted
  static Future<int> getVideosDeleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyVideosDeleted) ?? 0;
  }

  /// Get total storage recovered from photos (in bytes)
  static Future<int> getPhotoStorageRecovered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyPhotoStorageRecovered) ?? 0;
  }

  /// Get total storage recovered from videos (in bytes)
  static Future<int> getVideoStorageRecovered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyVideoStorageRecovered) ?? 0;
  }

  /// Get total storage recovered (in bytes)
  static Future<int> getTotalStorageRecovered() async {
    final photoStorage = await getPhotoStorageRecovered();
    final videoStorage = await getVideoStorageRecovered();
    return photoStorage + videoStorage;
  }

  /// Record deletion of media items
  static Future<void> recordDeletions({
    required int photosDeleted,
    required int videosDeleted,
    required int photoStorageBytes,
    required int videoStorageBytes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Read current values directly from the same prefs instance to avoid race conditions
    final currentPhotos = prefs.getInt(_keyPhotosDeleted) ?? 0;
    final currentVideos = prefs.getInt(_keyVideosDeleted) ?? 0;
    final currentPhotoStorage = prefs.getInt(_keyPhotoStorageRecovered) ?? 0;
    final currentVideoStorage = prefs.getInt(_keyVideoStorageRecovered) ?? 0;
    
    // Update counts atomically
    await prefs.setInt(_keyPhotosDeleted, currentPhotos + photosDeleted);
    await prefs.setInt(_keyVideosDeleted, currentVideos + videosDeleted);
    
    // Update storage
    await prefs.setInt(_keyPhotoStorageRecovered, currentPhotoStorage + photoStorageBytes);
    await prefs.setInt(_keyVideoStorageRecovered, currentVideoStorage + videoStorageBytes);
    
    // Ensure all writes are committed
    await prefs.reload();
  }

  /// Format bytes to human-readable string
  static String formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}

