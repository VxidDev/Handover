// home_shell.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'profile_tab.dart';
import 'requests_tab.dart';
import 'search_tab.dart';
import 'messages_tab.dart';
import 'create_post_sheet.dart';
import '../theme/colors.dart';
import '../widgets/connectivity_banner.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;

  late final AnimationController _controller;

  late final Animation<Offset> _navSlide;
  late final Animation<double> _navFade;
  late final Animation<double> _pillScale;
  late final Animation<double> _pillFade;
  late final Animation<double> _plusScale;
  late final Animation<double> _plusFade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _navSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.25, 0.85, curve: Curves.easeOutQuart),
          ),
        );
    _navFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.65, curve: Curves.easeOut),
    );

    _pillScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.95, curve: Curves.easeOutBack),
      ),
    );
    _pillFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.75, curve: Curves.easeOut),
    );

    _plusScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.8, curve: Curves.easeOutBack),
      ),
    );
    _plusFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.6, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (_index == index) return;
    HapticFeedback.lightImpact();
    setState(() => _index = index);
  }

  void _openCreatePost() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreatePostSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: ConnectivityBanner(
        child: Stack(
          children: [
            Positioned.fill(
              child: _AnimatedTabStack(
                index: _index,
                children: [
                  const SearchTab(),
                  RequestsTab(isActive: _index == 1),
                  MessagesTab(isActive: _index == 2),
                  const ProfileTab(),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: bottomSafe + 16,
              child: SlideTransition(
                position: _navSlide,
                child: FadeTransition(
                  opacity: _navFade,
                  child: SizedBox(
                    height: 68,
                    child: _FloatingNavBar(
                      index: _index,
                      onTap: _selectTab,
                      onPlus: _openCreatePost,
                      pillScale: _pillScale,
                      pillFade: _pillFade,
                      plusScale: _plusScale,
                      plusFade: _plusFade,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedTabStack extends StatelessWidget {
  const _AnimatedTabStack({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 360);
    const curve = Curves.easeOutQuart;

    return Stack(
      fit: StackFit.expand,
      children: [
        for (int i = 0; i < children.length; i++)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: i != index,
              child: ExcludeSemantics(
                excluding: i != index,
                child: AnimatedOpacity(
                  opacity: i == index ? 1 : 0,
                  duration: duration,
                  curve: curve,
                  child: AnimatedSlide(
                    offset: i == index
                        ? Offset.zero
                        : Offset(i < index ? -0.03 : 0.03, 0),
                    duration: duration,
                    curve: curve,
                    child: children[i],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.index,
    required this.onTap,
    required this.onPlus,
    required this.pillScale,
    required this.pillFade,
    required this.plusScale,
    required this.plusFade,
  });

  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onPlus;
  final Animation<double> pillScale;
  final Animation<double> pillFade;
  final Animation<double> plusScale;
  final Animation<double> plusFade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final navGlassColor = isDark
        ? AppColors.darkPaper.withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.76);

    final navBorder = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.9);

    final navShadow = isDark
        ? Colors.black.withValues(alpha: 0.25)
        : AppColors.inkSoft.withValues(alpha: 0.07);

    final pillColor = isDark
        ? AppColors.terracotta.withValues(alpha: 0.2)
        : AppColors.terracotta.withValues(alpha: 0.14);

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: navGlassColor,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: navBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: navShadow,
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 5 equal slots: 4 tabs + 1 center button
              final itemWidth = constraints.maxWidth / 5;

              // Pill skips center slot (index 2)
              final pillLeft = index == 0
                  ? 0.0
                  : index == 1
                  ? itemWidth
                  : index == 2
                  ? itemWidth * 3
                  : itemWidth * 4;

              return Stack(
                children: [
                  // Animated pill
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutQuart,
                    left: pillLeft,
                    width: itemWidth,
                    top: 0,
                    bottom: 0,
                    child: FadeTransition(
                      opacity: pillFade,
                      child: ScaleTransition(
                        scale: pillScale,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: pillColor,
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // All 5 slots in a row
                  Positioned.fill(
                    child: Row(
                      children: [
                        SizedBox(
                          width: itemWidth,
                          child: _NavItem(
                            icon: Icons.search_rounded,
                            selectedIcon: Icons.search_rounded,
                            label: 'Search',
                            isSelected: index == 0,
                            onTap: () => onTap(0),
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _NavItem(
                            icon: Icons.handshake_outlined,
                            selectedIcon: Icons.handshake_rounded,
                            label: 'Requests',
                            isSelected: index == 1,
                            onTap: () => onTap(1),
                          ),
                        ),
                        // Center plus button
                        SizedBox(
                          width: itemWidth,
                          child: Center(
                            child: FadeTransition(
                              opacity: plusFade,
                              child: ScaleTransition(
                                scale: plusScale,
                                child: Semantics(
                                  button: true,
                                  label: 'Create new post',
                                  child: GestureDetector(
                                    onTap: onPlus,
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: AppColors.terracotta,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.terracotta
                                                .withValues(
                                                  alpha: isDark ? 0.4 : 0.3,
                                                ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.add_rounded,
                                        color: Colors.white,
                                        size: 26,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _NavItem(
                            icon: Icons.chat_bubble_outline_rounded,
                            selectedIcon: Icons.chat_bubble_rounded,
                            label: 'Chats',
                            isSelected: index == 2,
                            onTap: () => onTap(2),
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _NavItem(
                            icon: Icons.person_outline_rounded,
                            selectedIcon: Icons.person_rounded,
                            label: 'Profile',
                            isSelected: index == 3,
                            onTap: () => onTap(3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selectedColor = AppColors.terracotta;
    final unselectedColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
        : AppColors.inkSoft.withValues(alpha: 0.55);

    final currentColor = isSelected ? selectedColor : unselectedColor;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label tab',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          color: Colors.transparent,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Icon(
                  isSelected ? selectedIcon : icon,
                  key: ValueKey(isSelected),
                  size: 22,
                  color: currentColor,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutQuart,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: 0.1,
                  color: currentColor,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label, maxLines: 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
