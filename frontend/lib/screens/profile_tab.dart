import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import 'intro_page.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _skills = ['Plumbing', 'Bike Repair'];
  bool _available = true;

  void _addSkill() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a skill'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Spanish Tutoring'),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final s = controller.text.trim();
              if (s.isNotEmpty) setState(() => _skills.add(s));
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You\'ll need to sign back in to see nearby requests.',
          style: TextStyle(color: AppColors.inkSoft, fontSize: 13.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const IntroPage()),
                (_) => false,
              );
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('My skill wallet')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.terracottaTint,
                      child: const Text(
                        'A',
                        style: TextStyle(
                          color: AppColors.terracottaDeep,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _available ? AppColors.success : AppColors.inkFaint,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.paper, width: 2.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Alex', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 13, color: AppColors.inkFaint),
                          const SizedBox(width: 3),
                          const Text('Grid D4', style: TextStyle(fontSize: 12, color: AppColors.inkFaint)),
                          const SizedBox(width: 10),
                          const Icon(Icons.eco_outlined, size: 13, color: AppColors.sage),
                          const SizedBox(width: 3),
                          const Text('12 karma', style: TextStyle(fontSize: 12, color: AppColors.inkFaint)),
                        ],
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _available,
                  onChanged: (v) => setState(() => _available = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _available ? AppColors.sageLight : AppColors.sand,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _available
                  ? 'You\'re visible to neighbors searching nearby.'
                  : 'You\'re hidden from search while marked busy.',
              style: TextStyle(
                fontSize: 12.5,
                color: _available ? AppColors.sage : AppColors.inkFaint,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text('Skills you offer', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'These show up when neighbors search for help.',
            style: TextStyle(fontSize: 12.5, color: AppColors.inkFaint),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _skills)
                Chip(
                  label: Text(s),
                  onDeleted: () => setState(() => _skills.remove(s)),
                  deleteIconColor: AppColors.inkFaint,
                  backgroundColor: AppColors.sand,
                ),
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 17, color: AppColors.terracottaDeep),
                label: const Text('Add skill', style: TextStyle(color: AppColors.terracottaDeep, fontWeight: FontWeight.w600)),
                backgroundColor: AppColors.terracottaTint,
                onPressed: _addSkill,
              ),
            ],
          ),
          const SizedBox(height: 36),
          OutlinedButton(
            onPressed: _confirmSignOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}