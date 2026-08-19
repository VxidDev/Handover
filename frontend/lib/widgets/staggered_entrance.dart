import 'package:flutter/material.dart';

/// Wraps a page or section to provide a shared AnimationController
/// for staggered entrance animations.
class StaggeredEntrance extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const StaggeredEntrance({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _StaggeredScope(controller: _controller, child: widget.child);
  }
}

class _StaggeredScope extends InheritedWidget {
  final AnimationController controller;
  const _StaggeredScope({required this.controller, required super.child});

  static AnimationController of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_StaggeredScope>()!
        .controller;
  }

  @override
  bool updateShouldNotify(_StaggeredScope oldWidget) => false;
}

/// Wraps an individual element to give it a staggered fade + slide entrance.
class StaggeredItem extends StatelessWidget {
  final Widget child;
  final int index;
  final Offset begin;

  const StaggeredItem({
    super.key,
    required this.child,
    required this.index,
    this.begin = const Offset(0, 0.12),
  });

  @override
  Widget build(BuildContext context) {
    final controller = _StaggeredScope.of(context);

    // Mimics the exact interval logic from your IntroPage
    final step = 0.10;
    final start = (index * step).clamp(0.0, 0.8);
    final end = (start + 0.45).clamp(0.0, 1.0);

    final fade = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutExpo),
    );

    final slide = Tween<Offset>(begin: begin, end: Offset.zero).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(start, end, curve: Curves.easeOutExpo),
      ),
    );

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
}
