import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/media_item.dart';
import '../utils/date_utils.dart';
import '../widgets/logo_widget.dart';
import '../widgets/swipe_card.dart';

class SwipeScreen extends StatefulWidget {
  final String dateKey;
  final List<MediaItem> media;

  const SwipeScreen({
    super.key,
    required this.dateKey,
    required this.media,
  });

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen> {
  int _currentIndex = 0;
  final List<MediaItem> _mediaToDelete = [];
  final ValueNotifier<double> _dragOffsetNotifier = ValueNotifier<double>(0.0);
  // In-memory cache for video thumbnails (session only, cleared on dispose)
  final Map<String, Uint8List> _videoThumbnailCache = {};
  // In-memory cache for image thumbnails (session only, cleared on dispose)
  final Map<String, Uint8List> _imageThumbnailCache = {};

  @override
  void initState() {
    super.initState();
    final videos = widget.media.where((m) => m.isVideo).toList();
    final photos = widget.media.where((m) => !m.isVideo).toList();
    print('SwipeScreen initState: Total media=${widget.media.length}, Videos=${videos.length}, Photos=${photos.length}');
    for (final item in widget.media) {
      print('SwipeScreen initState: Item - isVideo: ${item.isVideo}, ID: ${item.id}');
    }
    
    // Preload thumbnails for all videos and images in the background
    _preloadVideoThumbnails();
    _preloadImageThumbnails();
    
    // Preload the first item's file
    _preloadNextItem(0);
  }
  
  @override
  void dispose() {
    // Clear the cache when screen is disposed
    _videoThumbnailCache.clear();
    _imageThumbnailCache.clear();
    _dragOffsetNotifier.dispose();
    super.dispose();
  }
  
  Future<void> _preloadVideoThumbnails() async {
    // Preload thumbnails for all videos in parallel
    final videoItems = widget.media.where((m) => m.isVideo).toList();
    print('Preloading thumbnails for ${videoItems.length} videos...');
    
    for (final item in videoItems) {
      // Skip if already cached
      if (_videoThumbnailCache.containsKey(item.id)) continue;
      
      // Load thumbnail in background
      _loadVideoThumbnail(item.id);
    }
  }
  
  Future<void> _preloadImageThumbnails() async {
    // Preload thumbnails for all images in parallel
    final imageItems = widget.media.where((m) => !m.isVideo).toList();
    print('Preloading thumbnails for ${imageItems.length} images...');
    
    // Load thumbnails in parallel batches
    final futures = imageItems.map((item) async {
      if (_imageThumbnailCache.containsKey(item.id)) return;
      await _loadImageThumbnail(item.id);
    });
    
    // Process in batches of 5 to avoid overwhelming the system
    for (int i = 0; i < futures.length; i += 5) {
      final batch = futures.skip(i).take(5).toList();
      await Future.wait(batch);
    }
  }
  
  Future<void> _loadImageThumbnail(String mediaId) async {
    try {
      final asset = await AssetEntity.fromId(mediaId);
      if (asset == null) return;
      
      final thumbnail = await asset.thumbnailDataWithSize(
        const ThumbnailSize(1200, 1200), // Higher quality for better display
      );
      
      if (thumbnail != null && mounted) {
        setState(() {
          _imageThumbnailCache[mediaId] = thumbnail;
        });
        print('Cached thumbnail for image: $mediaId');
      }
    } catch (e) {
      print('Error preloading image thumbnail for $mediaId: $e');
    }
  }
  
  Future<void> _loadVideoThumbnail(String mediaId) async {
    try {
      final asset = await AssetEntity.fromId(mediaId);
      if (asset == null) return;
      
      final thumbnail = await asset.thumbnailDataWithSize(
        const ThumbnailSize(800, 800), // Higher quality for better display
      );
      
      if (thumbnail != null && mounted) {
        setState(() {
          _videoThumbnailCache[mediaId] = thumbnail;
        });
        print('Cached thumbnail for video: $mediaId');
      }
    } catch (e) {
      print('Error preloading video thumbnail for $mediaId: $e');
    }
  }
  
  Future<void> _preloadNextItem(int index) async {
    if (index >= widget.media.length) return;
    
    final item = widget.media[index];
    try {
      // Preload the file by getting it (photo_manager will cache it)
      final asset = await AssetEntity.fromId(item.id);
      if (asset != null && !item.isVideo) {
        // For images, preload the file to warm the cache
        await asset.file;
        // Also ensure thumbnail is cached
        if (!_imageThumbnailCache.containsKey(item.id)) {
          _loadImageThumbnail(item.id);
        }
        print('Preloaded file for item $index');
      } else if (asset != null && item.isVideo && !_videoThumbnailCache.containsKey(item.id)) {
        // For videos, ensure thumbnail is cached
        _loadVideoThumbnail(item.id);
      }
    } catch (e) {
      print('Error preloading item $index: $e');
    }
  }

  void _handleSwipe(String direction) {
    final currentMedia = widget.media[_currentIndex];

    if (direction == 'left') {
      // Swipe left = delete
      _mediaToDelete.add(currentMedia);
    }
    // Swipe right = keep (do nothing)

    if (_currentIndex < widget.media.length - 1) {
      final nextIndex = _currentIndex + 1;
      // Preload next item in background
      _preloadNextItem(nextIndex);
      
      _dragOffsetNotifier.value = 0.0;
      setState(() {
        _currentIndex++;
      });
    } else {
      // All cards swiped
      if (_mediaToDelete.isEmpty) {
        // No items to delete, go to home screen
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        // Navigate to deletion confirmation
        Navigator.of(context).pushReplacementNamed(
          '/deletion-confirmation',
          arguments: _mediaToDelete,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentIndex >= widget.media.length) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentMedia = widget.media[_currentIndex];
    print('SwipeScreen: Showing item ${_currentIndex + 1}/${widget.media.length}');
    print('SwipeScreen: Media type - isVideo: ${currentMedia.isVideo}, ID: ${currentMedia.id}');
    print('SwipeScreen: Total media breakdown - Photos: ${widget.media.where((m) => !m.isVideo).length}, Videos: ${widget.media.where((m) => m.isVideo).length}');
    final progress = ((_currentIndex + 1) / widget.media.length) * 100;

    return Scaffold(
      body: Column(
          children: [
          LogoWidget(
            onTap: () => Navigator.of(context).pushReplacementNamed('/home'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppDateUtils.formatDateForDisplay(widget.dateKey, year: currentMedia.year),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${_currentIndex + 1} of ${widget.media.length}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) {
                  final currentOffset = _dragOffsetNotifier.value;
                  final newOffset = (currentOffset + details.delta.dx).clamp(-500.0, 500.0);
                  _dragOffsetNotifier.value = newOffset;
                },
                onPanEnd: (details) {
                  const threshold = 100.0;
                  final offset = _dragOffsetNotifier.value;
                  if (offset.abs() > threshold) {
                    _handleSwipe(offset > 0 ? 'right' : 'left');
                  } else {
                    _dragOffsetNotifier.value = 0.0;
                  }
                },
                child: ValueListenableBuilder<double>(
                  valueListenable: _dragOffsetNotifier,
                  builder: (context, dragOffset, child) {
                    return RepaintBoundary(
                      child: Transform.translate(
                        offset: Offset(dragOffset, 0),
                        child: Transform.rotate(
                          angle: dragOffset * 0.001,
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width - 40,
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: SwipeCard(
                              key: ValueKey(currentMedia.id),
                              mediaItem: currentMedia,
                              cachedThumbnail: currentMedia.isVideo 
                                  ? _videoThumbnailCache[currentMedia.id]
                                  : _imageThumbnailCache[currentMedia.id],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: () => _handleSwipe('left'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 15,
                    ),
                  ),
                  child: const Text('❌ Delete', style: TextStyle(fontSize: 18)),
                ),
                ElevatedButton(
                  onPressed: () => _handleSwipe('right'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 15,
                    ),
                  ),
                  child: const Text('✅ Keep', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

