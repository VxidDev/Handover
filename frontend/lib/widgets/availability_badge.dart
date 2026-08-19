import 'package:flutter/material.dart';
import '../theme/colors.dart';

class AvailabilityBadge extends StatelessWidget {
  const AvailabilityBadge({super.key, required this.available});

  final bool available;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final dotColor = available
        ? AppColors.success
        : (isDark ? AppColors.darkInkFaint : AppColors.inkFaint);

    final bgColor = available
        ? (isDark
              ? AppColors.sage.withValues(alpha: 0.18)
              : AppColors.sageLight)
        : (isDark ? AppColors.darkSand : AppColors.sand);

    final textColor = available
        ? (isDark ? AppColors.sage : AppColors.terracottaDeep)
        : (isDark ? AppColors.darkInkFaint : AppColors.inkFaint);

    // In dark mode, we use lower alphas for the background and border
    // so the badge feels like a subtle tint rather than a solid shape.
    final bgAlpha = isDark ? 0.25 : 0.6;
    final borderAlpha = isDark ? 0.4 : 0.8;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: bgColor.withValues(alpha: borderAlpha),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: available
                  ? [
                      BoxShadow(
                        color: dotColor.withValues(alpha: 0.4),
                        blurRadius: 4,
                        spreadRadius: 0.5,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            available ? 'Available' : 'Busy',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
