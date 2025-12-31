import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/media_item.dart';
import '../utils/date_utils.dart';

class CarouselCard extends StatelessWidget {
  final int year;
  final List<MediaItem> mediaItems;
  final String dateKey;

  const CarouselCard({
    super.key,
    required this.year,
    required this.mediaItems,
    required this.dateKey,
  });

  @override
  Widget build(BuildContext context) {
    if (mediaItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final firstItem = mediaItems.first;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Expanded(
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
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Text(
                  AppDateUtils.formatDateForDisplay(dateKey, year: year),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
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
    );
  }

  Future<Widget> _buildImageWidget(MediaItem item) async {
    try {
      final asset = await AssetEntity.fromId(item.id);
      if (asset == null) {
        return const Center(child: Icon(Icons.image, size: 100));
      }
      
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
      return const Center(child: Icon(Icons.image, size: 100));
    }
  }
}

