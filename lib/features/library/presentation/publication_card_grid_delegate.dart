import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// Sizes a publication card from its cover's ratio plus a fixed metadata area.
class PublicationCardGridDelegate extends SliverGridDelegate {
  const PublicationCardGridDelegate({
    required this.maxCrossAxisExtent,
    required this.coverAspectRatio,
    required this.footerExtent,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = 0,
  }) : assert(maxCrossAxisExtent > 0),
       assert(coverAspectRatio > 0),
       assert(footerExtent >= 0),
       assert(mainAxisSpacing >= 0),
       assert(crossAxisSpacing >= 0);

  /// The maximum width of a card before another grid column is added.
  final double maxCrossAxisExtent;

  /// The cover width divided by its height.
  final double coverAspectRatio;

  /// The fixed height reserved for the title and progress area.
  final double footerExtent;

  /// The vertical gap between cards.
  final double mainAxisSpacing;

  /// The horizontal gap between cards.
  final double crossAxisSpacing;

  /// Calculates a card's total height for the available card width.
  double mainAxisExtentFor(double crossAxisExtent) =>
      crossAxisExtent / coverAspectRatio + footerExtent;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final crossAxisCount = math.max(
      1,
      (constraints.crossAxisExtent / (maxCrossAxisExtent + crossAxisSpacing))
          .ceil(),
    );
    final usableCrossAxisExtent =
        constraints.crossAxisExtent - crossAxisSpacing * (crossAxisCount - 1);
    final childCrossAxisExtent = usableCrossAxisExtent / crossAxisCount;
    final childMainAxisExtent = mainAxisExtentFor(childCrossAxisExtent);

    return SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: childMainAxisExtent + mainAxisSpacing,
      crossAxisStride: childCrossAxisExtent + crossAxisSpacing,
      childMainAxisExtent: childMainAxisExtent,
      childCrossAxisExtent: childCrossAxisExtent,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(covariant PublicationCardGridDelegate oldDelegate) =>
      maxCrossAxisExtent != oldDelegate.maxCrossAxisExtent ||
      coverAspectRatio != oldDelegate.coverAspectRatio ||
      footerExtent != oldDelegate.footerExtent ||
      mainAxisSpacing != oldDelegate.mainAxisSpacing ||
      crossAxisSpacing != oldDelegate.crossAxisSpacing;
}
