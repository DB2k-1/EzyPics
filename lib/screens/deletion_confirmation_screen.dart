import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/media_item.dart';
import '../services/photo_service.dart';
import '../services/stats_service.dart';
import '../widgets/logo_widget.dart';

class DeletionConfirmationScreen extends StatefulWidget {
  final List<MediaItem> mediaToDelete;

  const DeletionConfirmationScreen({
    super.key,
    required this.mediaToDelete,
  });

  @override
  State<DeletionConfirmationScreen> createState() =>
      _DeletionConfirmationScreenState();
}

class _DeletionConfirmationScreenState
    extends State<DeletionConfirmationScreen> {
  final Set<String> _selectedIds = {};
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _selectedIds.addAll(widget.mediaToDelete.map((item) => item.id));
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
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items selected')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text(
          'Are you sure you want to permanently delete ${_selectedIds.length} item(s)? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isDeleting = true);
      final itemsToDelete = widget.mediaToDelete
          .where((item) => _selectedIds.contains(item.id))
          .toList();

      // Get file sizes before deletion
      final fileSizes = await PhotoService.getFileSizes(itemsToDelete);
      
      // Calculate stats
      int photosDeleted = 0;
      int videosDeleted = 0;
      int photoStorageBytes = 0;
      int videoStorageBytes = 0;
      
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
      setState(() => _isDeleting = false);

      if (context.mounted) {
        if (success) {
          // Record stats
          await StatsService.recordDeletions(
            photosDeleted: photosDeleted,
            videosDeleted: videosDeleted,
            photoStorageBytes: photoStorageBytes,
            videoStorageBytes: videoStorageBytes,
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully deleted ${itemsToDelete.length} item(s)'),
            ),
          );
          // Navigate to home screen after deletion
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete items')),
          );
        }
      }
    }
  }

  Widget _buildThumbnail(MediaItem item) {
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
          child: const Icon(Icons.image),
        );
      },
    );
  }

  Future<Widget?> _getThumbnail(MediaItem item) async {
    try {
      final asset = await AssetEntity.fromId(item.id);
      if (asset == null) return null;
      final file = await asset.file;
      if (file == null) return null;
      return Image.file(
        file,
        fit: BoxFit.cover,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const LogoWidget(),
          Padding(
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
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
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
                    children: [
                      _buildThumbnail(item),
                      if (isSelected)
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.red, width: 3),
                          ),
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
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedIds.clear();
                        _selectedIds.addAll(widget.mediaToDelete.map((item) => item.id));
                      });
                    },
                    child: const Text('Select All'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isDeleting ? null : _handleDelete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isDeleting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            'Delete ${_selectedIds.length} Item${_selectedIds.length != 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

