import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureState;

import 'package:flutter/material.dart';

/// How a screen splits on large and folding displays (iPhone Duo, Android
/// foldables, tablets, phones in landscape).
///
/// - **Single pane** on normal phones: the screen's usual layout.
/// - **Two panes** on wide windows: [leading] is the width of the left pane and
///   [gap] the space between the panes. The split follows the hinge when
///   Flutter reports one (Android foldables); otherwise it sits in the middle,
///   which is where iPhone Duo folds. iOS doesn't report the fold to Flutter.
/// - **Tabletop** when a device is half-folded with the fold running across the
///   screen (Galaxy Z Flip in Flex Mode, or a book-style foldable held like a
///   laptop): [tabletopTop] is the height of the top half, measured from the
///   top of the screen. Android only, for the same reason.
///
/// Widths exclude the left and right safe-area insets, so lay panes out inside
/// a `SafeArea(top: false)`.
class PaneLayout {
  final bool twoPane;
  final double leading;
  final double gap;
  final double? tabletopTop;

  const PaneLayout._({
    required this.twoPane,
    required this.leading,
    required this.gap,
    this.tabletopTop,
  });

  bool get isTabletop => tabletopTop != null;

  /// Narrowest window that gets two panes in portrait. Landscape windows need
  /// only [_landscapeTwoPaneMinWidth].
  static const double _twoPaneMinWidth = 700;
  static const double _landscapeTwoPaneMinWidth = 560;
  static const double _paneGap = 24;

  /// Widest a single-column layout grows before it's centred, so cards don't
  /// stretch across the Duo's inner screen in portrait.
  static const double maxSingleColumnWidth = 560;

  static PaneLayout of(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    final double width = size.width - padding.left - padding.right;
    final List<DisplayFeature> features = MediaQuery.displayFeaturesOf(context);

    // Half-folded with the hinge running across the screen.
    for (final DisplayFeature feature in features) {
      final Rect bounds = feature.bounds;
      if (feature.state == DisplayFeatureState.postureHalfOpened &&
          bounds.width >= size.width * 0.9) {
        final double gap = math.max(bounds.height, _paneGap);
        return PaneLayout._(
          twoPane: false,
          leading: width,
          gap: gap,
          tabletopTop: bounds.center.dy - gap / 2,
        );
      }
    }

    final bool landscape = size.width > size.height;
    final bool wide = width >= _twoPaneMinWidth ||
        (landscape && width >= _landscapeTwoPaneMinWidth);
    if (!wide) return PaneLayout._(twoPane: false, leading: width, gap: 0);

    // A vertical hinge, or a fold the device reports as half-open: split on it.
    for (final DisplayFeature feature in features) {
      final Rect bounds = feature.bounds;
      final bool separates = bounds.shortestSide > 0 ||
          feature.state == DisplayFeatureState.postureHalfOpened;
      if (separates && bounds.height >= size.height * 0.9) {
        final double gap = math.max(bounds.width, _paneGap);
        return PaneLayout._(
          twoPane: true,
          leading: bounds.center.dx - padding.left - gap / 2,
          gap: gap,
        );
      }
    }
    return PaneLayout._(twoPane: true, leading: (width - _paneGap) / 2, gap: _paneGap);
  }
}

/// Centres [child] in the left pane on two-pane layouts, keeping it off the
/// fold. On single-pane layouts it's centred in the full width.
class LeadingPaneCenter extends StatelessWidget {
  final Widget child;

  const LeadingPaneCenter({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final layout = PaneLayout.of(context);
    return SafeArea(
      top: false,
      bottom: false,
      child: layout.twoPane
          ? Row(
              children: [
                SizedBox(width: layout.leading, child: Center(child: child)),
                const Spacer(),
              ],
            )
          : Center(child: child),
    );
  }
}

/// Centres a single column and stops it growing past
/// [PaneLayout.maxSingleColumnWidth]. Phones are narrower than that, so it
/// changes nothing there.
class SingleColumn extends StatelessWidget {
  final Widget child;

  const SingleColumn({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: PaneLayout.maxSingleColumnWidth),
        child: child,
      ),
    );
  }
}
