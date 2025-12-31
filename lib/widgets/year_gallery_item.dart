import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/media_item.dart';

class YearGalleryItem extends StatelessWidget {
  final int year;
  final List<MediaItem> mediaItems;
  final Animation<double> fadeAnimation;

  const YearGalleryItem({
    super.key,
    required this.year,
    required this.mediaItems,
    required this.fadeAnimation,
  });

  @override
  Widget build(BuildContext context) {
    if (mediaItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final firstItem = mediaItems.first;

    return FadeTransition(
      opacity: fadeAnimation,
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
                child: FutureBuilder<Widget>(
                  future: _buildImageWidget(firstItem),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return snapshot.data ?? const Center(child: Icon(Icons.image));
                  },
                ),
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
                    '${mediaItems.length} ${mediaItems.length == 1 ? 'item' : 'items'}',
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
    );
  }

  Future<Widget> _buildImageWidget(MediaItem item) async {
    try {
      final asset = await AssetEntity.fromId(item.id);
      if (asset == null) {
        return const Center(child: Icon(Icons.image, size: 100));
      }
      
      // For videos, use thumbnail
      if (item.isVideo) {
        final thumbnail = await asset.thumbnailDataWithSize(
          const ThumbnailSize(300, 300),
        );
        if (thumbnail != null) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(
                thumbnail,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(child: Icon(Icons.videocam, size: 100));
                },
              ),
              const Center(
                child: Icon(
                  Icons.play_circle_filled,
                  color: Colors.white,
                  size: 60,
                ),
              ),
            ],
          );
        } else {
          return const Center(child: Icon(Icons.videocam, size: 100));
        }
      }
      
      // For images, use the file directly
      final file = await asset.file;
      if (file == null) {
        return const Center(child: Icon(Icons.image, size: 100));
      }
      return Image.file(
        file,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return const Center(child: Icon(Icons.image, size: 100));
        },
      );
    } catch (e) {
      print('Error building image widget: $e');
      return Center(
        child: Icon(
          item.isVideo ? Icons.videocam : Icons.image,
          size: 100,
        ),
      );
    }
  }
}

