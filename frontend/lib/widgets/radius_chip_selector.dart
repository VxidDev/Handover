import 'package:flutter/material.dart';
import '../theme/colors.dart';

class RadiusChipSelector extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final option = options[i];
          final selected = option == value;
          return ChoiceChip(
            label: Text(
              option < 1 ? '${(option * 1000).round()} m' : '${option.toStringAsFixed(0)} km',
            ),
            selected: selected,
            onSelected: (_) => onChanged(option),
            selectedColor: AppColors.terracotta,
            backgroundColor: AppColors.sand,
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppColors.inkSoft,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12.5,
            ),
            side: BorderSide.none,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          );
        },
      ),
    );
  }
}