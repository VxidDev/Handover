// lib/screens/skill_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/neighbor_skill.dart';
import '../services/api.dart';
import '../theme/colors.dart';
import '../widgets/availability_badge.dart';
import '../widgets/image_viewer.dart';

class SkillDetailPage extends StatefulWidget {
  const SkillDetailPage({super.key, required this.neighbor, this.onRequest});

  final NeighborSkill neighbor;
  final VoidCallback? onRequest;

  @override
  State<SkillDetailPage> createState() => _SkillDetailPageState();
}

class _SkillDetailPageState extends State<SkillDetailPage> {
  late final PageController _pageController;
  int _currentImage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openImageViewer() {
    if (widget.neighbor.images.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (ctx, anim, _) => FadeTransition(
          opacity: anim,
          child: ImageViewerPage(
            images: widget.neighbor.images
                .map((p) => p.startsWith('http') ? p : '${Api.baseUrl}$p')
                .toList(),
            initialIndex: _currentImage,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final neighbor = widget.neighbor;
    final avatarColor = AppColors.avatarFor(neighbor.name, isDark: isDark);
    final hasImages = neighbor.images.isNotEmpty;
    final imageBaseUrl = Api.baseUrl;

    final metaParts = <String>[
      if (neighbor.km != null) '≈${neighbor.km!.toStringAsFixed(1)} km away',
      if (neighbor.grid != null && neighbor.grid!.trim().isNotEmpty)
        neighbor.grid!,
      '${neighbor.karma} karma',
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Scrollable content
          CustomScrollView(
            slivers: [
              // ─── Image carousel with back button ───
              SliverAppBar(
                expandedHeight: hasImages ? 320 : 180,
                pinned: true,
                backgroundColor: theme.scaffoldBackgroundColor,
                elevation: 0,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkPaper.withValues(alpha: 0.85)
                            : Colors.white.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder.withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.9),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: hasImages
                      ? GestureDetector(
                          onTap: _openImageViewer,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              PageView.builder(
                                controller: _pageController,
                                onPageChanged: (i) {
                                  setState(() => _currentImage = i);
                                  HapticFeedback.selectionClick();
                                },
                                itemCount: neighbor.images.length,
                                itemBuilder: (context, index) {
                                  final path = neighbor.images[index];
                                  final url = path.startsWith('http')
                                      ? path
                                      : '$imageBaseUrl$path';
                                  return Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        _imagePlaceholder(theme, isDark),
                                  );
                                },
                              ),
                              // Dots
                              if (neighbor.images.length > 1)
                                Positioned(
                                  bottom: 24,
                                  left: 0,
                                  right: 0,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(
                                      neighbor.images.length,
                                      (i) {
                                        final isActive = i == _currentImage;
                                        return AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 3,
                                          ),
                                          width: isActive ? 18 : 7,
                                          height: 7,
                                          decoration: BoxDecoration(
                                            color: isActive
                                                ? Colors.white
                                                : Colors.white.withValues(
                                                    alpha: 0.5,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.2,
                                                ),
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        )
                      : Container(
                          color: isDark
                              ? AppColors.darkSand.withValues(alpha: 0.4)
                              : AppColors.sand.withValues(alpha: 0.4),
                          child: Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 48,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.25,
                              ),
                            ),
                          ),
                        ),
                ),
              ),

              // ─── Content ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              neighbor.skill,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.6,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          AvailabilityBadge(available: neighbor.available),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Owner card
                      _OwnerCard(
                        name: neighbor.name,
                        avatarColor: avatarColor,
                        initial: neighbor.initial,
                        metaParts: metaParts,
                      ),

                      // Description
                      if (neighbor.blurb.trim().isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          'About this skill',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          neighbor.blurb,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.75,
                            ),
                            fontSize: 14.5,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ─── Sticky CTA at bottom ───
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: neighbor.available ? widget.onRequest : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: neighbor.available
                        ? AppColors.terracotta
                        : (isDark ? AppColors.darkSand : AppColors.sand),
                    foregroundColor: neighbor.available
                        ? Colors.white
                        : (isDark
                              ? AppColors.darkInkFaint
                              : AppColors.inkFaint),
                    disabledBackgroundColor: isDark
                        ? AppColors.darkSand.withValues(alpha: 0.6)
                        : AppColors.sand.withValues(alpha: 0.6),
                    disabledForegroundColor: isDark
                        ? AppColors.darkInkFaint
                        : AppColors.inkFaint,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  icon: Icon(
                    neighbor.available
                        ? Icons.handshake_outlined
                        : Icons.schedule_rounded,
                    size: 18,
                  ),
                  label: Text(
                    neighbor.available ? 'Ask for help' : 'Currently busy',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder(ThemeData theme, bool isDark) {
    return Container(
      color: isDark
          ? AppColors.darkSand.withValues(alpha: 0.4)
          : AppColors.sand.withValues(alpha: 0.4),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 48,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}

class _OwnerCard extends StatelessWidget {
  const _OwnerCard({
    required this.name,
    required this.avatarColor,
    required this.initial,
    required this.metaParts,
  });

  final String name;
  final Color avatarColor;
  final String initial;
  final List<String> metaParts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkPaper.withValues(alpha: 0.6)
            : AppColors.paper.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.8),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: avatarColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? AppColors.darkBorder.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.7),
                width: 1,
              ),
            ),
            child: Text(
              initial,
              style: TextStyle(
                color: avatarColor,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  metaParts.join(' · '),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 22,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }
}
