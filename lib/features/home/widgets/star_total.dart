import 'package:flutter/material.dart';
import 'package:mind_spark/core/theme/app_images.dart';
import 'package:mind_spark/core/theme/app_theme.dart';

/// Top-left badge showing the total stars collected across all levels
/// (sum of the player's best stars per level). Presentation only.
final class StarTotal extends StatelessWidget {
  const StarTotal({super.key, required this.total, this.size = 26});

  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Total stars $total',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(AppImages.star, width: size, height: size),
          const SizedBox(width: 6),
          Text(
            '$total',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.frost,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
