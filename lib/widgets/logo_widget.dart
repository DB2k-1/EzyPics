import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import '../utils/adaptive_layout.dart';

/// The blue EzyPics banner across the top of every screen, drawn under the
/// status bar.
///
/// On phones it fills the width at the artwork's own shape, as it always has.
/// On short or wide screens (iPhone Duo, foldables, landscape) that would take
/// too much height, so it's capped at [maxHeightFraction] of the screen: the
/// artwork stays sharp at that height, centred over the left pane in two-pane
/// layouts so the wordmark stays off the fold, and a blurred copy fills the
/// rest of the width.
class LogoWidget extends StatelessWidget {
  final String? selectedDateKey;
  final VoidCallback? onTap;

  /// Overrides the usual height cap, e.g. for the top half of tabletop mode.
  final double? maxHeight;

  const LogoWidget({super.key, this.selectedDateKey, this.onTap, this.maxHeight});

  static const String _asset = 'assets/EzyPics_big_banner_cropped.png';
  static const double _aspectRatio = 1536 / 697;
  static const double maxHeightFraction = 0.25;

  /// The banner's height for the current screen.
  static double heightOf(BuildContext context, {double? maxHeight}) {
    final Size size = MediaQuery.sizeOf(context);
    final double natural = size.width / _aspectRatio;
    final double cap = maxHeight ?? size.height * maxHeightFraction;
    return math.max(0, math.min(natural, cap));
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final double height = heightOf(context, maxHeight: maxHeight);
    final double naturalHeight = size.width / _aspectRatio;

    Widget banner;
    if (height >= naturalHeight - 0.5) {
      banner = Image.asset(
        _asset,
        fit: BoxFit.cover,
        width: double.infinity,
        height: height,
        errorBuilder: (context, error, stackTrace) => _fallback(context),
      );
    } else {
      final layout = PaneLayout.of(context);
      final double artWidth = height * _aspectRatio;
      // Centre over the visible area, clear of side status bars and cameras
      // (iPhone Duo's outer display puts its status bar down the side).
      final EdgeInsets insets = MediaQuery.paddingOf(context);
      final double paneCentre = layout.twoPane
          ? insets.left + layout.leading / 2
          : insets.left + (size.width - insets.left - insets.right) / 2;
      final double artLeft =
          (paneCentre - artWidth / 2).clamp(0.0, math.max(0.0, size.width - artWidth));
      banner = SizedBox(
        width: double.infinity,
        height: height,
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24, tileMode: TileMode.clamp),
                child: Image.asset(_asset, fit: BoxFit.cover),
              ),
              Positioned(
                left: artLeft,
                top: 0,
                width: artWidth,
                height: height,
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                    stops: [0, 0.15, 0.85, 1],
                  ).createShader(rect),
                  child: Image.asset(
                    _asset,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _fallback(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(onTap: onTap, child: banner);
  }

  Widget _fallback(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      alignment: Alignment.center,
      child: Text(
        'EzyPics',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
