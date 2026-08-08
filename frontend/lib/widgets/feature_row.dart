import 'package:flutter/material.dart';
import '../theme/colors.dart';

class FeatureRow extends StatelessWidget {
  const FeatureRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    // Removed hardcoded bottom padding; let the parent (IntroPage) handle layout spacing
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Softer, more organic icon container that interacts with the frosted glass behind it
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // Translucent base so the liquid glass effect shows through slightly
            color: tint.withOpacity(0.85),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withOpacity(0.9),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: tint.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.terracottaDeep, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            // Optical alignment: text baseline sits slightly lower than the visual center of a square
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600, // Slightly softer, more human weight than 700
                    fontSize: 15.5,
                    letterSpacing: -0.2, // Tighter tracking for an editorial feel
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.inkSoft.withOpacity(0.8),
                    fontSize: 13.5,
                    height: 1.45, // Relaxed line height for comfortable, warm reading
                    letterSpacing: 0.1,
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