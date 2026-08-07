import 'package:flutter/material.dart';
import '../theme/colors.dart';

class AvailabilityBadge extends StatelessWidget {
  const AvailabilityBadge({super.key, required this.available});

  final bool available;

  @override
  Widget build(BuildContext context) {
    final color = available ? AppColors.success : AppColors.inkFaint;
    final bg = available ? AppColors.sageLight : AppColors.sand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            available ? 'Available' : 'Busy',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: available ? AppColors.terracottaDeep : AppColors.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}