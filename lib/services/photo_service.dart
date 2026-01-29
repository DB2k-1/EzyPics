import 'package:photo_manager/photo_manager.dart';
import '../models/media_item.dart';

class PhotoService {
  static Future<bool> requestPermission() async {
    final status = await PhotoManager.requestPermissionExtend();
    return status.isAuth;
  }

  static Future<bool> hasPermission() async {
    final status = await PhotoManager.requestPermissionExtend();
    return status.isAuth;
  }

  static Future<Map<String, List<MediaItem>>> scanMediaByDate() async {
    final mediaMap = <String, List<MediaItem>>{};
    
    try {
      // Get all albums
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.all,
        hasAll: true,
      );

      if (albums.isEmpty) {
        return mediaMap;
      }

      // Use the first album (usually "Recent" or main album)
      final album = albums.first;
      final assetCount = await album.assetCountAsync;
      
      // Fetch assets in smaller batches to avoid blocking
      const batchSize = 200; // Reduced from 500 to prevent ANR
      int totalProcessed = 0;
      for (int start = 0; start < assetCount && start < 50000; start += batchSize) {
        final end = (start + batchSize < assetCount) ? start + batchSize : assetCount;
        
        // Add timeout to prevent hangs
        final assets = await album.getAssetListRange(start: start, end: end)
            .timeout(const Duration(seconds: 10), onTimeout: () {
          return <AssetEntity>[];
        });
        
        // Small delay between batches to keep UI responsive
        if (start + batchSize < assetCount && start + batchSize < 50000) {
          await Future.delayed(const Duration(milliseconds: 10));
        }

        // Group by date
        int videoCount = 0;
        int photoCount = 0;
        for (final asset in assets) {
          if (asset.createDateTime != null) {
            final isVideo = asset.type == AssetType.video;
            if (isVideo) videoCount++;
            else photoCount++;
            
            final mediaItem = MediaItem(
              id: asset.id,
              path: asset.relativePath ?? '',
              creationTime: asset.createDateTime!,
              isVideo: isVideo,
              width: asset.width,
              height: asset.height,
            );

            final dateKey = mediaItem.dateKey;
            
            // Verify MediaItem isVideo flag matches
            if (isVideo != mediaItem.isVideo) {
              print('PhotoService: ERROR - isVideo mismatch! asset.type=${asset.type}, isVideo=$isVideo, mediaItem.isVideo=${mediaItem.isVideo}');
            }
            
            mediaMap.putIfAbsent(dateKey, () => []);
            mediaMap[dateKey]!.add(mediaItem);
            totalProcessed++;
          }
        }
      }

      // Sort each date's media by creation time (newest first)
      for (final key in mediaMap.keys) {
        mediaMap[key]!.sort((a, b) => b.creationTime.compareTo(a.creationTime));
      }
    } catch (e) {
      print('Error scanning media: $e');
    }

    return mediaMap;
  }

  static Future<List<MediaItem>> getMediaForDate(String dateKey) async {
    final mediaMap = await scanMediaByDate();
    return mediaMap[dateKey] ?? [];
  }

  static Future<bool> deleteMediaItems(List<MediaItem> items) async {
    try {
      final assetIds = items.map((item) => item.id).toList();
      
      // Delete assets using photo_manager
      await PhotoManager.editor.deleteWithIds(assetIds);
      return true;
    } catch (e) {
      print('Error deleting media: $e');
      return false;
    }
  }

  /// Get file size for a media item (in bytes)
  static Future<int> getFileSize(MediaItem item) async {
    try {
      final asset = await AssetEntity.fromId(item.id);
      if (asset == null) return 0;
      
      final file = await asset.file;
      if (file == null) return 0;
      
      final size = await file.length();
      return size;
    } catch (e) {
      print('Error getting file size: $e');
      return 0;
    }
  }

  /// Get file sizes for multiple media items
  static Future<Map<String, int>> getFileSizes(List<MediaItem> items) async {
    final sizes = <String, int>{};
    for (final item in items) {
      final size = await getFileSize(item);
      sizes[item.id] = size;
    }
    return sizes;
  }

  /// Filter media to only items that are locally available (not iCloud-only).
  /// Returns the locally available list and the count of excluded (cloud) items.
  static Future<({List<MediaItem> local, int excludedCount})> filterToLocallyAvailable(
    List<MediaItem> items,
  ) async {
    if (items.isEmpty) {
      return (local: <MediaItem>[], excludedCount: 0);
    }
    final local = <MediaItem>[];
    for (final item in items) {
      try {
        final asset = await AssetEntity.fromId(item.id)
            .timeout(const Duration(seconds: 3), onTimeout: () => null);
        if (asset == null) continue;
        final available = await asset.isLocallyAvailable()
            .timeout(const Duration(seconds: 2), onTimeout: () => false);
        if (available) {
          local.add(item);
        }
      } catch (_) {
        // Treat errors (e.g. no network) as not available
      }
    }
    return (local: local, excludedCount: items.length - local.length);
  }
}

