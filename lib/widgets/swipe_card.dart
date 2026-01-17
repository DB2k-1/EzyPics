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
    // Don't auto-initialize video - wait for user to tap play button
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
        // Don't auto-play - user must tap play button
        print('Video controller ready, muted: $muted');
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
    // Dispose video controller asynchronously to avoid blocking the UI thread
    final controller = _videoController;
    if (controller != null) {
      // Pause first to stop any ongoing operations
      if (controller.value.isInitialized) {
        controller.pause();
      }
      // Dispose asynchronously to avoid blocking
      Future.microtask(() {
        try {
          controller.dispose();
        } catch (e) {
          print('Error disposing video controller: $e');
        }
      });
      _videoController = null;
    }
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
    
    // Don't auto-initialize video - wait for user to tap play button
    
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => _toggleFullscreen(context),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return widget.mediaItem.isVideo
                    ? _buildVideoWidget(constraints)
                    : _buildImageWidgetWithCache(constraints);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoWidget(BoxConstraints constraints) {
    // Calculate aspect ratio first
    final aspectRatio = widget.mediaItem.width / widget.mediaItem.height;
    final isLandscape = widget.mediaItem.width > widget.mediaItem.height;
    
    // Calculate dimensions: landscape fills width, portrait fills height
    double videoWidth;
    double videoHeight;
    
    if (isLandscape) {
      // Landscape: fill width, calculate height
      videoWidth = constraints.maxWidth;
      videoHeight = videoWidth / aspectRatio;
    } else {
      // Portrait: fill height, calculate width
      videoHeight = constraints.maxHeight;
      videoWidth = videoHeight * aspectRatio;
    }
    
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

    // Use cached thumbnail if available, otherwise load it
    final cachedThumb = widget.cachedThumbnail;
    
    // If video is initialized and playing, show player
    if (_videoController != null && _videoController!.value.isInitialized && _videoController!.value.isPlaying) {
      return GestureDetector(
        onTap: () {
          if (_videoController!.value.isPlaying) {
            _videoController!.pause();
            setState(() {});
          } else {
            _videoController!.play();
            setState(() {});
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: SizedBox(
                width: videoWidth,
                height: videoHeight,
                child: VideoPlayer(_videoController!),
              ),
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
    
    // Show thumbnail with play button - don't initialize video until play is tapped
    if (cachedThumb != null) {
      return GestureDetector(
        onTap: () {
          // Initialize and play video when tapped
          if (_videoController == null || !_videoController!.value.isInitialized) {
            _initVideoPlayer().then((_) {
              if (_videoController != null && _videoController!.value.isInitialized && mounted) {
                _videoController!.play();
                setState(() {});
              }
            });
          } else {
            _videoController!.play();
            setState(() {});
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: SizedBox(
                width: videoWidth,
                height: videoHeight,
                child: Image.memory(
                  cachedThumb,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            if (_isVideoInitializing)
              const Center(
                child: CircularProgressIndicator(),
              ),
            const Center(
              child: Icon(
                Icons.play_circle_filled,
                size: 80,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    
    // No cached thumbnail, load it
    return FutureBuilder<Uint8List?>(
      future: _getVideoThumbnail(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return GestureDetector(
            onTap: () {
              // Initialize and play video when tapped
              if (_videoController == null || !_videoController!.value.isInitialized) {
                _initVideoPlayer().then((_) {
                  if (_videoController != null && _videoController!.value.isInitialized && mounted) {
                    _videoController!.play();
                    setState(() {});
                  }
                });
              } else {
                _videoController!.play();
                setState(() {});
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: SizedBox(
                    width: videoWidth,
                    height: videoHeight,
                    child: Image.memory(
                      snapshot.data!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                if (_isVideoInitializing)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                const Center(
                  child: Icon(
                    Icons.play_circle_filled,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
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

  Future<Uint8List?> _getVideoThumbnail() async {
    try {
      final asset = await AssetEntity.fromId(widget.mediaItem.id)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (asset != null) {
        return await asset.thumbnailDataWithSize(
          ThumbnailSize(widget.mediaItem.width, widget.mediaItem.height),
        ).timeout(const Duration(seconds: 5), onTimeout: () => null);
      }
    } catch (e) {
      print('Error getting video thumbnail: $e');
    }
    return null;
  }

  Widget _buildImageWidgetWithCache(BoxConstraints constraints) {
    // Calculate aspect ratio
    final aspectRatio = widget.mediaItem.width / widget.mediaItem.height;
    final isLandscape = widget.mediaItem.width > widget.mediaItem.height;
    
    // Calculate dimensions: landscape fills width, portrait fills height
    double imageWidth;
    double imageHeight;
    
    if (isLandscape) {
      // Landscape: fill width, calculate height
      imageWidth = constraints.maxWidth;
      imageHeight = imageWidth / aspectRatio;
    } else {
      // Portrait: fill height, calculate width
      imageHeight = constraints.maxHeight;
      imageWidth = imageHeight * aspectRatio;
    }
    
    // Use cached thumbnail if available for instant display
    final cachedThumb = widget.cachedThumbnail;
    
    if (cachedThumb != null) {
      // Show cached thumbnail with proper aspect ratio
      return RepaintBoundary(
        child: Center(
          child: SizedBox(
            width: imageWidth,
            height: imageHeight,
            child: Image.memory(
              cachedThumb,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    }
    
    // No cached thumbnail, load it
    return FutureBuilder<Uint8List?>(
      future: _loadImageThumbnail(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData && snapshot.data != null) {
          return RepaintBoundary(
            child: Center(
              child: SizedBox(
                width: imageWidth,
                height: imageHeight,
                child: Image.memory(
                  snapshot.data!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          );
        }
        return const Center(child: Icon(Icons.image));
      },
    );
  }

  Future<Uint8List?> _loadImageThumbnail() async {
    try {
      final asset = await AssetEntity.fromId(widget.mediaItem.id)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (asset == null) return null;
      
      // Generate thumbnail maintaining aspect ratio
      // Use max dimension of 800, but maintain aspect ratio
      int thumbWidth;
      int thumbHeight;
      
      if (widget.mediaItem.width > widget.mediaItem.height) {
        // Landscape: width is larger
        thumbWidth = 800;
        thumbHeight = (800 * widget.mediaItem.height / widget.mediaItem.width).round();
      } else {
        // Portrait: height is larger
        thumbHeight = 800;
        thumbWidth = (800 * widget.mediaItem.width / widget.mediaItem.height).round();
      }
      
      return await asset.thumbnailDataWithSize(
        ThumbnailSize(thumbWidth, thumbHeight),
      ).timeout(const Duration(seconds: 5), onTimeout: () => null);
    } catch (e) {
      print('Error loading image thumbnail: $e');
      return null;
    }
  }
}


