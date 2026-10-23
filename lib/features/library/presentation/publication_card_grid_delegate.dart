import 'package:flutter/rendering.dart';

/// Sizes a publication card from its cover's ratio plus a fixed metadata area.
class PublicationCardGridDelegate extends SliverGridDelegate {
  const PublicationCardGridDelegate({
    required this.crossAxisCount,
    required this.coverAspectRatio,
    required this.footerExtent,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = 0,
  }) : assert(crossAxisCount > 0),
       assert(coverAspectRatio > 0),
       assert(footerExtent >= 0),
       assert(mainAxisSpacing >= 0),
       assert(crossAxisSpacing >= 0);

  /// The number of columns at the current responsive breakpoint.
  final int crossAxisCount;

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
      crossAxisCount != oldDelegate.crossAxisCount ||
      coverAspectRatio != oldDelegate.coverAspectRatio ||
      footerExtent != oldDelegate.footerExtent ||
      mainAxisSpacing != oldDelegate.mainAxisSpacing ||
      crossAxisSpacing != oldDelegate.crossAxisSpacing;
}
