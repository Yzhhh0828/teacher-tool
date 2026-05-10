import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/design/tokens.dart';

/// A shimmer loading placeholder that replaces CircularProgressIndicator.
///
/// Usage:
/// ```dart
/// ShimmerSkeleton.card(width: 200, height: 120)
/// ShimmerSkeleton.list(itemCount: 5)
/// ```
class ShimmerSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerSkeleton({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = AppRadius.s,
  });

  /// A single rectangular skeleton block.
  const ShimmerSkeleton.block({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = AppRadius.s,
  });

  /// A card-shaped skeleton.
  factory ShimmerSkeleton.card({
    Key? key,
    double width = double.infinity,
    double height = 120,
  }) =>
      ShimmerSkeleton(
        key: key,
        width: width,
        height: height,
        borderRadius: AppRadius.m,
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseColor = scheme.surfaceContainerHighest;
    final highlightColor = scheme.surface;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: AppMotion.grand,
          color: highlightColor.withValues(alpha: 0.5),
        );
  }

  /// Builds a vertical list of shimmer skeletons mimicking a list page.
  static Widget list({
    int itemCount = 4,
    double itemHeight = 72,
    double spacing = AppSpacing.gap3,
    EdgeInsets padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.pagePadding,
      vertical: AppSpacing.gap4,
    ),
  }) {
    return Padding(
      padding: padding,
      child: Column(
        children: List.generate(itemCount, (i) {
          return Padding(
            padding: EdgeInsets.only(bottom: i < itemCount - 1 ? spacing : 0),
            child: ShimmerSkeleton(height: itemHeight, borderRadius: AppRadius.m),
          );
        }),
      ),
    );
  }

  /// Builds a grid of shimmer skeletons.
  static Widget grid({
    int crossAxisCount = 2,
    int itemCount = 4,
    double childAspectRatio = 1.0,
    EdgeInsets padding = const EdgeInsets.all(AppSpacing.pagePadding),
  }) {
    return Padding(
      padding: padding,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: AppSpacing.gap3,
          crossAxisSpacing: AppSpacing.gap3,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: itemCount,
        itemBuilder: (_, __) =>
            const ShimmerSkeleton(height: double.infinity, borderRadius: AppRadius.m),
      ),
    );
  }

  /// Profile-style skeleton with avatar circle + text lines.
  static Widget profile({Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Row(
        children: [
          const ShimmerSkeleton(
            width: 48,
            height: 48,
            borderRadius: AppRadius.pill,
          ),
          const SizedBox(width: AppSpacing.gap3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerSkeleton.block(width: 140, height: 14),
                const SizedBox(height: AppSpacing.gap2),
                ShimmerSkeleton.block(width: 200, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
