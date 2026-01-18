import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:share_plus/share_plus.dart';
import '../services/stats_service.dart';
import '../services/photo_service.dart';
import '../utils/date_utils.dart';
import '../widgets/logo_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _photosDeleted = 0;
  int _videosDeleted = 0;
  int _photoStorageBytes = 0;
  int _videoStorageBytes = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final photos = await StatsService.getPhotosDeleted();
    final videos = await StatsService.getVideosDeleted();
    final photoStorage = await StatsService.getPhotoStorageRecovered();
    final videoStorage = await StatsService.getVideoStorageRecovered();
    
    if (mounted) {
      setState(() {
        _photosDeleted = photos;
        _videosDeleted = videos;
        _photoStorageBytes = photoStorage;
        _videoStorageBytes = videoStorage;
        _isLoading = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload stats when screen becomes visible
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
          children: [
            const LogoWidget(),
            const SizedBox(height: 16), // Match gap between button and stats header
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Review Media button - white bubble with app icon
                          InkWell(
                            onTap: () async {
                              // Check if there's media for today's date
                              final todayKey = AppDateUtils.getTodayDateKey();
                              final mediaMap = await PhotoService.scanMediaByDate();
                              
                              // Check if widget is still mounted before using context
                              if (!mounted) return;
                              
                              final mediaForToday = mediaMap[todayKey] ?? [];
                              
                              if (mediaForToday.isEmpty) {
                                // No media for today, go to date selector
                                Navigator.of(context).pushReplacementNamed('/settings');
                              } else {
                                // Has media, go to carousel
                                Navigator.of(context).pushReplacementNamed('/carousel');
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                  color: Colors.blue,
                                  width: 4.0, // Same as app border
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 12.0,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.asset(
                                        'assets/app_icon.png',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Text(
                                    'Review Media',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Storage Recovery Stats',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          _buildStatCard(
                            icon: Icons.photo,
                            title: 'Photos Deleted',
                            value: '$_photosDeleted',
                            subtitle: StatsService.formatBytes(_photoStorageBytes),
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 12),
                          _buildStatCard(
                            icon: Icons.videocam,
                            title: 'Videos Deleted',
                            value: '$_videosDeleted',
                            subtitle: StatsService.formatBytes(_videoStorageBytes),
                            color: Colors.purple,
                          ),
                          const SizedBox(height: 12),
                          _buildStatCard(
                            icon: Icons.storage,
                            title: 'Total Storage Recovered',
                            value: StatsService.formatBytes(_photoStorageBytes + _videoStorageBytes),
                            subtitle: '', // Removed redundant subtitle
                            color: Colors.green,
                            showShareButton: true,
                            onShare: () => _shareStats(),
                          ),
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pushNamed('/settings');
                              },
                              icon: const Icon(Icons.calendar_today),
                              label: const Text('Date Selector'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      );
  }

  Future<void> _shareStats() async {
    final totalStorage = _photoStorageBytes + _videoStorageBytes;
    final storageFormatted = StatsService.formatBytes(totalStorage);
    
    final message = "I've deleted $_photosDeleted ${_photosDeleted == 1 ? 'photo' : 'photos'} and $_videosDeleted ${_videosDeleted == 1 ? 'video' : 'videos'} from my phone and saved $storageFormatted using EzyPics.";
    
    // This method is called from the button's onPressed, which provides the context
    // The actual share with position is handled in the button's onPressed
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    bool showShareButton = false,
    VoidCallback? onShare,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (showShareButton && onShare != null) ...[
              const SizedBox(width: 8),
              Builder(
                builder: (context) {
                  return IconButton(
                    key: GlobalKey(),
                    icon: Icon(
                      Platform.isIOS ? CupertinoIcons.share : Icons.share,
                      color: color,
                    ),
                    onPressed: () async {
                      // Get button position for iOS
                      if (Platform.isIOS) {
                        final RenderBox? box = context.findRenderObject() as RenderBox?;
                        if (box != null) {
                          final position = box.localToGlobal(Offset.zero);
                          final size = box.size;
                          final totalStorage = _photoStorageBytes + _videoStorageBytes;
                          final storageFormatted = StatsService.formatBytes(totalStorage);
                          final message = "I've deleted $_photosDeleted ${_photosDeleted == 1 ? 'photo' : 'photos'} and $_videosDeleted ${_videosDeleted == 1 ? 'video' : 'videos'} from my phone and saved $storageFormatted using EzyPics.\n\nGet it on the App Store here: https://apps.apple.com/us/app/ezypics/id6757226178";
                          
                          try {
                            await Share.share(
                              message,
                              sharePositionOrigin: Rect.fromLTWH(
                                position.dx,
                                position.dy,
                                size.width,
                                size.height,
                              ),
                            );
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error sharing: $e')),
                              );
                            }
                          }
                          return;
                        }
                      }
                      // For Android or fallback, use the callback
                      onShare();
                    },
                    tooltip: 'Share stats',
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

