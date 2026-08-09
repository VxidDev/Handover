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
    final avatarColor = AppColors.avatarFor(neighbor.name);
    final isAvailable = neighbor.available;

    final metaParts = <String>[
      if (neighbor.km != null) '≈${neighbor.km!.toStringAsFixed(1)} km',
      if (neighbor.grid != null && neighbor.grid!.trim().isNotEmpty)
        neighbor.grid!,
    ];

    final metaSuffix =
        metaParts.isEmpty ? '' : '  ·  ${metaParts.join(' · ')}';

    final hasBlurb = neighbor.blurb.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.paper.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.inkSoft.withValues(alpha: 0.05),
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
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                    width: 1,
                  ),
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
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text.rich(
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      TextSpan(
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.inkFaint,
                          height: 1.35,
                        ),
                        children: [
                          TextSpan(
                            text: neighbor.name,
                            style: TextStyle(
                              color: AppColors.inkSoft.withValues(alpha: 0.9),
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
                color: AppColors.inkSoft.withValues(alpha: 0.95),
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
                backgroundColor:
                    isAvailable ? AppColors.terracotta : AppColors.sand,
                foregroundColor:
                    isAvailable ? Colors.white : AppColors.inkFaint,
                disabledBackgroundColor:
                    AppColors.sand.withValues(alpha: 0.7),
                disabledForegroundColor: AppColors.inkFaint,
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