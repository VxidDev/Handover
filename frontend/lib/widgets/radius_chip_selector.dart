import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/colors.dart';

class RadiusChipSelector extends StatefulWidget {
  const RadiusChipSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.options = const [0.5, 1, 2, 3, 5],
  });

  final double value;
  final ValueChanged<double> onChanged;
  final List<double> options;

  @override
  State<RadiusChipSelector> createState() => _RadiusChipSelectorState();
}

class _RadiusChipSelectorState extends State<RadiusChipSelector> {
  final List<GlobalKey> _chipKeys = [];
  final GlobalKey _stackKey = GlobalKey();

  double? _indicatorLeft;
  double? _indicatorWidth;

  @override
  void initState() {
    super.initState();
    _syncKeys();
    _updateIndicator();
  }

  @override
  void didUpdateWidget(covariant RadiusChipSelector oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.value != widget.value ||
        oldWidget.options != widget.options) {
      _syncKeys();
      _updateIndicator();
    }
  }

  void _syncKeys() {
    while (_chipKeys.length < widget.options.length) {
      _chipKeys.add(GlobalKey());
    }

    while (_chipKeys.length > widget.options.length) {
      _chipKeys.removeLast();
    }
  }

  int get _selectedIndex {
    return widget.options.indexWhere(
      (option) => (option - widget.value).abs() < 0.0001,
    );
  }

  bool _closeTo(double? current, double next) {
    if (current == null) return false;
    return (current - next).abs() < 0.01;
  }

  void _updateIndicator() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final selectedIndex = _selectedIndex;

      if (selectedIndex < 0) {
        if (_indicatorLeft != null || _indicatorWidth != null) {
          setState(() {
            _indicatorLeft = null;
            _indicatorWidth = null;
          });
        }
        return;
      }

      final chipContext = _chipKeys[selectedIndex].currentContext;
      final stackContext = _stackKey.currentContext;

      if (chipContext == null || stackContext == null) return;

      final chipBox = chipContext.findRenderObject() as RenderBox?;
      final stackBox = stackContext.findRenderObject() as RenderBox?;

      if (chipBox == null || stackBox == null) return;

      final chipOffset = chipBox.localToGlobal(Offset.zero, ancestor: stackBox);

      final newLeft = chipOffset.dx;
      final newWidth = chipBox.size.width;

      if (!_closeTo(_indicatorLeft, newLeft) ||
          !_closeTo(_indicatorWidth, newWidth)) {
        setState(() {
          _indicatorLeft = newLeft;
          _indicatorWidth = newWidth;
        });
      }
    });
  }

  String _label(double option) {
    if (option < 1) {
      return '${(option * 1000).round()} m';
    }

    if (option == option.roundToDouble()) {
      return '${option.toInt()} km';
    }

    return '${option.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex;

    return SizedBox(
      height: 38,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        child: Stack(
          key: _stackKey,
          alignment: Alignment.center,
          children: [
            if (_indicatorLeft != null && _indicatorWidth != null)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeOutExpo,
                left: _indicatorLeft!,
                width: _indicatorWidth!,
                top: 1,
                bottom: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.terracotta.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: AppColors.terracotta.withValues(alpha: 0.32),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.terracotta.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < widget.options.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    selected: i == selectedIndex,
                    label: _label(widget.options[i]),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        final option = widget.options[i];

                        if (option != widget.value) {
                          HapticFeedback.selectionClick();
                          widget.onChanged(option);
                        }
                      },
                      child: Container(
                        key: _chipKeys[i],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        color: Colors.transparent,
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutExpo,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
                            color: i == selectedIndex
                                ? AppColors.terracottaDeep
                                : AppColors.inkSoft.withValues(alpha: 0.9),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(_label(widget.options[i])),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
