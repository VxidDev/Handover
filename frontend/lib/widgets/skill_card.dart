import 'package:flutter/material.dart';
import '../models/neighbor_skill.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import 'availability_badge.dart';

class SkillCard extends StatelessWidget {
  const SkillCard({super.key, required this.neighbor, this.onRequest});

  final NeighborSkill neighbor;
  final VoidCallback? onRequest;

  @override
  Widget build(BuildContext context) {
    final avatarColor = AppColors.avatarFor(neighbor.name);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: avatarColor.withValues(alpha: 0.18),
                child: Text(
                  neighbor.initial,
                  style: TextStyle(color: avatarColor, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(neighbor.skill, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${neighbor.name} · ≈${neighbor.km?.toStringAsFixed(1) ?? '?'} km · ${neighbor.grid ?? 'nearby'}',
                      style: const TextStyle(fontSize: 12, color: AppColors.inkFaint),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AvailabilityBadge(available: neighbor.available),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            neighbor.blurb,
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: neighbor.available ? (onRequest ?? () {}) : null,
              style: FilledButton.styleFrom(
                backgroundColor: neighbor.available ? AppColors.terracotta : AppColors.sand,
                foregroundColor: neighbor.available ? Colors.white : AppColors.inkFaint,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
              icon: const Icon(Icons.handshake_outlined, size: 18),
              label: Text(neighbor.available ? 'Ask for help' : 'Currently busy'),
            ),
          ),
        ],
      ),
    );
  }
}