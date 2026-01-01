import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/media_item.dart';
import '../services/photo_service.dart';
import '../utils/date_utils.dart';
import '../widgets/logo_widget.dart';
import '../widgets/year_preview_card.dart';

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
      print('CarouselScreen initialized with dateKey: $_selectedDateKey');
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
    super.dispose();
  }

  Future<void> _scanLibrary() async {
    setState(() => _isScanning = true);
    try {
      print('Starting media scan...');
      final scannedMedia = await PhotoService.scanMediaByDate();
      print('Media scan complete. Found ${scannedMedia.length} dates with media.');
      if (mounted) {
        setState(() {
          _mediaMap = scannedMedia;
          _isScanning = false;
        });
        _startGalleryAnimation();
      }
    } catch (e) {
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
      print('Gallery already started, skipping');
      return;
    }
    
    _galleryTimer?.cancel();
    _galleryTimer = null;
    _navigationTriggered = false;
    _galleryStarted = true;

    print('Gallery: Available dates in mediaMap: ${_mediaMap.keys.toList()}');
    print('Gallery: Looking for dateKey: $_selectedDateKey');
    final mediaForDate = _mediaMap[_selectedDateKey] ?? [];
    print('Starting gallery animation. Media for date $_selectedDateKey: ${mediaForDate.length} items');
    
    if (mediaForDate.isEmpty) {
      print('No media found for date $_selectedDateKey');
      return;
    }

    _startGalleryWithMedia(mediaForDate);
  }

  Future<void> _preloadThumbnails(Map<int, List<MediaItem>> mediaByYear, List<int> years) async {
    setState(() => _thumbnailsLoading = true);
    print('Pre-loading thumbnails for ${years.length} years...');
    
    final thumbnailCache = <int, Uint8List?>{};
    
    // Load thumbnails for all years in parallel
    final futures = years.map((year) async {
      final firstItem = mediaByYear[year]!.first;
      try {
        final asset = await AssetEntity.fromId(firstItem.id);
        if (asset == null) {
          print('Asset is null for year $year');
          return MapEntry(year, null as Uint8List?);
        }
        
        // Use thumbnails for both images and videos (300x300 is sufficient for preview)
        final thumbnail = await asset.thumbnailDataWithSize(
          const ThumbnailSize(300, 300),
        );
        print('Loaded thumbnail for year $year: ${thumbnail != null ? 'success' : 'failed'}');
        return MapEntry(year, thumbnail);
      } catch (e) {
        print('Error loading thumbnail for year $year: $e');
        return MapEntry(year, null as Uint8List?);
      }
    });
    
    final results = await Future.wait(futures);
    for (final entry in results) {
      thumbnailCache[entry.key] = entry.value;
    }
    
    if (mounted) {
      setState(() {
        _thumbnailCache = thumbnailCache;
        _thumbnailsLoading = false;
      });
      print('Thumbnail pre-loading complete. Starting animation...');
      _startAnimationAfterPreload(years);
    }
  }

  void _startGalleryWithMedia(List<MediaItem> mediaForDate) {
    final mediaByYear = <int, List<MediaItem>>{};
    for (final item in mediaForDate) {
      mediaByYear.putIfAbsent(item.year, () => []).add(item);
    }
    final years = mediaByYear.keys.toList()..sort((a, b) => b.compareTo(a));
    print('Years found: $years (${years.length} years)');
    
    for (final year in years) {
      final items = mediaByYear[year]!;
      print('  Year $year: ${items.length} items');
    }

    // Store years and media
    setState(() {
      _mediaByYear = mediaByYear;
      _years = years;
      _currentYearIndex = 0;
    });

    if (years.isEmpty) {
      print('No years found, cannot start gallery');
      return;
    }
    
    print('Pre-loading thumbnails before starting gallery preview...');
    _preloadThumbnails(mediaByYear, years);
  }

  void _startAnimationAfterPreload(List<int> years) {
    if (!mounted || _navigationTriggered) return;
    
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

    print('Starting gallery preview with ${years.length} years');
    
    // Start first card animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _navigationTriggered) return;
      
      print('Fading in first year: ${years[0]}');
      controller.forward();
      
      if (years.length > 1) {
        // Cycle through years - wait 1000ms (full animation duration)
        _galleryTimer = Timer(const Duration(milliseconds: 1000), () {
          if (mounted && !_navigationTriggered) {
            _cycleToNextYear(years, controller);
          }
        });
      } else {
        // Only one year
        _galleryTimer = Timer(const Duration(milliseconds: 1000), () {
          if (mounted && !_navigationTriggered) {
            _navigateToSwipe();
          }
        });
      }
    });
  }

  void _cycleToNextYear(List<int> years, AnimationController controller) {
    if (!mounted || _navigationTriggered) return;
    
    print('[ANIMATION] Cycling to next year. Current index: $_currentYearIndex, Total: ${years.length}');
    
    // Check if all years shown
    if (_currentYearIndex >= years.length - 1) {
      print('[ANIMATION] All years shown, navigating in 0.5s');
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_navigationTriggered) {
          _navigateToSwipe();
        }
      });
      return;
    }

    // The timer fires after 1000ms when animation should be complete (at 1.0, fully faded out)
    // Don't use reverse() - it causes the card to reappear during reverse
    // Just reset and show the next card
    controller.reset();
    setState(() {
      _currentYearIndex++;
    });
    
    // Start next animation immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _navigationTriggered) return;
      
      print('[ANIMATION] Starting animation for year ${years[_currentYearIndex]}');
      controller.forward();
      
      _galleryTimer = Timer(const Duration(milliseconds: 1000), () {
        if (mounted && !_navigationTriggered) {
          _cycleToNextYear(years, controller);
        }
      });
    });
  }

  void _navigateToSwipe() {
    if (_navigationTriggered) return;
    
    _navigationTriggered = true;
    print('Navigating to swipe screen - preview complete');
    final media = _mediaMap[_selectedDateKey] ?? [];
    print('Media count for navigation: ${media.length}');
    
    _galleryTimer?.cancel();
    _fadeController?.stop();
    
    if (!mounted) return;
    
    try {
      Navigator.of(context).pushReplacementNamed(
        '/swipe',
        arguments: {'dateKey': _selectedDateKey, 'media': media},
      );
      print('Navigation command sent successfully');
    } catch (e, stackTrace) {
      print('Navigation error: $e');
      print('Stack trace: $stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPreviewing = _years.isNotEmpty && _fadeController != null && !_thumbnailsLoading;
    
    return Scaffold(
      body: Column(
        children: [
          LogoWidget(selectedDateKey: _selectedDateKey),
          if (!isPreviewing)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    Navigator.of(context).pushNamed('/settings');
                  },
                ),
              ],
            ),
          Expanded(
            child: _isScanning || _thumbnailsLoading
                ? const Center(
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
                        child: Text(
                          'No media to review',
                          style: TextStyle(fontSize: 18),
                        ),
                      )
                    : isPreviewing && _currentYearIndex < _years.length
                        ? Center(
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
                        : const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }
}
