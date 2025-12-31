import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import '../models/media_item.dart';

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

  @override
  void initState() {
    super.initState();
    widget.controller.play();
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
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () {
                  widget.controller.pause();
                  Navigator.of(context).pop();
                },
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

  const SwipeCard({super.key, required this.mediaItem});

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard> {
  VideoPlayerController? _videoController;
  bool _isVideoInitializing = false;
  String? _videoError;

  @override
  void initState() {
    super.initState();
    if (widget.mediaItem.isVideo) {
      _initVideoPlayer();
    }
  }

  Future<void> _initVideoPlayer() async {
    if (_isVideoInitializing) return;
    
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

      if (!mounted) return;

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

      if (!mounted) return;

      print('Creating video controller for: ${file.path}');
      _videoController = VideoPlayerController.file(file);
      await _videoController!.initialize();
      print('Video controller initialized: ${_videoController!.value.isInitialized}');
      print('Video duration: ${_videoController!.value.duration}');
      print('Video size: ${_videoController!.value.size}');
      
      if (mounted) {
        setState(() {
          _isVideoInitializing = false;
        });
        // Auto-play video when it's ready
        _videoController!.play();
        print('Video playback started');
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
    return GestureDetector(
      onTap: () => _toggleFullscreen(context),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: widget.mediaItem.isVideo
              ? _buildVideoWidget()
              : FutureBuilder<Widget>(
                  future: _buildImageWidget(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return snapshot.data ?? const Center(child: Icon(Icons.image));
                  },
                ),
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
          AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: VideoPlayer(_videoController!),
          ),
          if (!_videoController!.value.isPlaying)
            const Center(
              child: Icon(
                Icons.play_circle_filled,
                size: 64,
                color: Colors.white70,
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

  Future<Widget> _buildImageWidget() async {
    try {
      final asset = await AssetEntity.fromId(widget.mediaItem.id);
      if (asset == null) {
        return const Center(child: Icon(Icons.image, size: 100));
      }
      final file = await asset.file;
      if (file == null) {
        return const Center(child: Icon(Icons.image, size: 100));
      }
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Center(child: Icon(Icons.image, size: 100));
        },
      );
    } catch (e) {
      print('Error building image widget: $e');
      return const Center(child: Icon(Icons.image, size: 100));
    }
  }
}


