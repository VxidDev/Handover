import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/neighbor_skill.dart';
import '../services/api.dart';
import '../theme/colors.dart';
import '../widgets/availability_badge.dart';
import '../widgets/image_viewer.dart';
import '../widgets/report_user_sheet.dart';
import '../widgets/tip_sheet.dart';

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

  void _reportUser() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportUserSheet(userId: widget.neighbor.ownerId),
    );
  }

  Future<void> _blockUser() async {
    final name = widget.neighbor.name.split(' ').first;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: isDark
          ? Colors.black.withValues(alpha: 0.6)
          : AppColors.ink.withValues(alpha: 0.4),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkPaper : AppColors.paper,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? AppColors.darkBorder.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.8),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.block_rounded,
                  color: AppColors.error,
                  size: 26,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Block $name?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$name won\'t be able to send you messages or see your skills. '
                'This won\'t notify them.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder.withValues(alpha: 0.6)
                                : AppColors.inkSoft.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Center(
                          child: Text(
                            'Block',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await Api.post(
        '/api/safety/block',
        body: {'blocked_id': widget.neighbor.ownerId},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name has been blocked.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeError(e))),
        );
      }
    }
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
                      width: 48,
                      height: 48,
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
                actions: [
                  if (widget.neighbor.ownerId != Api.currentUserId)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'report') _reportUser();
                          if (value == 'block') _blockUser();
                        },
                        icon: Container(
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
                            Icons.more_vert_rounded,
                            size: 18,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'report',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.flag_outlined,
                                  size: 18,
                                  color: AppColors.error,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Report user',
                                  style: TextStyle(color: AppColors.error),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'block',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.block,
                                  size: 18,
                                  color: AppColors.error,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Block user',
                                  style: TextStyle(color: AppColors.error),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
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
                        profileImage: neighbor.ownerProfileImage,
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
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => showTipSheet(context, recipientId: neighbor.ownerId, recipientName: neighbor.name),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.terracottaDeep,
                      side: const BorderSide(color: AppColors.terracotta, width: 1.2),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    icon: const Icon(Icons.favorite_rounded, size: 16),
                    label: const Text('Tip'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: neighbor.available ? widget.onRequest : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: neighbor.available
                            ? AppColors.terracotta
                            : (isDark ? AppColors.darkSand : AppColors.sand),
                        foregroundColor: neighbor.available
                            ? Colors.white
                            : (isDark ? AppColors.darkInkFaint : AppColors.inkFaint),
                        disabledBackgroundColor: isDark
                            ? AppColors.darkSand.withValues(alpha: 0.6)
                            : AppColors.sand.withValues(alpha: 0.6),
                        disabledForegroundColor: isDark ? AppColors.darkInkFaint : AppColors.inkFaint,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      icon: Icon(neighbor.available ? Icons.handshake_outlined : Icons.schedule_rounded, size: 18),
                      label: Text(neighbor.available ? 'Ask for help' : 'Currently busy'),
                    ),
                  ),
                ],
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
    this.profileImage,
  });

  final String name;
  final Color avatarColor;
  final String initial;
  final List<String> metaParts;
  final String? profileImage;

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
            child: profileImage != null
                ? ClipOval(
                    child: Image.network(
                      '${Api.baseUrl}$profileImage',
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Text(
                        initial,
                        style: TextStyle(
                          color: avatarColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  )
                : Text(
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
