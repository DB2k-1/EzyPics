import 'dart:async';
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
  Timer? _hideControlsTimer;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.controller.value.isPlaying;
    widget.controller.addListener(_onVideoStateChanged);
    if (!_isPlaying) {
      widget.controller.play();
      _isPlaying = true;
    }
    _loadMuteState();
    _startHideControlsTimer();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    widget.controller.removeListener(_onVideoStateChanged);
    super.dispose();
  }

  void _onVideoStateChanged() {
    if (!mounted) return;
    final isPlaying = widget.controller.value.isPlaying;
    if (_isPlaying != isPlaying) {
      setState(() {
        _isPlaying = isPlaying;
        if (isPlaying) {
          _startHideControlsTimer(); // Auto-hide when playing
        } else {
          _hideControlsTimer?.cancel();
          _showControls = true; // Show controls when paused
        }
      });
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 1), () {
      if (mounted && _isPlaying) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _showControlsTemporarily() {
    if (!_showControls) {
      setState(() {
        _showControls = true;
      });
    }
    _startHideControlsTimer();
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
    _showControlsTemporarily();
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      widget.controller.pause();
      // Immediately update state when pausing - don't wait for listener
      setState(() {
        _isPlaying = false;
        _showControls = true;
      });
      _hideControlsTimer?.cancel();
    } else {
      widget.controller.play();
      // Immediately update state when playing - don't wait for listener
      setState(() {
        _isPlaying = true;
      });
      // Show controls temporarily then auto-hide
      _showControlsTemporarily();
    }
  }

  double _dragOffset = 0.0;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(_isDragging ? 0.5 : 1.0),
      body: SafeArea(
        child: Stack(
          children: [
            // Video area with drag gesture - covers full screen
            Positioned.fill(
              child: GestureDetector(
                onVerticalDragStart: (_) {
                  setState(() {
                    _isDragging = true;
                  });
                },
                onVerticalDragUpdate: (details) {
                  if (details.delta.dy > 0) {
                    setState(() {
                      _dragOffset += details.delta.dy;
                    });
                  }
                },
                onVerticalDragEnd: (details) {
                  if (_dragOffset > 100) {
                    widget.controller.pause();
                    Navigator.of(context).pop();
                  } else {
                    setState(() {
                      _dragOffset = 0.0;
                      _isDragging = false;
                    });
                  }
                },
                onTap: () {
                  // Toggle play/pause when video area is tapped
                  _togglePlayPause();
                },
                child: Transform.translate(
                  offset: Offset(0, _dragOffset),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: widget.controller.value.aspectRatio,
                      child: VideoPlayer(widget.controller),
                    ),
                  ),
                ),
              ),
            ),
            // Controls overlay - semi-transparent background when controls are shown
            if (_showControls)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: true, // Let taps pass through to video GestureDetector
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                  ),
                ),
              ),
            // Play/pause button in center - only shown when controls are visible
            if (_showControls)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: false, // This button needs to receive taps
                  child: Center(
                    child: Material(
                      color: Colors.transparent,
                      child: IconButton(
                        icon: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 64,
                        ),
                        onPressed: _togglePlayPause,
                      ),
                    ),
                  ),
                ),
              ),
            // Top-right control buttons - ALWAYS visible, positioned last to be on top
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mute/unmute button - ALWAYS visible
                  Material(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      onTap: () {
                        _showControlsTemporarily();
                        _toggleMute();
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
                  const SizedBox(width: 8),
                  // Close button - ALWAYS visible
                  Material(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      onTap: () {
                        widget.controller.pause();
                        Navigator.of(context).pop();
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
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
    // Don't auto-initialize video - wait for user to tap play button
  }

  Future<void> _initVideoPlayer() async {
    if (_isVideoInitializing) {
      return;
    }
    
    if (_videoController != null && _videoController!.value.isInitialized) {
      return;
    }
    
    setState(() {
      _isVideoInitializing = true;
      _videoError = null;
    });

    try {
      final asset = await AssetEntity.fromId(widget.mediaItem.id);
      if (asset == null) {
        if (mounted) {
          setState(() {
            _videoError = 'Asset not found';
            _isVideoInitializing = false;
          });
        }
        return;
      }

      if (!mounted) {
        return;
      }

      final file = await asset.file;
      if (file == null) {
        if (mounted) {
          setState(() {
            _videoError = 'File not found';
            _isVideoInitializing = false;
          });
        }
        return;
      }

      if (!mounted) {
        return;
      }

      _videoController = VideoPlayerController.file(file);
      await _videoController!.initialize();
      
      if (mounted) {
        // Load mute state and apply it
        final muted = await VideoSettingsService.isMuted();
        _videoController!.setVolume(muted ? 0.0 : 1.0);
        
        setState(() {
          _isVideoInitializing = false;
          _isMuted = muted;
        });
        // Don't auto-play - user must tap play button
      } else {
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
            // Control buttons in bottom right
            Positioned(
              bottom: 16,
              right: 16,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Fullscreen button
                  Material(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      onTap: () => _showFullscreenVideo(context),
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: const Icon(
                          Icons.fullscreen,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Mute/unmute toggle button
                  Material(
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
                ],
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
        // Use fixed max dimension to avoid full-resolution decode (memory)
        const maxDim = 480;
        final w = widget.mediaItem.width;
        final h = widget.mediaItem.height;
        final thumbW = w > h ? maxDim : (maxDim * w / h).round();
        final thumbH = w > h ? (maxDim * h / w).round() : maxDim;
        return await asset.thumbnailDataWithSize(
          ThumbnailSize(thumbW, thumbH),
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
      
      // Use 480 max dimension to limit memory (avoid 800+ on large libraries)
      const maxDim = 480;
      int thumbWidth;
      int thumbHeight;
      if (widget.mediaItem.width > widget.mediaItem.height) {
        thumbWidth = maxDim;
        thumbHeight = (maxDim * widget.mediaItem.height / widget.mediaItem.width).round();
      } else {
        thumbHeight = maxDim;
        thumbWidth = (maxDim * widget.mediaItem.width / widget.mediaItem.height).round();
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


