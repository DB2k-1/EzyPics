import 'package:flutter/material.dart';
import '../utils/adaptive_layout.dart';
import 'logo_widget.dart';

/// Arranges the review screen's three parts for the current display:
///
/// - **Phones:** header, photo, then the buttons along the bottom.
/// - **Two panes** (iPhone Duo open, foldables, landscape): the photo in the
///   left pane; the header, buttons and progress in the right pane.
/// - **Tabletop** (half-folded, fold across the screen): header and photo in
///   the top half, buttons and progress in the bottom half.
///
/// [pager] keeps its state across layout changes (opening or closing the
/// phone) because the caller gives it a [GlobalKey].
class ReviewLayout extends StatelessWidget {
  final Widget header;
  final Widget pager;
  final Widget controls;

  /// Extra detail under the controls, shown only in two-pane layouts where
  /// the right pane would otherwise be mostly empty.
  final Widget? details;

  /// How far below the top of the screen this layout starts: the banner's
  /// height. Needed to line the tabletop split up with the hinge.
  final double topOffset;

  const ReviewLayout({
    super.key,
    required this.header,
    required this.pager,
    required this.controls,
    required this.topOffset,
    this.details,
  });

  @override
  Widget build(BuildContext context) {
    final layout = PaneLayout.of(context);

    final double? tabletopTop = layout.tabletopTop;
    if (tabletopTop != null) {
      return Column(
        children: [
          SizedBox(
            height: (tabletopTop - topOffset).clamp(0.0, double.infinity),
            child: SafeArea(
              top: false,
              bottom: false,
              child: Column(children: [header, Expanded(child: pager)]),
            ),
          ),
          SizedBox(height: layout.gap),
          Expanded(
            child: SafeArea(
              top: false,
              child: Center(child: SingleChildScrollView(child: controls)),
            ),
          ),
        ],
      );
    }

    if (layout.twoPane) {
      return SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: layout.leading, child: pager),
            SizedBox(width: layout.gap),
            Expanded(
              child: Column(
                children: [
                  header,
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [controls, if (details != null) details!],
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

    return SafeArea(
      top: false,
      bottom: false,
      child: Column(
        children: [
          header,
          Expanded(child: pager),
          SafeArea(top: false, child: controls),
        ],
      ),
    );
  }

  /// Banner height to use above a [ReviewLayout]: in tabletop it's limited to
  /// a share of the top half so the photo keeps most of it.
  static double? bannerMaxHeight(BuildContext context) {
    final double? tabletopTop = PaneLayout.of(context).tabletopTop;
    return tabletopTop == null ? null : tabletopTop * 0.28;
  }

  static double bannerHeight(BuildContext context) =>
      LogoWidget.heightOf(context, maxHeight: bannerMaxHeight(context));
}
