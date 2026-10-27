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
import 'utils/screenshot_mode.dart';
import 'services/notification_service.dart';

/// Phones stay in portrait, so swiping through photos never rotates the
/// screen by accident. Large screens (iPhone Duo open, foldables open,
/// tablets) can rotate: they're often held in landscape, and Apple and Google
/// both expect apps to fill them in any orientation.
bool? _allowsRotation;
void _applyOrientationPolicy() {
  final views = WidgetsBinding.instance.platformDispatcher.views;
  if (views.isEmpty) return;
  final view = views.first;
  if (view.physicalSize.isEmpty) return;
  final Size size = view.physicalSize / view.devicePixelRatio;
  final bool allow = size.shortestSide >= 600;
  if (allow == _allowsRotation) return;
  _allowsRotation = allow;
  SystemChrome.setPreferredOrientations(
    allow ? const <DeviceOrientation>[] : const [DeviceOrientation.portraitUp],
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep app lean: limit Flutter's image cache (default is 1000 images / 100MB).
  // We only show thumbnails; a smaller cache reduces memory and storage pressure.
  PaintingBinding.instance.imageCache.maximumSize = 60;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 25 * 1024 * 1024; // 25 MB

  // Don't clear cache on startup — the engine/plugins expect some files to exist;
  // clearing here causes "fopen failed / Invalidating cache" in the console.
  // We only clear when the app goes to background so Documents & Data drops.

  await NotificationService.initialize();

  _applyOrientationPolicy();

  // Opt in to edge-to-edge on Android 15+ (SDK 35) and back-port the same
  // behaviour to older Android versions for consistency. SafeArea widgets in
  // each screen handle the system bar insets.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

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

  // Opening or closing an iPhone Duo or a foldable changes the screen size.
  @override
  void didChangeMetrics() => _applyOrientationPolicy();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // Clear cache when user leaves app so storage size drops. Don't await.
      CacheCleanup.clearTempFilesOnStartup();
    }
    if (state == AppLifecycleState.resumed) {
      NotificationService.scheduleReminder();
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
      debugShowCheckedModeBanner: !screenshotMode,
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
        switch (screenshotView) {
          case 'review':
            Navigator.of(context).pushReplacementNamed(
              '/carousel',
              arguments: screenshotDate.isEmpty ? null : {'dateKey': screenshotDate},
            );
          case 'calendar':
            Navigator.of(context).pushReplacementNamed('/settings');
          default:
            Navigator.of(context).pushReplacementNamed('/home');
        }
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
