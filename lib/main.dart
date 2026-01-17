import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/permission_screen.dart';
import 'screens/carousel_screen.dart';
import 'screens/swipe_screen.dart';
import 'screens/deletion_confirmation_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/home_screen.dart';
import 'services/photo_service.dart';
import 'models/media_item.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Force portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const EzyPicsApp());
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
      routes: {
        '/': (context) => const InitialScreen(),
        '/home': (context) => const HomeScreen(),
        '/carousel': (context) => const CarouselScreen(),
        '/swipe': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          final media = args['media'] as List<MediaItem>;
          final videos = media.where((m) => m.isVideo).toList();
          final photos = media.where((m) => !m.isVideo).toList();
          print('Main: SwipeScreen route - ${photos.length} photos, ${videos.length} videos');
          for (final item in media) {
            print('Main: Media item - isVideo: ${item.isVideo}, ID: ${item.id}');
          }
          return SwipeScreen(
            dateKey: args['dateKey'] as String,
            media: media,
          );
        },
        '/deletion-confirmation': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as List<MediaItem>;
          return DeletionConfirmationScreen(mediaToDelete: args);
        },
        '/settings': (context) => const SettingsScreen(),
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
