import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/media_item.dart';
import '../utils/cache_cleanup.dart';
import '../utils/date_utils.dart';
import '../widgets/logo_widget.dart';
import '../widgets/review_card.dart';

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
  /// false = delete, true = keep. Absent = undecided (treated as keep on finish).
  final Map<String, bool> _decisions = {};
  // viewportFraction < 1 shows ~9% of adjacent images at each edge of the list
  final PageController _pageController = PageController(viewportFraction: 0.82);
  final Map<String, Uint8List> _videoThumbnailCache = {};
  final Map<String, Uint8List> _imageThumbnailCache = {};
  final List<String> _imageThumbnailOrder = [];
  final List<String> _videoThumbnailOrder = [];
  static const int _kMaxThumbnailCacheSize = 40;
  static const int _kMaxThumbnailDimension = 480;
  int _currentIndex = 0;
  Timer? _diskCacheCleanupTimer;

  @override
  void initState() {
    super.initState();
    _preloadVideoThumbnails();
    _preloadImageThumbnails();
    _preloadNextItem(0);
    _diskCacheCleanupTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => CacheCleanup.clearAllDiskCaches(),
    );
  }

  @override
  void dispose() {
    _diskCacheCleanupTimer?.cancel();
    _videoThumbnailCache.clear();
    _imageThumbnailCache.clear();
    _imageThumbnailOrder.clear();
    _videoThumbnailOrder.clear();
    _pageController.dispose();
    CacheCleanup.clearImageCache();
    CacheCleanup.clearAllDiskCaches();
    super.dispose();
  }

  Future<void> _preloadVideoThumbnails() async {
    final videoItems = widget.media.where((m) => m.isVideo).toList();
    for (final item in videoItems) {
      if (_videoThumbnailCache.containsKey(item.id)) continue;
      _loadVideoThumbnail(item.id);
    }
  }

  Future<void> _preloadImageThumbnails() async {
    final imageItems = widget.media.where((m) => !m.isVideo).toList();
    final futures = imageItems.map((item) async {
      if (_imageThumbnailCache.containsKey(item.id)) return;
      await _loadImageThumbnail(item.id);
    });
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
      final thumbnail = await asset.thumbnailDataWithSize(ThumbnailSize(thumbWidth, thumbHeight));
      if (thumbnail != null && mounted) {
        setState(() {
          _imageThumbnailCache[mediaId] = thumbnail;
          _imageThumbnailOrder.add(mediaId);
          while (_imageThumbnailCache.length > _kMaxThumbnailCacheSize &&
              _imageThumbnailOrder.isNotEmpty) {
            _imageThumbnailCache.remove(_imageThumbnailOrder.removeAt(0));
          }
        });
      }
    } catch (e) {
      print('Error loading image thumbnail for $mediaId: $e');
    }
  }

  Future<void> _loadVideoThumbnail(String mediaId) async {
    try {
      final asset = await AssetEntity.fromId(mediaId);
      if (asset == null) return;
      final thumbnail = await asset.thumbnailDataWithSize(const ThumbnailSize(480, 480));
      if (thumbnail != null && mounted) {
        setState(() {
          _videoThumbnailCache[mediaId] = thumbnail;
          _videoThumbnailOrder.add(mediaId);
          while (_videoThumbnailCache.length > _kMaxThumbnailCacheSize &&
              _videoThumbnailOrder.isNotEmpty) {
            _videoThumbnailCache.remove(_videoThumbnailOrder.removeAt(0));
          }
        });
      }
    } catch (e) {
      print('Error loading video thumbnail for $mediaId: $e');
    }
  }

  Future<void> _preloadNextItem(int index) async {
    if (index >= widget.media.length) return;
    final item = widget.media[index];
    try {
      final asset = await AssetEntity.fromId(item.id);
      if (asset != null && !item.isVideo) {
        await asset.file;
        if (!_imageThumbnailCache.containsKey(item.id)) {
          _loadImageThumbnail(item.id);
        }
      } else if (asset != null && item.isVideo && !_videoThumbnailCache.containsKey(item.id)) {
        _loadVideoThumbnail(item.id);
      }
    } catch (e) {
      print('Error preloading item $index: $e');
    }
  }

  void _decide(int index, bool keep) {
    setState(() {
      _decisions[widget.media[index].id] = keep;
    });
    if (index + 1 < widget.media.length) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Last item decided — auto-finish after the snap-back animation settles
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _finishReview();
      });
    }
  }

  void _finishReview() {
    final toDelete = widget.media.where((m) => _decisions[m.id] == false).toList();
    if (toDelete.isEmpty) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed(
        '/deletion-confirmation',
        arguments: {
          'mediaToDelete': toDelete,
          'videoThumbnailCache': _videoThumbnailCache,
          'imageThumbnailCache': _imageThumbnailCache,
        },
      );
    }
  }

  void _handleButtonDecide(bool keep) {
    _decide(_currentIndex, keep);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.media.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentMedia = widget.media[_currentIndex];
    final decidedCount = _decisions.length;

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
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    Text(
                      '${_currentIndex + 1} of ${widget.media.length}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: _finishReview,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              physics: const BouncingScrollPhysics(),
              itemCount: widget.media.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
                _preloadNextItem(index);
                if (index + 1 < widget.media.length) _preloadNextItem(index + 1);
              },
              itemBuilder: (context, index) {
                final mediaItem = widget.media[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final aspectRatio = mediaItem.width / mediaItem.height;
                      double cardWidth;
                      double cardHeight;
                      if (aspectRatio > constraints.maxWidth / constraints.maxHeight) {
                        cardWidth = constraints.maxWidth;
                        cardHeight = cardWidth / aspectRatio;
                      } else {
                        cardHeight = constraints.maxHeight;
                        cardWidth = cardHeight * aspectRatio;
                      }
                      return Center(
                        child: SizedBox(
                          width: cardWidth,
                          height: cardHeight,
                          child: ReviewCard(
                            key: ValueKey('${mediaItem.id}_$index'),
                            mediaItem: mediaItem,
                            cachedThumbnail: mediaItem.isVideo
                                ? _videoThumbnailCache[mediaItem.id]
                                : _imageThumbnailCache[mediaItem.id],
                            decision: _decisions[mediaItem.id],
                            onDecide: (keep) => _decide(index, keep),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(40, 16, 40, Platform.isAndroid ? 8 : 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ElevatedButton(
                        onPressed: () => _handleButtonDecide(false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        ),
                        child: const Text('❌ Delete', style: TextStyle(fontSize: 18)),
                      ),
                      ElevatedButton(
                        onPressed: () => _handleButtonDecide(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        ),
                        child: const Text('✅ Keep', style: TextStyle(fontSize: 18)),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, Platform.isAndroid ? 8.0 : 16.0),
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: decidedCount / widget.media.length,
                        minHeight: 4,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$decidedCount of ${widget.media.length} reviewed',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
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
