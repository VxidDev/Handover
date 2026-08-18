// lib/widgets/skill_card.dart
import 'package:flutter/material.dart';

import '../models/neighbor_skill.dart';
import '../screens/skill_detail_page.dart';
import '../theme/colors.dart';
import '../services/api.dart';

import 'availability_badge.dart';

class SkillCard extends StatelessWidget {
  const SkillCard({super.key, required this.neighbor, this.onRequest});

  final NeighborSkill neighbor;
  final VoidCallback? onRequest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final avatarColor = AppColors.avatarFor(neighbor.name, isDark: isDark);
    final hasImages = neighbor.images.isNotEmpty;

    final cardBg = isDark
        ? AppColors.darkPaper.withValues(alpha: 0.88)
        : AppColors.paper.withValues(alpha: 0.9);
    final cardBorder = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.5)
        : Colors.white.withValues(alpha: 0.8);
    final cardShadow = isDark
        ? Colors.black.withValues(alpha: 0.15)
        : AppColors.inkSoft.withValues(alpha: 0.035);

    final metaParts = <String>[
      if (neighbor.km != null) '≈${neighbor.km!.toStringAsFixed(1)} km',
      if (neighbor.grid != null && neighbor.grid!.trim().isNotEmpty)
        neighbor.grid!,
    ];

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 340),
            reverseTransitionDuration: const Duration(milliseconds: 280),
            pageBuilder: (_, animation, __) => SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: FadeTransition(
                opacity: animation,
                child: SkillDetailPage(
                  neighbor: neighbor,
                  onRequest: onRequest,
                ),
              ),
            ),
          ),
        );
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: cardShadow,
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image carousel (preview)
            if (hasImages) _buildImagePreview(theme, isDark),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + availability
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          neighbor.skill,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            fontSize: 15,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      AvailabilityBadge(available: neighbor.available),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Owner row
                  Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: avatarColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          neighbor.initial,
                          style: TextStyle(
                            color: avatarColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          neighbor.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (metaParts.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          metaParts.join(' · '),
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.45,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Blurb preview
                  if (neighbor.blurb.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      neighbor.blurb,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(ThemeData theme, bool isDark) {
    final imageCount = neighbor.images.length;
    final imageBaseUrl = Api.baseUrl; // Add this
    final path = neighbor.images.first;
    final url = path.startsWith('http')
        ? path
        : '$imageBaseUrl$path'; // Construct full URL

    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: Image.network(
            url, // Use the full URL instead of just the path
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: isDark
                  ? AppColors.darkSand.withValues(alpha: 0.4)
                  : AppColors.sand.withValues(alpha: 0.4),
              child: Icon(
                Icons.image_outlined,
                size: 36,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
              ),
            ),
          ),
        ),
        if (imageCount > 1)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.photo_library_outlined,
                    size: 11,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$imageCount',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
