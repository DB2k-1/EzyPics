import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/media_item.dart';
import '../services/photo_service.dart';
import '../services/stats_service.dart';
import '../utils/cache_cleanup.dart';
import '../utils/adaptive_layout.dart';
import '../widgets/logo_widget.dart';

class DeletionConfirmationScreen extends StatefulWidget {
  final List<MediaItem> mediaToDelete;
  final Map<String, Uint8List>? videoThumbnailCache;
  final Map<String, Uint8List>? imageThumbnailCache;

  const DeletionConfirmationScreen({
    super.key,
    required this.mediaToDelete,
    this.videoThumbnailCache,
    this.imageThumbnailCache,
  });

  @override
  State<DeletionConfirmationScreen> createState() =>
      _DeletionConfirmationScreenState();
}

class _DeletionConfirmationScreenState
    extends State<DeletionConfirmationScreen> {
  final Set<String> _selectedIds = {};
  bool _isDeleting = false;
  Map<String, int> _fileSizes = {};

  @override
  void initState() {
    super.initState();
    _selectedIds.addAll(widget.mediaToDelete.map((item) => item.id));
    // Precompute file sizes in the background so _handleDelete doesn't block
    // waiting for iCloud downloads when the user eventually taps Delete.
    PhotoService.getFileSizes(widget.mediaToDelete).then((sizes) {
      if (mounted) setState(() { _fileSizes = sizes; });
    });
  }

  void _toggleSelection(MediaItem item) {
    setState(() {
      if (_selectedIds.contains(item.id)) {
        _selectedIds.remove(item.id);
      } else {
        _selectedIds.add(item.id);
      }
    });
  }

  Future<void> _handleDelete() async {
    if (_selectedIds.isEmpty || _isDeleting) return;

    setState(() => _isDeleting = true);

    // Show spinner dialog immediately — appears on the next paint without
    // waiting for a full widget rebuild cycle, so the user sees feedback
    // the moment they confirm rather than after the dialog close animation.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Verifying local and internet storage media data…',
                  style: TextStyle(fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final itemsToDelete = widget.mediaToDelete
        .where((item) => _selectedIds.contains(item.id))
        .toList();

    int photosDeleted = 0;
    int videosDeleted = 0;
    int photoStorageBytes = 0;
    int videoStorageBytes = 0;

    try {
      final fileSizes = _fileSizes;
      for (final item in itemsToDelete) {
        final size = fileSizes[item.id] ?? 0;
        if (item.isVideo) {
          videosDeleted++;
          videoStorageBytes += size;
        } else {
          photosDeleted++;
          photoStorageBytes += size;
        }
      }

      final success = await PhotoService.deleteMediaItems(itemsToDelete);

      if (!context.mounted) return;
      Navigator.of(context).pop(); // dismiss spinner dialog

      if (success) {
        await StatsService.recordDeletions(
          photosDeleted: photosDeleted,
          videosDeleted: videosDeleted,
          photoStorageBytes: photoStorageBytes,
          videoStorageBytes: videoStorageBytes,
        );

        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
          CacheCleanup.clearImageCache();
          CacheCleanup.clearAllDiskCaches();
        }
      } else {
        setState(() => _isDeleting = false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete items')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // dismiss spinner dialog
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete items')),
        );
      }
    }
  }

  Widget _buildThumbnail(MediaItem item) {
    // Check if we have a cached thumbnail first
    Uint8List? cachedThumbnail;
    if (item.isVideo && widget.videoThumbnailCache != null) {
      cachedThumbnail = widget.videoThumbnailCache![item.id];
    } else if (!item.isVideo && widget.imageThumbnailCache != null) {
      cachedThumbnail = widget.imageThumbnailCache![item.id];
    }

    // If we have a cached thumbnail, use it immediately
    if (cachedThumbnail != null) {
      return Image.memory(
        cachedThumbnail,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: Icon(item.isVideo ? Icons.videocam : Icons.image),
          );
        },
      );
    }

    // Otherwise, load it asynchronously
    return FutureBuilder<Widget?>(
      future: _getThumbnail(item),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.grey[300],
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data ?? Container(
          color: Colors.grey[300],
          child: Icon(item.isVideo ? Icons.videocam : Icons.image),
        );
      },
    );
  }

  Future<Widget?> _getThumbnail(MediaItem item) async {
    try {
      final asset = await AssetEntity.fromId(item.id);
      if (asset == null) return null;
      
      if (item.isVideo) {
        // For videos, use thumbnail
        final thumbnail = await asset.thumbnailDataWithSize(
          const ThumbnailSize(300, 300),
        );
        if (thumbnail != null) {
          return Image.memory(
            thumbnail,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: const Icon(Icons.videocam),
              );
            },
          );
        }
        return Container(
          color: Colors.grey[300],
          child: const Icon(Icons.videocam),
        );
      } else {
        final thumbnail = await asset.thumbnailDataWithSize(
          const ThumbnailSize(300, 300),
        );
        if (thumbnail != null) {
          return Image.memory(
            thumbnail,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: const Icon(Icons.image),
              );
            },
          );
        }
        return Container(
          color: Colors.grey[300],
          child: const Icon(Icons.image),
        );
      }
    } catch (e) {
      print('Error getting thumbnail for ${item.isVideo ? "video" : "image"}: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = PaneLayout.of(context);
    return Scaffold(
      body: Column(
        children: [
          LogoWidget(
            onTap: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false),
          ),
          Expanded(
            child: layout.twoPane
                // Thumbnails in the left pane; title and buttons in the right.
                ? SafeArea(
                    top: false,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: layout.leading, child: _buildGrid(3)),
                        SizedBox(width: layout.gap),
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [_buildTitle(), _buildButtons(), _buildBreakdown()],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : SafeArea(
                    top: false,
                    bottom: false,
                    child: Column(
                      children: [
                        _buildTitle(),
                        Expanded(
                          child: LayoutBuilder(
                            // Three columns on phones, four on wider screens
                            // (an even count keeps a gap on the Duo's fold).
                            builder: (context, constraints) => _buildGrid(
                              constraints.maxWidth < PaneLayout.maxSingleColumnWidth ? 3 : 4,
                            ),
                          ),
                        ),
                        // Bottom controls with Android-safe padding
                        SafeArea(top: false, child: _buildButtons()),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          const Text(
            'Review Items to Delete',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_selectedIds.length} of ${widget.mediaToDelete.length} selected',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(int crossAxisCount) {
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 5,
        mainAxisSpacing: 5,
      ),
      itemCount: widget.mediaToDelete.length,
      itemBuilder: (context, index) {
        final item = widget.mediaToDelete[index];
        final isSelected = _selectedIds.contains(item.id);
        return GestureDetector(
          onTap: () => _toggleSelection(item),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: _buildThumbnail(item),
              ),
              if (isSelected)
                const Positioned(
                  top: 5,
                  right: 5,
                  child: CircleAvatar(
                    backgroundColor: Colors.red,
                    child: Icon(Icons.check, color: Colors.white),
                  ),
                ),
              if (item.isVideo)
                const Positioned(
                  bottom: 5,
                  left: 5,
                  child: Icon(Icons.play_circle, color: Colors.white),
                ),
            ],
          ),
        );
      },
    );
  }

  /// What's selected, by type and by year. Shown beside the thumbnails on
  /// wide screens, where the right pane has room.
  Widget _buildBreakdown() {
    final selected = widget.mediaToDelete.where((m) => _selectedIds.contains(m.id)).toList();
    final videos = selected.where((m) => m.isVideo).length;
    final photos = selected.length - videos;
    final byYear = <int, int>{};
    for (final m in selected) {
      byYear[m.year] = (byYear[m.year] ?? 0) + 1;
    }
    final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));

    Widget tile(IconData icon, String label, int value, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 4),
                Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              ],
            ),
          ),
        );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                tile(Icons.photo, 'Photos', photos, Colors.blue),
                const SizedBox(width: 8),
                tile(Icons.videocam, 'Videos', videos, Colors.purple),
              ],
            ),
            if (years.length > 1) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final y in years)
                    Chip(
                      label: Text('$y  ·  ${byYear[y]}'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildButtons() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20.0,
        20.0,
        20.0,
        Platform.isAndroid ? 8.0 : 20.0,
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isDeleting
                  ? null
                  : () {
                      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                    },
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isDeleting
                  ? null
                  : (_selectedIds.isEmpty
                      ? null
                      : _handleDelete),
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedIds.isEmpty ? Colors.grey : Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                _selectedIds.isEmpty
                    ? 'No Items Selected'
                    : 'Delete ${_selectedIds.length} Item${_selectedIds.length != 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

