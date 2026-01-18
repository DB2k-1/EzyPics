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
            final args = settings.arguments as List<MediaItem>;
            builder = (context) => DeletionConfirmationScreen(mediaToDelete: args);
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
