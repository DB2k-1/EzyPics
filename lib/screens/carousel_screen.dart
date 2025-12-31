import 'dart:async';
import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/photo_service.dart';
import '../utils/date_utils.dart';
import '../widgets/logo_widget.dart';
import '../widgets/year_gallery_item.dart';

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
  int _visibleYearCount = 0;
  bool _galleryStarted = false;
  bool _navigationTriggered = false;
  Map<int, AnimationController> _fadeControllers = {};
  Map<int, List<MediaItem>> _mediaByYear = {};
  List<int> _years = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitialized) {
      _hasInitialized = true;
      // Get selected date from arguments if provided
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Map && args['dateKey'] != null) {
        _selectedDateKey = args['dateKey'] as String;
      }
      print('CarouselScreen initialized with dateKey: $_selectedDateKey');
      // Reset gallery state
      _galleryStarted = false;
      _navigationTriggered = false;
      _visibleYearCount = 0;
      _scanLibrary();
    }
  }

  @override
  void dispose() {
    _galleryTimer?.cancel();
    for (final controller in _fadeControllers.values) {
      controller.dispose();
    }
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
    // Prevent multiple calls
    if (_galleryStarted) {
      print('Gallery already started, skipping');
      return;
    }
    
    // Cancel any existing timers first
    _galleryTimer?.cancel();
    _galleryTimer = null;
    
    // Reset navigation flag
    _navigationTriggered = false;
    _galleryStarted = true;

    print('Gallery: Available dates in mediaMap: ${_mediaMap.keys.toList()}');
    print('Gallery: Looking for dateKey: $_selectedDateKey');
    final mediaForDate = _mediaMap[_selectedDateKey] ?? [];
    print('Starting gallery animation. Media for date $_selectedDateKey: ${mediaForDate.length} items');
    
    if (mediaForDate.isEmpty) {
      // If no media for this date, just show the empty state - don't navigate
      print('No media found for date $_selectedDateKey');
      return;
    }

    _startGalleryWithMedia(mediaForDate);
  }

  void _startGalleryWithMedia(List<MediaItem> mediaForDate) {
    final mediaByYear = <int, List<MediaItem>>{};
    for (final item in mediaForDate) {
      mediaByYear.putIfAbsent(item.year, () => []).add(item);
    }
    final years = mediaByYear.keys.toList()..sort((a, b) => b.compareTo(a));
    print('Years found: $years (${years.length} years)');

    // Create a single fade controller for the current card
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 0.0, // Start invisible
    );
    
    // Cancel any existing timers
    _galleryTimer?.cancel();
    _galleryTimer = null;
    
    // Store years and media by year for the build method
    setState(() {
      _visibleYearCount = 0;
      _navigationTriggered = false;
      _fadeControllers = {0: controller}; // Use 0 as key for the single controller
      _mediaByYear = mediaByYear;
      _years = years;
    });

    if (years.isEmpty) {
      print('No years found, cannot start gallery');
      return;
    }
    
    print('Starting gallery preview with ${years.length} years');

    // Fade in the first year immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _navigationTriggered) return;
      
      print('Fading in first year: ${years[0]}, total years: ${years.length}');
      controller.forward();
      setState(() {
        _visibleYearCount = 1;
      });

      // Start cycling through years - wait 0.75s per card
      if (years.length > 1) {
        // Wait 0.75s for first card, then cycle through rest
        print('Multiple years detected, will cycle through them');
        Timer(const Duration(milliseconds: 750), () {
          if (!mounted || _navigationTriggered) {
            print('Widget unmounted or navigation triggered, cancelling cycle');
            return;
          }
          print('First card shown for 0.75s, cycling to next year');
          _cycleToNextYear(years, controller);
        });
      } else {
        // Only one year, wait 0.75 seconds then navigate
        print('Only one year, waiting 0.75s then navigating');
        Timer(const Duration(milliseconds: 750), () {
          if (mounted && !_navigationTriggered) {
            print('Single year timeout complete, navigating');
            _navigateToSwipe();
          }
        });
      }
    });
  }

  void _cycleToNextYear(List<int> years, AnimationController controller) {
    if (!mounted || _navigationTriggered) return;
    
    print('_cycleToNextYear called. _visibleYearCount: $_visibleYearCount, years.length: ${years.length}');
    
    // If we've shown all years, navigate
    if (_visibleYearCount >= years.length) {
      print('All years shown, navigating in 0.5s');
      // Wait a bit after last card before navigating
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_navigationTriggered) {
          _navigateToSwipe();
        }
      });
      return;
    }

    print('Fading out year ${years[_visibleYearCount - 1]}, will show year ${years[_visibleYearCount]}');
    
    // Fade out current, then fade in next
    controller.reverse().then((_) {
      if (!mounted || _navigationTriggered) return;
      setState(() {
        _visibleYearCount++;
      });
      print('Fading in year ${years[_visibleYearCount - 1]}');
      controller.forward();
      
      // Wait 0.75s for this card, then move to next
      Timer(const Duration(milliseconds: 750), () {
        if (!mounted || _navigationTriggered) return;
        _cycleToNextYear(years, controller);
      });
    });
  }

  void _navigateToSwipe() {
    if (_navigationTriggered) {
      print('Navigation already triggered, skipping');
      return;
    }
    
    _navigationTriggered = true;
    print('Navigating to swipe screen - preview complete');
    final media = _mediaMap[_selectedDateKey] ?? [];
    print('Media count for navigation: ${media.length}');
    final videos = media.where((m) => m.isVideo).toList();
    final photos = media.where((m) => !m.isVideo).toList();
    print('CarouselScreen: Passing to SwipeScreen - ${photos.length} photos, ${videos.length} videos');
    for (final item in media) {
      print('CarouselScreen: Media item - isVideo: ${item.isVideo}, ID: ${item.id}');
    }
    _galleryTimer?.cancel();
    _galleryTimer = null;
    
    // Cancel any pending timers
    for (final controller in _fadeControllers.values) {
      controller.stop();
    }
    
    // Navigate directly - don't wait for callbacks
    if (!mounted) {
      print('Widget not mounted, cannot navigate');
      return;
    }
    
    print('Executing navigation to swipe screen');
    try {
      final navigator = Navigator.of(context);
      if (navigator.canPop() || true) { // Always allow navigation
        navigator.pushReplacementNamed(
          '/swipe',
          arguments: {'dateKey': _selectedDateKey, 'media': media},
        );
        print('Navigation command sent successfully');
      } else {
        print('Navigator cannot navigate');
      }
    } catch (e, stackTrace) {
      print('Navigation error: $e');
      print('Stack trace: $stackTrace');
    }
  }


  @override
  Widget build(BuildContext context) {
    // During preview (when showing gallery cards), hide settings and center card
    final isPreviewing = _years.isNotEmpty && _visibleYearCount > 0 && _visibleYearCount <= _years.length;
    
    return Scaffold(
      body: Column(
        children: [
          if (!isPreviewing) LogoWidget(selectedDateKey: _selectedDateKey),
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
            child: _isScanning
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 20),
                        Text('Scanning your photo library...'),
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
                    : isPreviewing && _fadeControllers.containsKey(0)
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: YearGalleryItem(
                                year: _years[_visibleYearCount - 1],
                                mediaItems: _mediaByYear[_years[_visibleYearCount - 1]]!,
                                fadeAnimation: _fadeControllers[0]!,
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


