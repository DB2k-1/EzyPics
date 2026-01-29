import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/media_item.dart';
import '../services/photo_service.dart';
import '../services/share_service.dart';
import '../utils/date_utils.dart';
import '../utils/performance_logger.dart';
import '../widgets/logo_widget.dart';
import '../widgets/year_preview_card.dart';
import '../widgets/swipe_card.dart';

class CarouselScreen extends StatefulWidget {
  const CarouselScreen({super.key});

  @override
  State<CarouselScreen> createState() => _CarouselScreenState();
}

class _CarouselScreenState extends State<CarouselScreen> with TickerProviderStateMixin {
  Map<String, List<MediaItem>> _mediaMap = {};
  bool _isScanning = false;
  Timer? _galleryTimer;
  String _selectedDateKey = AppDateUtils.getTodayDateKey();
  bool _hasInitialized = false;
  int _currentYearIndex = 0;
  bool _galleryStarted = false;
  bool _navigationTriggered = false;
  AnimationController? _fadeController;
  Map<int, List<MediaItem>> _mediaByYear = {};
  List<int> _years = [];
  Map<int, Uint8List?> _thumbnailCache = {}; // Cache thumbnails by year
  bool _thumbnailsLoading = false;
  
  // Review mode state
  bool _isReviewMode = false;
  bool _isComplete = false;
  bool _reviewEndTriggered = false;
  List<MediaItem> _reviewMedia = [];
  final List<MediaItem> _mediaToDelete = [];
  final CardSwiperController _swiperController = CardSwiperController();
  final Map<String, Uint8List> _videoThumbnailCache = {};
  final Map<String, Uint8List> _imageThumbnailCache = {};
  final List<String> _imageThumbnailOrder = [];
  final List<String> _videoThumbnailOrder = [];
  static const int _kMaxThumbnailCacheSize = 40;
  static const int _kMaxThumbnailDimension = 480;
  int _currentIndex = 0;
  Timer? _batchUpdateTimer;
  final Map<String, Uint8List> _pendingThumbnailUpdates = {};

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitialized) {
      _hasInitialized = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Map && args['dateKey'] != null) {
        _selectedDateKey = args['dateKey'] as String;
      }
      _galleryStarted = false;
      _navigationTriggered = false;
      _currentYearIndex = 0;
      _scanLibrary();
    }
  }

  @override
  void dispose() {
    _galleryTimer?.cancel();
    _fadeController?.dispose();
    _swiperController.dispose();
    _batchUpdateTimer?.cancel();
    _videoThumbnailCache.clear();
    _imageThumbnailCache.clear();
    _imageThumbnailOrder.clear();
    _videoThumbnailOrder.clear();
    _pendingThumbnailUpdates.clear();
    super.dispose();
  }

  Future<void> _scanLibrary() async {
    PerformanceLogger.start('scan_library');
    setState(() => _isScanning = true);
    try {
      final scannedMedia = await PhotoService.scanMediaByDate()
          .timeout(const Duration(seconds: 30), onTimeout: () {
        PerformanceLogger.log('scan_library timeout after 30s', level: 'error');
        return <String, List<MediaItem>>{};
      });
      PerformanceLogger.end('scan_library', threshold: const Duration(seconds: 5));
      if (mounted) {
        setState(() {
          _mediaMap = scannedMedia;
          _isScanning = false;
        });
        _startGalleryAnimation();
      }
    } catch (e) {
      PerformanceLogger.log('Error scanning library: $e', level: 'error');
      print('Error scanning library: $e');
      if (mounted) {
        setState(() {
          _isScanning = false;
          _mediaMap = {};
        });
        _startGalleryAnimation();
      }
    }
  }

  void _startGalleryAnimation() {
    if (_galleryStarted) {
      return;
    }
    
    _galleryTimer?.cancel();
    _galleryTimer = null;
    _navigationTriggered = false;
    _galleryStarted = true;

    final mediaForDate = _mediaMap[_selectedDateKey] ?? [];
    
    if (mediaForDate.isEmpty) {
      return;
    }

    _startGalleryWithMedia(mediaForDate);
  }

  Future<void> _preloadThumbnails(Map<int, List<MediaItem>> mediaByYear, List<int> years) async {
    PerformanceLogger.start('preload_preview_thumbnails');
    setState(() => _thumbnailsLoading = true);
    
    final thumbnailCache = <int, Uint8List?>{};
    
    // Load thumbnails for all years in parallel with timeout
    final futures = years.map((year) async {
      final firstItem = mediaByYear[year]!.first;
      try {
        PerformanceLogger.start('load_thumbnail_year_$year');
        final asset = await AssetEntity.fromId(firstItem.id)
            .timeout(const Duration(seconds: 5), onTimeout: () => null);
        if (asset == null) {
          PerformanceLogger.end('load_thumbnail_year_$year');
          return MapEntry(year, null as Uint8List?);
        }
        
        // Use smaller thumbnails for preview (300x300 is sufficient)
        final thumbnail = await asset.thumbnailDataWithSize(
          const ThumbnailSize(300, 300),
        ).timeout(const Duration(seconds: 5), onTimeout: () => null);
        PerformanceLogger.end('load_thumbnail_year_$year', threshold: const Duration(milliseconds: 500));
        return MapEntry(year, thumbnail);
      } catch (e) {
        PerformanceLogger.log('Error loading thumbnail for year $year: $e', level: 'error');
        print('Error loading thumbnail for year $year: $e');
        return MapEntry(year, null as Uint8List?);
      }
    });
    
    final results = await Future.wait(futures);
    for (final entry in results) {
      thumbnailCache[entry.key] = entry.value;
    }
    
    PerformanceLogger.end('preload_preview_thumbnails', threshold: const Duration(seconds: 3));
    
    if (mounted) {
      setState(() {
        _thumbnailCache = thumbnailCache;
        _thumbnailsLoading = false;
      });
      _startAnimationAfterPreload(years);
    }
  }

  void _startGalleryWithMedia(List<MediaItem> mediaForDate) {
    final mediaByYear = <int, List<MediaItem>>{};
    for (final item in mediaForDate) {
      mediaByYear.putIfAbsent(item.year, () => []).add(item);
    }
    final years = mediaByYear.keys.toList()..sort((a, b) => b.compareTo(a));

    // Store years and media
    setState(() {
      _mediaByYear = mediaByYear;
      _years = years;
      _currentYearIndex = 0;
    });

    if (years.isEmpty) {
      return;
    }
    
    _preloadThumbnails(mediaByYear, years);
  }

  void _startAnimationAfterPreload(List<int> years) {
    if (!mounted || _navigationTriggered) return;
    
    // Preload swipe content early - start while preview is showing
    final media = _mediaMap[_selectedDateKey] ?? [];
    if (media.isNotEmpty) {
      _preloadSwipeContentEarly(media);
    }
    
    // Create animation controller
    // Total: 1000ms (150ms fade in + 700ms full opacity + 150ms fade out)
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
      value: 0.0,
    );
    
    setState(() {
      _fadeController = controller;
      _currentYearIndex = 0;
    });

    // Start first card animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _navigationTriggered) return;
      
      controller.forward();
      
      if (years.length > 1) {
        // Cycle through years - wait 850ms (fade in + full opacity, before fade out starts)
        // This way we navigate to next card just as fade out begins
        _galleryTimer = Timer(const Duration(milliseconds: 850), () {
          if (mounted && !_navigationTriggered) {
            _cycleToNextYear(years, controller);
          }
        });
      } else {
        // Only one year - navigate after showing it (850ms = fade in + full opacity)
        _galleryTimer = Timer(const Duration(milliseconds: 850), () {
          if (mounted && !_navigationTriggered) {
            _navigateToSwipe();
          }
        });
      }
    });
  }
  
  void _preloadSwipeContentEarly(List<MediaItem> media) {
    // Start preloading in background immediately
    _reviewMedia = media;
    _preloadVideoThumbnails(media);
    _preloadImageThumbnails(media);
    _preloadNextItem(0);
  }

  void _cycleToNextYear(List<int> years, AnimationController controller) {
    if (!mounted || _navigationTriggered) return;
    
    // Check if all years shown
    if (_currentYearIndex >= years.length - 1) {
      // Navigate immediately - we've shown all years
      if (mounted && !_navigationTriggered) {
        _navigateToSwipe();
      }
      return;
    }

    // The timer fires after 850ms (just before fade out starts at 0.85)
    // Reset and show the next card immediately for smooth transition
    controller.reset();
    setState(() {
      _currentYearIndex++;
    });
    
    // Start next animation immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _navigationTriggered) return;
      
      controller.forward();
      
      // For the last year, navigate after showing it (850ms)
      // For other years, cycle to next after 850ms
      if (_currentYearIndex >= years.length - 1) {
        _galleryTimer = Timer(const Duration(milliseconds: 850), () {
          if (mounted && !_navigationTriggered) {
            _navigateToSwipe();
          }
        });
      } else {
        _galleryTimer = Timer(const Duration(milliseconds: 850), () {
          if (mounted && !_navigationTriggered) {
            _cycleToNextYear(years, controller);
          }
        });
      }
    });
  }

  Future<void> _navigateToSwipe() async {
    if (_navigationTriggered) return;
    
    _navigationTriggered = true;
    final media = _mediaMap[_selectedDateKey] ?? [];
    
    _galleryTimer?.cancel();
    _fadeController?.stop();
    
    if (!mounted) return;

    // Only filter out cloud-only media when we're offline (no connectivity).
    // When online, show all media so iCloud can deliver on demand.
    List<MediaItem> mediaToReview = media;
    final connectivityResults = await Connectivity().checkConnectivity();
    final isOffline = connectivityResults.isEmpty ||
        connectivityResults.every((r) => r == ConnectivityResult.none);

    if (isOffline) {
      final filtered = await PhotoService.filterToLocallyAvailable(media);
      mediaToReview = filtered.local;

      if (filtered.excludedCount > 0 && mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Cloud photos not available'),
            content: Text(
              'Only locally stored photos and videos can be shown during review '
              'because there is no internet connection.\n\n'
              '${filtered.excludedCount} item${filtered.excludedCount == 1 ? '' : 's'} in the cloud ${filtered.excludedCount == 1 ? 'has' : 'have'} been skipped. '
              'You can review ${filtered.local.length} locally available item${filtered.local.length == 1 ? '' : 's'}.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

      if (mediaToReview.isEmpty && mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('No local photos available'),
            content: const Text(
              'All photos and videos for this date appear to be in the cloud and '
              'are not available without connectivity. Connect to the internet to '
              'download them, or try another date.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacementNamed('/home');
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    }

    if (!mounted) return;

    // Preload swipe content (all media when online, or filtered when offline)
    _preloadSwipeContent(mediaToReview);
  }
  
  Future<void> _preloadSwipeContent(List<MediaItem> media) async {
    // Use the provided media list (filtered to locally available)
    if (mounted) {
      setState(() {
        _reviewMedia = media;
        _isReviewMode = true;
        _isComplete = false;
        _reviewEndTriggered = false;
        _currentIndex = 0;
        _mediaToDelete.clear();
      });
    }
  }
  
  Future<void> _preloadVideoThumbnails(List<MediaItem> media) async {
    PerformanceLogger.start('preload_video_thumbnails');
    final videoItems = media.where((m) => m.isVideo).toList();
    
    // Process in smaller batches to avoid overwhelming the system
    const batchSize = 3;
    for (int i = 0; i < videoItems.length; i += batchSize) {
      final batch = videoItems.skip(i).take(batchSize).toList();
      final futures = batch.map((item) {
        if (_videoThumbnailCache.containsKey(item.id)) return Future.value();
        return _loadVideoThumbnail(item.id);
      });
      
      await Future.wait(futures);
      // Small delay between batches to prevent blocking
      if (i + batchSize < videoItems.length) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }
    PerformanceLogger.end('preload_video_thumbnails', threshold: const Duration(seconds: 5));
  }
  
  Future<void> _preloadImageThumbnails(List<MediaItem> media) async {
    PerformanceLogger.start('preload_image_thumbnails');
    final imageItems = media.where((m) => !m.isVideo).toList();
    
    // Process in smaller batches
    const batchSize = 3;
    for (int i = 0; i < imageItems.length; i += batchSize) {
      final batch = imageItems.skip(i).take(batchSize).toList();
      final futures = batch.map((item) async {
        if (_imageThumbnailCache.containsKey(item.id)) return;
        await _loadImageThumbnail(item.id);
      });
      
      await Future.wait(futures);
      // Small delay between batches
      if (i + batchSize < imageItems.length) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }
    PerformanceLogger.end('preload_image_thumbnails', threshold: const Duration(seconds: 5));
  }
  
  Future<void> _loadImageThumbnail(String mediaId) async {
    try {
      PerformanceLogger.start('load_image_thumb_$mediaId');
      final asset = await AssetEntity.fromId(mediaId)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (asset == null) return;
      
      final mediaItem = _reviewMedia.firstWhere((item) => item.id == mediaId);
      
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
      ).timeout(const Duration(seconds: 5), onTimeout: () => null);
      
      if (thumbnail != null && mounted) {
        _pendingThumbnailUpdates[mediaId] = thumbnail;
        _scheduleBatchUpdate();
      }
      PerformanceLogger.end('load_image_thumb_$mediaId', threshold: const Duration(milliseconds: 500));
    } catch (e) {
      PerformanceLogger.log('Error preloading image thumbnail for $mediaId: $e', level: 'error');
      print('Error preloading image thumbnail for $mediaId: $e');
    }
  }
  
  Future<void> _loadVideoThumbnail(String mediaId) async {
    try {
      PerformanceLogger.start('load_video_thumb_$mediaId');
      final asset = await AssetEntity.fromId(mediaId)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (asset == null) return;
      
      final thumbnail = await asset.thumbnailDataWithSize(
        const ThumbnailSize(480, 480),
      ).timeout(const Duration(seconds: 5), onTimeout: () => null);
      
      if (thumbnail != null && mounted) {
        _pendingThumbnailUpdates['video_$mediaId'] = thumbnail;
        _scheduleBatchUpdate();
      }
      PerformanceLogger.end('load_video_thumb_$mediaId', threshold: const Duration(milliseconds: 500));
    } catch (e) {
      PerformanceLogger.log('Error preloading video thumbnail for $mediaId: $e', level: 'error');
      print('Error preloading video thumbnail for $mediaId: $e');
    }
  }
  
  /// Batch setState calls to reduce rebuilds; evict oldest thumbnails when over cap
  void _scheduleBatchUpdate() {
    _batchUpdateTimer?.cancel();
    _batchUpdateTimer = Timer(const Duration(milliseconds: 100), () {
      if (!mounted || _pendingThumbnailUpdates.isEmpty) return;
      
      setState(() {
        for (final entry in _pendingThumbnailUpdates.entries) {
          if (entry.key.startsWith('video_')) {
            final mediaId = entry.key.substring(6);
            _videoThumbnailCache[mediaId] = entry.value;
            _videoThumbnailOrder.add(mediaId);
            while (_videoThumbnailCache.length > _kMaxThumbnailCacheSize &&
                _videoThumbnailOrder.isNotEmpty) {
              final evict = _videoThumbnailOrder.removeAt(0);
              _videoThumbnailCache.remove(evict);
            }
          } else {
            _imageThumbnailCache[entry.key] = entry.value;
            _imageThumbnailOrder.add(entry.key);
            while (_imageThumbnailCache.length > _kMaxThumbnailCacheSize &&
                _imageThumbnailOrder.isNotEmpty) {
              final evict = _imageThumbnailOrder.removeAt(0);
              _imageThumbnailCache.remove(evict);
            }
          }
        }
        _pendingThumbnailUpdates.clear();
      });
    });
  }
  
  Future<void> _preloadNextItem(int index) async {
    if (index >= _reviewMedia.length) return;
    
    final item = _reviewMedia[index];
    try {
      PerformanceLogger.start('preload_item_$index');
      final asset = await AssetEntity.fromId(item.id)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (asset != null && !item.isVideo) {
        // Only preload file if thumbnail not cached
        if (!_imageThumbnailCache.containsKey(item.id)) {
          await asset.file.timeout(const Duration(seconds: 5), onTimeout: () => null);
          _loadImageThumbnail(item.id);
        }
      } else if (asset != null && item.isVideo && !_videoThumbnailCache.containsKey(item.id)) {
        _loadVideoThumbnail(item.id);
      }
      PerformanceLogger.end('preload_item_$index', threshold: const Duration(milliseconds: 1000));
    } catch (e) {
      PerformanceLogger.log('Error preloading item $index: $e', level: 'error');
      print('Error preloading item $index: $e');
    }
  }
  
  Future<bool> _onSwipe(int previousIndex, int? currentIndex, CardSwiperDirection direction) async {
    PerformanceLogger.start('on_swipe');
    final swipedMedia = _reviewMedia[previousIndex];
    final wasVideo = swipedMedia.isVideo;
    
    if (direction == CardSwiperDirection.left) {
      _mediaToDelete.add(swipedMedia);
    }
    
    final newIndex = currentIndex ?? (previousIndex + 1);
    
    // Preload next item immediately (before setState) to start loading in parallel
    if (newIndex < _reviewMedia.length) {
      // Don't await - let it run in background
      _preloadNextItem(newIndex);
    }
    
    setState(() {
      _currentIndex = newIndex;
    });
    
    // Also preload the item after next (lookahead) for smoother transitions
    if (newIndex + 1 < _reviewMedia.length) {
      _preloadNextItem(newIndex + 1);
    }
    
    PerformanceLogger.end('on_swipe', threshold: const Duration(milliseconds: 100));
    if (wasVideo) {
      PerformanceLogger.log('Swiped away video, next item: ${newIndex < _reviewMedia.length ? _reviewMedia[newIndex].isVideo ? "video" : "image" : "none"}', level: 'info');
    }
    
    if (newIndex >= _reviewMedia.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _onReviewEnd();
        }
      });
    }
    
    return true;
  }
  
  void _onReviewEnd() {
    // Prevent multiple calls
    if (_reviewEndTriggered || !mounted) return;
    _reviewEndTriggered = true;
    
    // Transition to completion state first (keeps header persistent)
    setState(() {
      _isComplete = true;
    });
    
    // Navigate after a brief delay to allow smooth transition
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      
      try {
        if (_mediaToDelete.isEmpty) {
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
      } catch (e) {
        PerformanceLogger.log('Error navigating after review: $e', level: 'error');
        print('Error navigating after review: $e');
        // Fallback: try navigating to home
        try {
          Navigator.of(context).pushReplacementNamed('/home');
        } catch (e2) {
          print('Fallback navigation also failed: $e2');
        }
      }
    });
  }
  
  void _handleButtonSwipe(String direction) {
    if (direction == 'left') {
      _swiperController.swipe(CardSwiperDirection.left);
    } else if (direction == 'right') {
      _swiperController.swipe(CardSwiperDirection.right);
    }
  }

  Future<void> _handleShare(MediaItem mediaItem) async {
    // Show loading dialog immediately
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false, // Prevent dismissing by back button
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Sharing',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    // Wait for dialog to render before starting branding
    await Future.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;

    try {
      // Now start the branding and sharing process
      await ShareService.shareMedia(mediaItem);
    } finally {
      // Hide loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPreviewing = !_isReviewMode && _years.isNotEmpty && _fadeController != null && !_thumbnailsLoading;
    
    return Scaffold(
      body: Column(
        children: [
          // Persistent header - always shown
          LogoWidget(
            selectedDateKey: _selectedDateKey,
            onTap: (_isReviewMode || _isComplete) ? () {
              try {
                Navigator.of(context).pushReplacementNamed('/home');
              } catch (e) {
                print('Error navigating from header tap: $e');
              }
            } : null,
          ),
          // Content area - transitions between preview, review, and completion
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              child: _isComplete
                  ? _buildCompletionContent()
                  : _isReviewMode
                      ? _buildReviewContent()
                      : _buildPreviewContent(isPreviewing),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPreviewContent(bool isPreviewing) {
    return _isScanning || _thumbnailsLoading
        ? const Center(
            key: ValueKey('loading'),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text('Loading media...'),
              ],
            ),
          )
        : _years.isEmpty
            ? const Center(
                key: ValueKey('empty'),
                child: Text(
                  'No media to review',
                  style: TextStyle(fontSize: 18),
                ),
              )
            : isPreviewing && _currentYearIndex < _years.length
                ? Center(
                    key: ValueKey('preview'),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: YearPreviewCard(
                        key: ValueKey(_years[_currentYearIndex]),
                        year: _years[_currentYearIndex],
                        totalItemsForYear: _mediaByYear[_years[_currentYearIndex]]!.length,
                        thumbnailData: _thumbnailCache[_years[_currentYearIndex]],
                        isVideo: _mediaByYear[_years[_currentYearIndex]]!.first.isVideo,
                        fadeAnimation: _fadeController!,
                      ),
                    ),
                  )
                : const Center(
                    key: ValueKey('waiting'),
                    child: CircularProgressIndicator(),
                  );
  }
  
  Widget _buildReviewContent() {
    if (_reviewMedia.isEmpty) {
      return const Center(
        key: ValueKey('review-empty'),
        child: CircularProgressIndicator(),
      );
    }

    final currentMedia = _reviewMedia[_currentIndex];
    final progress = ((_currentIndex + 1) / _reviewMedia.length) * 100;

    return Column(
      key: const ValueKey('review'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppDateUtils.formatDateForDisplay(_selectedDateKey, year: currentMedia.year),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_currentIndex + 1} of ${_reviewMedia.length}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _handleShare(currentMedia),
                    child: Icon(
                      Platform.isIOS ? Icons.ios_share : Icons.share,
                      size: 20,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: CardSwiper(
            controller: _swiperController,
            cardsCount: _reviewMedia.length,
            allowedSwipeDirection: const AllowedSwipeDirection.only(
              left: true,
              right: true,
            ),
            threshold: 50,
            maxAngle: 30,
            duration: const Duration(milliseconds: 200),
            scale: 0.9,
            numberOfCardsDisplayed: 1,
            isLoop: false,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
            onSwipe: _onSwipe,
            onEnd: _onReviewEnd,
            cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
              if (index >= _reviewMedia.length) {
                return const SizedBox.shrink();
              }
              
              if (index < _currentIndex) {
                return const SizedBox.shrink();
              }
              
              final mediaItem = _reviewMedia[index];
              final aspectRatio = mediaItem.width / mediaItem.height;
              final maxWidth = MediaQuery.of(context).size.width - 40;
              // Reduce height on Android to account for system navigation controls
              final heightMultiplier = Platform.isAndroid ? 0.55 : 0.6;
              final maxHeight = MediaQuery.of(context).size.height * heightMultiplier;
              
              double cardWidth;
              double cardHeight;
              
              if (aspectRatio > maxWidth / maxHeight) {
                cardWidth = maxWidth;
                cardHeight = cardWidth / aspectRatio;
              } else {
                cardHeight = maxHeight;
                cardWidth = cardHeight * aspectRatio;
              }
              
              return Center(
                child: SizedBox(
                  width: cardWidth,
                  height: cardHeight,
                  child: SwipeCard(
                    key: ValueKey('${mediaItem.id}_$index'),
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
    );
  }
  
  Widget _buildCompletionContent() {
    return Center(
      key: const ValueKey('completion'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle,
            size: 80,
            color: Colors.green,
          ),
          const SizedBox(height: 24),
          const Text(
            'Review Complete!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _mediaToDelete.isEmpty
                ? 'No items marked for deletion'
                : '${_mediaToDelete.length} item${_mediaToDelete.length == 1 ? '' : 's'} marked for deletion',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          const CircularProgressIndicator(),
        ],
      ),
    );
  }
}
