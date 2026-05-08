import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/media_item.dart';
import 'swipe_card.dart';

/// Wraps [SwipeCard] with a horizontal-drag-to-decide gesture and animated feedback.
///
/// - Drag left past threshold (or tap ❌ Delete) → onDecide(false) — mark for deletion
/// - Drag right past threshold (or tap ✅ Keep)  → onDecide(true)  — keep
/// - [decision]: current stored decision (null=undecided, true=keep, false=delete)
///
/// The parent is responsible for advancing to the next item after onDecide fires.
class ReviewCard extends StatefulWidget {
  final MediaItem mediaItem;
  final Uint8List? cachedThumbnail;
  final bool? decision;
  final void Function(bool keep) onDecide;

  const ReviewCard({
    super.key,
    required this.mediaItem,
    required this.onDecide,
    this.cachedThumbnail,
    this.decision,
  });

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  bool _isDragging = false;
  late final AnimationController _snapController;
  late Animation<double> _snapAnimation;

  static const double _kDecideThreshold = 100.0;
  static const double _kMaxRotationRad = 0.15;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _snapAnimation = Tween<double>(begin: 0, end: 0).animate(_snapController);
    _snapController.addListener(_onSnapTick);
  }

  @override
  void dispose() {
    _snapController.removeListener(_onSnapTick);
    _snapController.dispose();
    super.dispose();
  }

  void _onSnapTick() {
    if (mounted) setState(() => _dragOffset = _snapAnimation.value);
  }

  void _snapBack() {
    final from = _dragOffset;
    _snapAnimation = Tween<double>(begin: from, end: 0).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOut),
    );
    _snapController.forward(from: 0);
  }

  void _onHorizontalDragStart(DragStartDetails _) {
    _snapController.stop();
    setState(() => _isDragging = true);
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() => _dragOffset += details.delta.dx);
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    setState(() => _isDragging = false);
    final velocity = details.primaryVelocity ?? 0;
    if (_dragOffset < -_kDecideThreshold || velocity < -800) {
      widget.onDecide(false);
    } else if (_dragOffset > _kDecideThreshold || velocity > 800) {
      widget.onDecide(true);
    }
    _snapBack();
  }

  @override
  Widget build(BuildContext context) {
    final dragFraction = (_dragOffset / 200.0).clamp(-1.0, 1.0);
    final isDeletingIntent = _isDragging && _dragOffset < -20;
    final isKeepingIntent = _isDragging && _dragOffset > 20;
    final overlayOpacity = (dragFraction.abs() * 0.55).clamp(0.0, 0.55);

    return GestureDetector(
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Transform.translate(
        offset: Offset(_dragOffset, 0),
        child: Transform.rotate(
          angle: dragFraction * _kMaxRotationRad,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SwipeCard(
                mediaItem: widget.mediaItem,
                cachedThumbnail: widget.cachedThumbnail,
              ),

              // Coloured drag-intent overlay
              if (isDeletingIntent || isKeepingIntent)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDeletingIntent
                            ? Colors.red.withOpacity(overlayOpacity)
                            : Colors.green.withOpacity(overlayOpacity),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

              // "DELETE" label — appears on left side while dragging left
              if (isDeletingIntent)
                Positioned(
                  left: 16,
                  top: 16,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: (-dragFraction).clamp(0.0, 1.0),
                      child: _intentLabel('DELETE', Colors.red),
                    ),
                  ),
                ),

              // "KEEP" label — appears on right side while dragging right
              if (isKeepingIntent)
                Positioned(
                  right: 16,
                  top: 16,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: dragFraction.clamp(0.0, 1.0),
                      child: _intentLabel('KEEP', Colors.green),
                    ),
                  ),
                ),

              // Decision badge — shown when not dragging and item is already decided
              if (widget.decision != null && !_isDragging)
                Positioned(
                  top: 10,
                  right: 10,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: widget.decision!
                            ? Colors.green.withOpacity(0.88)
                            : Colors.red.withOpacity(0.88),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.decision! ? '✅ Keep' : '🗑 Delete',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _intentLabel(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
