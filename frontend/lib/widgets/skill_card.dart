import 'package:flutter/material.dart';

import '../models/neighbor_skill.dart';
import '../theme/colors.dart';
import 'availability_badge.dart';

class SkillCard extends StatelessWidget {
  const SkillCard({
    super.key,
    required this.neighbor,
    this.onRequest,
  });

  final NeighborSkill neighbor;
  final VoidCallback? onRequest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final avatarColor = AppColors.avatarFor(neighbor.name, isDark: isDark);
    final isAvailable = neighbor.available;

    final metaParts = <String>[
      if (neighbor.km != null) '≈${neighbor.km!.toStringAsFixed(1)} km',
      if (neighbor.grid != null && neighbor.grid!.trim().isNotEmpty)
        neighbor.grid!,
    ];

    final metaSuffix =
        metaParts.isEmpty ? '' : '  ·  ${metaParts.join(' · ')}';

    final hasBlurb = neighbor.blurb.trim().isNotEmpty;

    final cardBg = isDark
        ? AppColors.darkPaper.withValues(alpha: 0.92)
        : AppColors.paper.withValues(alpha: 0.92);

    final cardBorder = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.8);

    final cardShadow = isDark
        ? Colors.black.withValues(alpha: 0.25)
        : AppColors.inkSoft.withValues(alpha: 0.05);

    final avatarBorder = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.5)
        : Colors.white.withValues(alpha: 0.8);

    final buttonBg = isAvailable
        ? AppColors.terracotta
        : (isDark ? AppColors.darkSand : AppColors.sand);

    final buttonFg = isAvailable
        ? Colors.white
        : (isDark ? AppColors.darkInkFaint : AppColors.inkFaint);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: cardShadow,
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: avatarColor.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(color: avatarBorder, width: 1),
                ),
                child: Text(
                  neighbor.initial,
                  style: TextStyle(
                    color: avatarColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      neighbor.skill,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text.rich(
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      TextSpan(
                        style: TextStyle(
                          fontSize: 12.5,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          height: 1.35,
                        ),
                        children: [
                          TextSpan(
                            text: neighbor.name,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(text: metaSuffix),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AvailabilityBadge(available: neighbor.available),
            ],
          ),
          if (hasBlurb) ...[
            const SizedBox(height: 12),
            Text(
              neighbor.blurb,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isAvailable ? onRequest : null,
              style: FilledButton.styleFrom(
                backgroundColor: buttonBg,
                foregroundColor: buttonFg,
                disabledBackgroundColor: isDark
                    ? AppColors.darkSand.withValues(alpha: 0.7)
                    : AppColors.sand.withValues(alpha: 0.7),
                disabledForegroundColor: isDark
                    ? AppColors.darkInkFaint
                    : AppColors.inkFaint,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
              icon: Icon(
                isAvailable
                    ? Icons.handshake_outlined
                    : Icons.schedule_rounded,
                size: 18,
              ),
              label: Text(
                isAvailable ? 'Ask for help' : 'Currently busy',
              ),
            ),
          ),
        ],
      ),
    );
  }
}