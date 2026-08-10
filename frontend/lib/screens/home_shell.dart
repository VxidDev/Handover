import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'profile_tab.dart';
import 'requests_tab.dart';
import 'search_tab.dart';
import '../theme/colors.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with SingleTickerProviderStateMixin {
  int _index = 0;
  
  late final AnimationController _controller;
  
  // Content animations
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;
  
  // Nav bar animations
  late final Animation<Offset> _navSlide;
  late final Animation<double> _navFade;
  
  // Orange pill entrance animations
  late final Animation<double> _pillScale;
  late final Animation<double> _pillFade;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _contentFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _navSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
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

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          Positioned.fill(
            child: _AnimatedTabStack(
              index: _index,
              children: [
                const SearchTab(),
                RequestsTab(isActive: _index == 1),
                const ProfileTab(),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: bottomSafe + 18,
            child: SlideTransition(
              position: _navSlide,
              child: FadeTransition(
                opacity: _navFade,
                child: SizedBox(
                  height: 74,
                  child: _FloatingNavBar(
                    index: _index,
                    onTap: _selectTab,
                    pillScale: _pillScale,
                    pillFade: _pillFade,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedTabStack extends StatelessWidget {
  const _AnimatedTabStack({
    required this.index,
    required this.children,
  });

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
    required this.pillScale,
    required this.pillFade,
  });

  final int index;
  final ValueChanged<int> onTap;
  final Animation<double> pillScale;
  final Animation<double> pillFade;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.76),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.inkSoft.withValues(alpha: 0.07),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / 3;

              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutQuart,
                    left: index * itemWidth,
                    width: itemWidth,
                    top: 0,
                    bottom: 0,
                    child: FadeTransition(
                      opacity: pillFade,
                      child: ScaleTransition(
                        scale: pillScale,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: AppColors.terracotta.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                      ),
                    ),
                  ),

                  Positioned.fill(
                    child: Row(
                      children: [
                        _NavItem(
                          icon: Icons.search_rounded,
                          selectedIcon: Icons.search_rounded,
                          label: 'Find help',
                          isSelected: index == 0,
                          onTap: () => onTap(0),
                        ),
                        _NavItem(
                          icon: Icons.handshake_outlined,
                          selectedIcon: Icons.handshake_rounded,
                          label: 'Requests',
                          isSelected: index == 1,
                          onTap: () => onTap(1),
                        ),
                        _NavItem(
                          icon: Icons.person_outline_rounded,
                          selectedIcon: Icons.person_rounded,
                          label: 'My skills',
                          isSelected: index == 2,
                          onTap: () => onTap(2),
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
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          color: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                size: 22,
                color: isSelected
                    ? AppColors.terracotta
                    : AppColors.inkSoft.withValues(alpha: 0.55),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutQuart,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: 0.1,
                  color: isSelected
                      ? AppColors.terracotta
                      : AppColors.inkSoft.withValues(alpha: 0.55),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}