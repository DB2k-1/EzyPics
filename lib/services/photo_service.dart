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
      print('PhotoService: Requesting asset path list...');
      // Get all albums
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.all,
        hasAll: true,
      );
      
      print('PhotoService: Found ${albums.length} albums');

      if (albums.isEmpty) {
        print('PhotoService: No albums found');
        return mediaMap;
      }

      // Use the first album (usually "Recent" or main album)
      final album = albums.first;
      print('PhotoService: Using album: ${album.name}');
      final assetCount = await album.assetCountAsync;
      print('PhotoService: Album has $assetCount assets');
      
      // Fetch assets in batches
      const batchSize = 500;
      int totalProcessed = 0;
      for (int start = 0; start < assetCount && start < 50000; start += batchSize) {
        final end = (start + batchSize < assetCount) ? start + batchSize : assetCount;
        print('PhotoService: Fetching assets $start to $end');
        final assets = await album.getAssetListRange(start: start, end: end);
        print('PhotoService: Got ${assets.length} assets in this batch');

        // Group by date
        for (final asset in assets) {
          if (asset.createDateTime != null) {
            final mediaItem = MediaItem(
              id: asset.id,
              path: asset.relativePath ?? '',
              creationTime: asset.createDateTime!,
              isVideo: asset.type == AssetType.video,
              width: asset.width,
              height: asset.height,
            );

            final dateKey = mediaItem.dateKey;
            mediaMap.putIfAbsent(dateKey, () => []);
            mediaMap[dateKey]!.add(mediaItem);
            totalProcessed++;
          }
        }
      }
      print('PhotoService: Processed $totalProcessed assets total');

      // Sort each date's media by creation time (newest first)
      for (final key in mediaMap.keys) {
        mediaMap[key]!.sort((a, b) => b.creationTime.compareTo(a.creationTime));
      }
      
      print('PhotoService: Media grouped by dates: ${mediaMap.keys.toList()}');
      for (final key in mediaMap.keys) {
        print('PhotoService: Date $key has ${mediaMap[key]!.length} items');
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
}

