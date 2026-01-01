import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/media_item.dart';

class YearGalleryItem extends StatefulWidget {
  final int year;
  final List<MediaItem> mediaItems;
  final int totalItemsForYear; // Total count of items for this year (not just the one shown)
  final Animation<double> fadeAnimation;

  const YearGalleryItem({
    super.key,
    required this.year,
    required this.mediaItems,
    required this.totalItemsForYear,
    required this.fadeAnimation,
  });

  @override
  State<YearGalleryItem> createState() => _YearGalleryItemState();
}

class _YearGalleryItemState extends State<YearGalleryItem> {
  Widget? _cachedImageWidget;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    print('YearGalleryItem initState: year=${widget.year}, mediaCount=${widget.mediaItems.length}');
    _loadImageWidget();
  }

  Future<void> _loadImageWidget() async {
    if (widget.mediaItems.isEmpty) {
      setState(() {
        _isLoading = false;
        _cachedImageWidget = const SizedBox.shrink();
      });
      return;
    }

    final firstItem = widget.mediaItems.first;
    print('YearGalleryItem: Showing year ${widget.year} with ${widget.mediaItems.length} item(s). First item ID: ${firstItem.id}, type: ${firstItem.isVideo ? "video" : "photo"}');
    
    final imageWidget = await _buildImageWidget(firstItem);
    if (mounted) {
      setState(() {
        _cachedImageWidget = imageWidget;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('[YGI] YearGalleryItem.build called for year ${widget.year}. animation.value=${widget.fadeAnimation.value}, animation.status=${widget.fadeAnimation.status}');
    
    if (widget.mediaItems.isEmpty) {
      print('[YGI] No media items, returning SizedBox.shrink');
      return const SizedBox.shrink();
    }

    print('[YGI] Building AnimatedBuilder for year ${widget.year}. animation.value=${widget.fadeAnimation.value}, animation.status=${widget.fadeAnimation.status}');
    
    // Create custom animation: quick fade in -> full opacity for 500ms -> quick fade out
    // Animation duration is 800ms total:
    // - 0.0 to 0.1875 (150ms): fade in 0->1
    // - 0.1875 to 0.8125 (500ms): stay at 1.0
    // - 0.8125 to 1.0 (150ms): fade out 1->0
    return AnimatedBuilder(
      animation: widget.fadeAnimation,
      builder: (context, child) {
        // Calculate opacity based on animation value
        final opacityValue = widget.fadeAnimation.value <= 0.1875
            ? widget.fadeAnimation.value / 0.1875 // Fade in: 0 to 1
            : widget.fadeAnimation.value >= 0.8125
                ? (1.0 - widget.fadeAnimation.value) / 0.1875 // Fade out: 1 to 0
                : 1.0; // Full opacity in middle
        
        // Log only significant animation changes (every 0.1 or on status changes)
        final animValue = widget.fadeAnimation.value;
        final shouldLog = (animValue % 0.1 < 0.02) || 
                         widget.fadeAnimation.status == AnimationStatus.completed ||
                         widget.fadeAnimation.status == AnimationStatus.dismissed;
        if (shouldLog) {
          print('[YGI] AnimatedBuilder rebuild for year ${widget.year}. animation.value=${animValue.toStringAsFixed(3)}, status=${widget.fadeAnimation.status}, opacityValue=${opacityValue.toStringAsFixed(3)}');
        }
        
        // Calculate white overlay opacity (visible during transitions, hidden during full opacity)
        final whiteOverlayOpacity = widget.fadeAnimation.value <= 0.1875
            ? 1.0 - (widget.fadeAnimation.value / 0.1875) // Fade out white during fade in
            : widget.fadeAnimation.value >= 0.8125
                ? (widget.fadeAnimation.value - 0.8125) / 0.1875 // Fade in white during fade out
                : 0.0; // No white overlay during full opacity
        
        // Card height: 300 (image) + 16 (top padding) + 24 (year text) + 4 (spacing) + 16 (items text) + 16 (bottom padding) ≈ 376
        const cardHeight = 300.0 + 16.0 + 24.0 + 4.0 + 16.0 + 16.0;
        
        return LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth - 32; // Account for horizontal margin (16 * 2)
            
            return Stack(
              alignment: Alignment.center,
              children: [
                // White background that shows during transitions (covers the card area)
                Opacity(
                  opacity: whiteOverlayOpacity.clamp(0.0, 1.0),
                  child: Container(
                    width: cardWidth,
                    height: cardHeight,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                // The actual card with photo
                Opacity(
                  opacity: opacityValue.clamp(0.0, 1.0),
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 300,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: _isLoading
                                ? const Center(child: CircularProgressIndicator())
                                : (_cachedImageWidget ?? const Center(child: Icon(Icons.image))),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.year}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.totalItemsForYear} ${widget.totalItemsForYear == 1 ? 'item' : 'items'}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Widget> _buildImageWidget(MediaItem item) async {
    try {
      print('YearGalleryItem: Building widget for ${item.isVideo ? "VIDEO" : "IMAGE"} - ID: ${item.id}');
      final asset = await AssetEntity.fromId(item.id);
      if (asset == null) {
        print('YearGalleryItem: Asset is null for ${item.isVideo ? "video" : "image"}');
        return Center(
          child: Icon(
            item.isVideo ? Icons.videocam : Icons.image,
            size: 100,
          ),
        );
      }
      
      // For videos, use thumbnail
      if (item.isVideo) {
        print('YearGalleryItem: Loading video thumbnail...');
        try {
          final thumbnail = await asset.thumbnailDataWithSize(
            const ThumbnailSize(300, 300),
          );
          if (thumbnail != null) {
            print('YearGalleryItem: Video thumbnail loaded successfully');
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(
                  thumbnail,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    print('YearGalleryItem: Error displaying video thumbnail: $error');
                    return const Center(child: Icon(Icons.videocam, size: 100));
                  },
                ),
                const Center(
                  child: Icon(
                    Icons.play_circle_filled,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
              ],
            );
          } else {
            print('YearGalleryItem: Video thumbnail is null');
            return const Center(child: Icon(Icons.videocam, size: 100));
          }
        } catch (e) {
          print('YearGalleryItem: Error loading video thumbnail: $e');
          return const Center(child: Icon(Icons.videocam, size: 100));
        }
      }
      
      // For images, use the file directly
      final file = await asset.file;
      if (file == null) {
        return const Center(child: Icon(Icons.image, size: 100));
      }
      return Image.file(
        file,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return const Center(child: Icon(Icons.image, size: 100));
        },
      );
    } catch (e) {
      print('Error building image widget: $e');
      return Center(
        child: Icon(
          item.isVideo ? Icons.videocam : Icons.image,
          size: 100,
        ),
      );
    }
  }
}

