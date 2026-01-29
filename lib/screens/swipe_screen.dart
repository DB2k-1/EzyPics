import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
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
  final List<MediaItem> _mediaToDelete = [];
  final CardSwiperController _swiperController = CardSwiperController();
  final Map<String, Uint8List> _videoThumbnailCache = {};
  final Map<String, Uint8List> _imageThumbnailCache = {};
  final List<String> _imageThumbnailOrder = [];
  final List<String> _videoThumbnailOrder = [];
  static const int _kMaxThumbnailCacheSize = 40;
  static const int _kMaxThumbnailDimension = 480;
  int _currentIndex = 0;

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
    _videoThumbnailCache.clear();
    _imageThumbnailCache.clear();
    _imageThumbnailOrder.clear();
    _videoThumbnailOrder.clear();
    _swiperController.dispose();
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
      
      final mediaItem = widget.media.firstWhere((item) => item.id == mediaId);
      int thumbWidth;
      int thumbHeight;
      if (mediaItem.width > mediaItem.height) {
        thumbWidth = _kMaxThumbnailDimension;
        thumbHeight = (_kMaxThumbnailDimension * mediaItem.height / mediaItem.width).round();
      } else {
        thumbHeight = _kMaxThumbnailDimension;
        thumbWidth = (_kMaxThumbnailDimension * mediaItem.width / mediaItem.height).round();
      }
      final thumbnail = await asset.thumbnailDataWithSize(
        ThumbnailSize(thumbWidth, thumbHeight),
      );
      
      if (thumbnail != null && mounted) {
        setState(() {
          _imageThumbnailCache[mediaId] = thumbnail;
          _imageThumbnailOrder.add(mediaId);
          while (_imageThumbnailCache.length > _kMaxThumbnailCacheSize &&
              _imageThumbnailOrder.isNotEmpty) {
            final evict = _imageThumbnailOrder.removeAt(0);
            _imageThumbnailCache.remove(evict);
          }
        });
        print('Cached thumbnail for image: $mediaId (${thumbWidth}x${thumbHeight})');
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
        const ThumbnailSize(480, 480),
      );
      
      if (thumbnail != null && mounted) {
        setState(() {
          _videoThumbnailCache[mediaId] = thumbnail;
          _videoThumbnailOrder.add(mediaId);
          while (_videoThumbnailCache.length > _kMaxThumbnailCacheSize &&
              _videoThumbnailOrder.isNotEmpty) {
            final evict = _videoThumbnailOrder.removeAt(0);
            _videoThumbnailCache.remove(evict);
          }
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

  Future<bool> _onSwipe(int previousIndex, int? currentIndex, CardSwiperDirection direction) async {
    final swipedMedia = widget.media[previousIndex];
    
    // Determine swipe direction
    if (direction == CardSwiperDirection.left) {
      // Swipe left = delete
      _mediaToDelete.add(swipedMedia);
    }
    // Swipe right = keep (do nothing)
    
    // Update current index
    final newIndex = currentIndex ?? (previousIndex + 1);
    setState(() {
      _currentIndex = newIndex;
    });
    
    // Preload next item in background
    if (newIndex < widget.media.length) {
      _preloadNextItem(newIndex);
    }
    
    // Check if we've reached the end
    if (newIndex >= widget.media.length) {
      // All cards swiped, navigate immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _onEnd();
        }
      });
    }
    
    return true; // Allow the swipe
  }

  void _onEnd() {
    // All cards swiped
    if (_mediaToDelete.isEmpty) {
      // No items to delete, go to home screen
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      // Navigate to deletion confirmation with cached thumbnails
      Navigator.of(context).pushReplacementNamed(
        '/deletion-confirmation',
        arguments: {
          'mediaToDelete': _mediaToDelete,
          'videoThumbnailCache': _videoThumbnailCache,
          'imageThumbnailCache': _imageThumbnailCache,
        },
      );
    }
  }

  void _handleButtonSwipe(String direction) {
    if (direction == 'left') {
      _swiperController.swipe(CardSwiperDirection.left);
    } else if (direction == 'right') {
      _swiperController.swipe(CardSwiperDirection.right);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.media.isEmpty) {
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
            child: CardSwiper(
              controller: _swiperController,
              cardsCount: widget.media.length,
              allowedSwipeDirection: const AllowedSwipeDirection.only(
                left: true,
                right: true,
              ),
              threshold: 50,
              maxAngle: 30,
              duration: const Duration(milliseconds: 200),
              scale: 0.9,
              numberOfCardsDisplayed: 1, // Only show one card at a time to prevent ghost cards
              isLoop: false, // Don't loop - prevent cards from reappearing
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
              onSwipe: _onSwipe,
              onEnd: _onEnd,
              cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
                if (index >= widget.media.length) {
                  return const SizedBox.shrink();
                }
                
                // Only build the card if it's the current index or hasn't been swiped yet
                // This prevents building cards that are already swiped away
                if (index < _currentIndex) {
                  return const SizedBox.shrink();
                }
                
                final mediaItem = widget.media[index];
                // Calculate aspect ratio
                final aspectRatio = mediaItem.width / mediaItem.height;
                final maxWidth = MediaQuery.of(context).size.width - 40;
                // Reduce height on Android to account for system navigation controls
                final heightMultiplier = Platform.isAndroid ? 0.55 : 0.6;
                final maxHeight = MediaQuery.of(context).size.height * heightMultiplier;
                
                // Calculate actual dimensions maintaining aspect ratio
                double cardWidth;
                double cardHeight;
                
                if (aspectRatio > maxWidth / maxHeight) {
                  // Media is wider - fit to width
                  cardWidth = maxWidth;
                  cardHeight = cardWidth / aspectRatio;
                } else {
                  // Media is taller - fit to height
                  cardHeight = maxHeight;
                  cardWidth = cardHeight * aspectRatio;
                }
                
                return Center(
                  child: SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    child: SwipeCard(
                      key: ValueKey('${mediaItem.id}_$index'), // Include index to force rebuild
                      mediaItem: mediaItem,
                      cachedThumbnail: mediaItem.isVideo 
                          ? _videoThumbnailCache[mediaItem.id]
                          : _imageThumbnailCache[mediaItem.id],
                    ),
                  ),
                );
              },
            ),
          ),
          // Bottom controls with Android-safe padding
          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    40,
                    20,
                    40,
                    Platform.isAndroid ? 8 : 20,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ElevatedButton(
                        onPressed: () => _handleButtonSwipe('left'),
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
                        onPressed: () => _handleButtonSwipe('right'),
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
                  padding: EdgeInsets.fromLTRB(
                    20.0,
                    0,
                    20.0,
                    Platform.isAndroid ? 8.0 : 20.0,
                  ),
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
