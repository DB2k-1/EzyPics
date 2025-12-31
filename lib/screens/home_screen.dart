import 'package:flutter/material.dart';
import '../services/stats_service.dart';
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
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20),
                        const Text(
                          'Storage Recovery Stats',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                        _buildStatCard(
                          icon: Icons.photo,
                          title: 'Photos Deleted',
                          value: '$_photosDeleted',
                          subtitle: StatsService.formatBytes(_photoStorageBytes),
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 20),
                        _buildStatCard(
                          icon: Icons.videocam,
                          title: 'Videos Deleted',
                          value: '$_videosDeleted',
                          subtitle: StatsService.formatBytes(_videoStorageBytes),
                          color: Colors.purple,
                        ),
                        const SizedBox(height: 20),
                        _buildStatCard(
                          icon: Icons.storage,
                          title: 'Total Storage Recovered',
                          value: StatsService.formatBytes(_photoStorageBytes + _videoStorageBytes),
                          subtitle: '${StatsService.formatBytes(_photoStorageBytes)} photos + ${StatsService.formatBytes(_videoStorageBytes)} videos',
                          color: Colors.green,
                        ),
                        const SizedBox(height: 40),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pushReplacementNamed('/carousel');
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Review More Media'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pushNamed('/settings');
                            },
                            icon: const Icon(Icons.settings),
                            label: const Text('Settings'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
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

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
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
                      fontSize: 24,
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
          ],
        ),
      ),
    );
  }
}

