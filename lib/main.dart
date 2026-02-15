import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'screens/permission_screen.dart';
import 'screens/carousel_screen.dart';
import 'screens/swipe_screen.dart';
import 'screens/deletion_confirmation_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/home_screen.dart';
import 'services/photo_service.dart';
import 'models/media_item.dart';
import 'utils/cache_cleanup.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep app lean: limit Flutter's image cache (default is 1000 images / 100MB).
  // We only show thumbnails; a smaller cache reduces memory and storage pressure.
  PaintingBinding.instance.imageCache.maximumSize = 60;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 25 * 1024 * 1024; // 25 MB

  // Don't clear cache on startup — the engine/plugins expect some files to exist;
  // clearing here causes "fopen failed / Invalidating cache" in the console.
  // We only clear when the app goes to background so Documents & Data drops.

  // Force portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const CacheCleanupAppWrapper());
}

/// Wraps the app and clears cache when going to background so "Documents & Data"
/// drops after the user leaves the app (instead of refilling during use).
class CacheCleanupAppWrapper extends StatefulWidget {
  const CacheCleanupAppWrapper({super.key});

  @override
  State<CacheCleanupAppWrapper> createState() => _CacheCleanupAppWrapperState();
}

class _CacheCleanupAppWrapperState extends State<CacheCleanupAppWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // Clear cache when user leaves app so storage size drops. Don't await.
      CacheCleanup.clearTempFilesOnStartup();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const EzyPicsApp();
  }
}

class EzyPicsApp extends StatelessWidget {
  const EzyPicsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EzyPics',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // Enable performance overlay in debug mode (toggle with 'P' key or set to true)
      // Set showPerformanceOverlay: true to always show it
      showPerformanceOverlay: false, // Set to true to debug performance issues
      initialRoute: '/',
      // Custom route generator with instant transitions (no slide-in animation)
      onGenerateRoute: (settings) {
        WidgetBuilder? builder;
        
        switch (settings.name) {
          case '/':
            builder = (context) => const InitialScreen();
            break;
          case '/home':
            builder = (context) => const HomeScreen();
            break;
          case '/carousel':
            builder = (context) => const CarouselScreen();
            break;
          case '/swipe':
            final args = settings.arguments as Map;
            final media = args['media'] as List<MediaItem>;
            builder = (context) => SwipeScreen(
              dateKey: args['dateKey'] as String,
              media: media,
            );
            break;
          case '/deletion-confirmation':
            // Support both Map (with caches) and List (legacy) argument formats
            if (settings.arguments is Map) {
              final args = settings.arguments as Map<String, dynamic>;
              builder = (context) => DeletionConfirmationScreen(
                mediaToDelete: args['mediaToDelete'] as List<MediaItem>,
                videoThumbnailCache: args['videoThumbnailCache'] as Map<String, Uint8List>?,
                imageThumbnailCache: args['imageThumbnailCache'] as Map<String, Uint8List>?,
              );
            } else {
              // Legacy format - just a list of MediaItems
              final args = settings.arguments as List<MediaItem>;
              builder = (context) => DeletionConfirmationScreen(mediaToDelete: args);
            }
            break;
          case '/settings':
            builder = (context) => const SettingsScreen();
            break;
        }
        
        if (builder == null) {
          return null;
        }
        
        // Instant transition - no animation
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) => builder!(context),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        );
      },
    );
  }
}

class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  bool _isChecking = true;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final hasPermission = await PhotoService.hasPermission();
    if (mounted) {
      setState(() {
        _hasPermission = hasPermission;
        _isChecking = false;
      });
      if (hasPermission) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _hasPermission
        ? const CarouselScreen()
        : const PermissionScreen();
  }
}
