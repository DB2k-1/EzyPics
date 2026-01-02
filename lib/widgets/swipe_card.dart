import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import '../models/media_item.dart';
import '../services/video_settings_service.dart';

class _FullscreenImageViewer extends StatefulWidget {
  final File imageFile;

  const _FullscreenImageViewer({required this.imageFile});

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  double _dragOffset = 0.0;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(_isDragging ? 0.5 : 1.0),
      body: SafeArea(
        child: GestureDetector(
          onVerticalDragStart: (_) {
            setState(() {
              _isDragging = true;
            });
          },
          onVerticalDragUpdate: (details) {
            if (details.delta.dy > 0) { // Only allow downward drag
              setState(() {
                _dragOffset += details.delta.dy;
              });
            }
          },
          onVerticalDragEnd: (details) {
            if (_dragOffset > 100) { // Threshold to close
              Navigator.of(context).pop();
            } else {
              setState(() {
                _dragOffset = 0.0;
                _isDragging = false;
              });
            }
          },
          child: Stack(
            children: [
              Transform.translate(
                offset: Offset(0, _dragOffset),
                child: Center(
                  child: InteractiveViewer(
                    child: Image.file(
                      widget.imageFile,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(child: Icon(Icons.image, color: Colors.white, size: 100));
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullscreenVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;

  const _FullscreenVideoPlayer({required this.controller});

  @override
  State<_FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<_FullscreenVideoPlayer> {
  bool _showControls = true;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    widget.controller.play();
    _loadMuteState();
  }

  Future<void> _loadMuteState() async {
    final muted = await VideoSettingsService.isMuted();
    widget.controller.setVolume(muted ? 0.0 : 1.0);
    setState(() {
      _isMuted = muted;
    });
  }

  Future<void> _toggleMute() async {
    final newMuted = await VideoSettingsService.toggleMute();
    widget.controller.setVolume(newMuted ? 0.0 : 1.0);
    setState(() {
      _isMuted = newMuted;
    });
  }

  void _togglePlayPause() {
    setState(() {
      if (widget.controller.value.isPlaying) {
        widget.controller.pause();
      } else {
        widget.controller.play();
      }
    });
  }

  double _dragOffset = 0.0;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(_isDragging ? 0.5 : 1.0),
      body: GestureDetector(
        onTap: () {
          setState(() {
            _showControls = !_showControls;
          });
        },
        onVerticalDragStart: (_) {
          setState(() {
            _isDragging = true;
          });
        },
        onVerticalDragUpdate: (details) {
          if (details.delta.dy > 0) { // Only allow downward drag
            setState(() {
              _dragOffset += details.delta.dy;
            });
          }
        },
        onVerticalDragEnd: (details) {
          if (_dragOffset > 100) { // Threshold to close
            widget.controller.pause();
            Navigator.of(context).pop();
          } else {
            setState(() {
              _dragOffset = 0.0;
              _isDragging = false;
            });
          }
        },
        child: Stack(
          children: [
            Transform.translate(
              offset: Offset(0, _dragOffset),
              child: Center(
                child: AspectRatio(
                  aspectRatio: widget.controller.value.aspectRatio,
                  child: VideoPlayer(widget.controller),
                ),
              ),
            ),
            if (_showControls)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  child: Center(
                    child: IconButton(
                      icon: Icon(
                        widget.controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 64,
                      ),
                      onPressed: _togglePlayPause,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 10,
              right: 10,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mute/unmute button
                  Material(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      onTap: _toggleMute,
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Icon(
                          _isMuted ? Icons.volume_off : Icons.volume_up,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Close button
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () {
                      widget.controller.pause();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SwipeCard extends StatefulWidget {
  final MediaItem mediaItem;
  final Uint8List? cachedThumbnail; // Optional cached thumbnail for videos and images

  const SwipeCard({
    super.key,
    required this.mediaItem,
    this.cachedThumbnail,
  });

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard> {
  VideoPlayerController? _videoController;
  bool _isVideoInitializing = false;
  String? _videoError;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    print('SwipeCard initState: isVideo=${widget.mediaItem.isVideo}, ID=${widget.mediaItem.id}');
    if (widget.mediaItem.isVideo) {
      print('SwipeCard: Initializing video player...');
      _initVideoPlayer();
    } else {
      print('SwipeCard: Not a video, skipping video initialization');
    }
  }

  Future<void> _initVideoPlayer() async {
    if (_isVideoInitializing) {
      print('Video initialization already in progress, skipping');
      return;
    }
    
    if (_videoController != null && _videoController!.value.isInitialized) {
      print('Video controller already initialized, skipping');
      return;
    }
    
    print('_initVideoPlayer called for video: ${widget.mediaItem.id}');
    setState(() {
      _isVideoInitializing = true;
      _videoError = null;
    });

    try {
      print('Initializing video for: ${widget.mediaItem.id}');
      final asset = await AssetEntity.fromId(widget.mediaItem.id);
      if (asset == null) {
        print('Asset is null for video: ${widget.mediaItem.id}');
        if (mounted) {
          setState(() {
            _videoError = 'Asset not found';
            _isVideoInitializing = false;
          });
        }
        return;
      }

      if (!mounted) {
        print('Widget not mounted after getting asset');
        return;
      }

      print('Getting file for video asset...');
      final file = await asset.file;
      if (file == null) {
        print('File is null for video: ${widget.mediaItem.id}');
        if (mounted) {
          setState(() {
            _videoError = 'File not found';
            _isVideoInitializing = false;
          });
        }
        return;
      }

      if (!mounted) {
        print('Widget not mounted after getting file');
        return;
      }

      print('Creating video controller for: ${file.path}');
      print('File exists: ${await file.exists()}, size: ${await file.length()} bytes');
      _videoController = VideoPlayerController.file(file);
      print('Video controller created, initializing...');
      await _videoController!.initialize();
      print('Video controller initialized: ${_videoController!.value.isInitialized}');
      print('Video duration: ${_videoController!.value.duration}');
      print('Video size: ${_videoController!.value.size}');
      
      if (mounted) {
        // Load mute state and apply it
        final muted = await VideoSettingsService.isMuted();
        _videoController!.setVolume(muted ? 0.0 : 1.0);
        
        setState(() {
          _isVideoInitializing = false;
          _isMuted = muted;
        });
        // Auto-play video when it's ready
        _videoController!.play();
        print('Video playback started, muted: $muted');
      } else {
        print('Widget not mounted after initialization, disposing controller');
        _videoController?.dispose();
        _videoController = null;
      }
    } catch (e, stackTrace) {
      print('Error initializing video: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _videoError = e.toString();
          _isVideoInitializing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _toggleFullscreen(BuildContext context) {
    if (widget.mediaItem.isVideo) {
      _showFullscreenVideo(context);
    } else {
      _showFullscreenImage(context);
    }
  }

  void _showFullscreenImage(BuildContext context) async {
    try {
      final asset = await AssetEntity.fromId(widget.mediaItem.id);
      if (asset == null || !mounted) return;
      
      final file = await asset.file;
      if (file == null || !mounted) return;

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => _FullscreenImageViewer(imageFile: file),
          fullscreenDialog: true,
        ),
      );
    } catch (e) {
      print('Error showing fullscreen image: $e');
    }
  }

  void _showFullscreenVideo(BuildContext context) async {
    if (_videoController == null || !_videoController!.value.isInitialized || !mounted) {
      return;
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullscreenVideoPlayer(
          controller: _videoController!,
        ),
        fullscreenDialog: true,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    print('SwipeCard build: isVideo=${widget.mediaItem.isVideo}, hasController=${_videoController != null}, isInitialized=${_videoController?.value.isInitialized ?? false}, isInitializing=$_isVideoInitializing');
    
    // If it's a video but controller hasn't been initialized yet, trigger initialization
    if (widget.mediaItem.isVideo && _videoController == null && !_isVideoInitializing && _videoError == null) {
      print('SwipeCard build: Video detected but not initialized, triggering init...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.mediaItem.isVideo && _videoController == null) {
          _initVideoPlayer();
        }
      });
    }
    
    return GestureDetector(
      onTap: () => _toggleFullscreen(context),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: widget.mediaItem.isVideo
              ? _buildVideoWidget()
              : _buildImageWidgetWithCache(),
        ),
      ),
    );
  }

  Widget _buildVideoWidget() {
    if (_videoError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Video Error: $_videoError', textAlign: TextAlign.center),
          ],
        ),
      );
    }

    if (_isVideoInitializing || _videoController == null || !_videoController!.value.isInitialized) {
      // Use cached thumbnail if available, otherwise load it
      final cachedThumb = widget.cachedThumbnail;
      
      if (cachedThumb != null) {
        // Show cached thumbnail immediately (no loading spinner)
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(
              cachedThumb,
              fit: BoxFit.cover,
            ),
            if (_isVideoInitializing)
              const Center(
                child: CircularProgressIndicator(),
              ),
            const Center(
              child: Icon(
                Icons.play_circle_filled,
                size: 64,
                color: Colors.white70,
              ),
            ),
          ],
        );
      }
      
      // No cached thumbnail, load it
      return FutureBuilder<Uint8List?>(
        future: _getVideoThumbnail(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(
                  snapshot.data!,
                  fit: BoxFit.cover,
                ),
                const Center(
                  child: CircularProgressIndicator(),
                ),
                const Center(
                  child: Icon(
                    Icons.play_circle_filled,
                    size: 64,
                    color: Colors.white70,
                  ),
                ),
              ],
            );
          }
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Icon(Icons.videocam, size: 64, color: Colors.white70),
              ],
            ),
          );
        },
      );
    }

    return GestureDetector(
      onTap: () {
        if (_videoController!.value.isPlaying) {
          _videoController!.pause();
        } else {
          _videoController!.play();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final videoAspectRatio = _videoController!.value.aspectRatio;
              final containerAspectRatio = constraints.maxWidth / constraints.maxHeight;
              
              double videoWidth;
              double videoHeight;
              
              if (videoAspectRatio > containerAspectRatio) {
                // Video is wider - fit to width
                videoWidth = constraints.maxWidth;
                videoHeight = videoWidth / videoAspectRatio;
              } else {
                // Video is taller - fit to height
                videoHeight = constraints.maxHeight;
                videoWidth = videoHeight * videoAspectRatio;
              }
              
              return Center(
                child: SizedBox(
                  width: videoWidth,
                  height: videoHeight,
                  child: VideoPlayer(_videoController!),
                ),
              );
            },
          ),
          if (!_videoController!.value.isPlaying)
            const Center(
              child: Icon(
                Icons.play_circle_filled,
                size: 64,
                color: Colors.white70,
              ),
            ),
          // Mute/unmute toggle button
          Positioned(
            bottom: 16,
            right: 16,
            child: Material(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                onTap: () async {
                  final newMuted = await VideoSettingsService.toggleMute();
                  if (_videoController != null) {
                    _videoController!.setVolume(newMuted ? 0.0 : 1.0);
                    setState(() {
                      _isMuted = newMuted;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Icon(
                    _isMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<Uint8List?> _getVideoThumbnail() async {
    try {
      final asset = await AssetEntity.fromId(widget.mediaItem.id);
      if (asset != null) {
        return await asset.thumbnailDataWithSize(
          ThumbnailSize(widget.mediaItem.width, widget.mediaItem.height),
        );
      }
    } catch (e) {
      print('Error getting video thumbnail: $e');
    }
    return null;
  }

  Widget _buildImageWidgetWithCache() {
    // Determine fit based on aspect ratio
    final isLandscape = widget.mediaItem.width > widget.mediaItem.height;
    final fit = isLandscape ? BoxFit.cover : BoxFit.contain;
    
    // Use cached thumbnail if available for instant display
    final cachedThumb = widget.cachedThumbnail;
    
    if (cachedThumb != null) {
      // Show cached thumbnail immediately while loading full image
      return FutureBuilder<Widget>(
        future: _buildImageWidget(cachedThumb: cachedThumb, fit: fit),
        builder: (context, snapshot) {
          // Show cached thumbnail immediately with proper fit
          // When full image loads, it will replace the thumbnail
          if (snapshot.hasData) {
            return snapshot.data!;
          }
          // Show cached thumbnail while loading
          return Center(
            child: Image.memory(
              cachedThumb,
              fit: fit,
            ),
          );
        },
      );
    }
    
    // No cached thumbnail, load it
    return FutureBuilder<Widget>(
      future: _buildImageWidget(fit: fit),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        return snapshot.data ?? const Center(child: Icon(Icons.image));
      },
    );
  }

  Future<Widget> _buildImageWidget({Uint8List? cachedThumb, required BoxFit fit}) async {
    try {
      final asset = await AssetEntity.fromId(widget.mediaItem.id);
      if (asset == null) {
        return const Center(child: Icon(Icons.image, size: 100));
      }
      
      // Use cached thumbnail if provided, otherwise load it
      Uint8List? thumbnail = cachedThumb;
      if (thumbnail == null) {
        thumbnail = await asset.thumbnailDataWithSize(
          const ThumbnailSize(1200, 1200), // Higher quality thumbnail
        );
      }
      
      // Then get the full file
      final file = await asset.file;
      if (file == null) {
        // If no file, try to show thumbnail if available
        if (thumbnail != null) {
          return Center(
            child: Image.memory(
              thumbnail,
              fit: fit,
            ),
          );
        }
        return const Center(child: Icon(Icons.image, size: 100));
      }
      
      // If we have a thumbnail, show it as background while full image loads on top
      if (thumbnail != null) {
        return Center(
          child: Image.file(
            file,
            fit: fit,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              // Show full image when frame is available, otherwise show thumbnail
              if (wasSynchronouslyLoaded || frame != null) {
                return child;
              }
              // Show thumbnail while loading
              return Image.memory(
                thumbnail!,
                fit: fit,
              );
            },
            errorBuilder: (context, error, stackTrace) {
              // Fallback to thumbnail if full image fails
              return Image.memory(
                thumbnail!,
                fit: fit,
              );
            },
          ),
        );
      }
      
      // Fallback to direct file if no thumbnail available
      return Center(
        child: Image.file(
          file,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return const Center(child: Icon(Icons.image, size: 100));
          },
        ),
      );
    } catch (e) {
      print('Error building image widget: $e');
      return const Center(child: Icon(Icons.image, size: 100));
    }
  }
}


