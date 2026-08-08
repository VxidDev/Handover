import 'package:flutter/material.dart';
import '../models/skill.dart';
import '../models/user_profile.dart';
import '../services/api.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import 'intro_page.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  UserProfile? _profile;
  bool _loading = true;
  String? _error;
  bool _savingAvailability = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Api.get('/api/users/me');
      final profile = UserProfile.fromJson(res as Map<String, dynamic>);
      Api.currentUserId = profile.id;
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = describeError(e);
        _loading = false;
      });
    }
  }

  Future<void> _toggleAvailability(bool value) async {
    setState(() => _savingAvailability = true);
    try {
      final res = await Api.patch('/api/users/me', body: {'is_available': value});
      if (!mounted) return;
      setState(() {
        _profile = UserProfile.fromJson(res as Map<String, dynamic>);
        _savingAvailability = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingAvailability = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  Future<void> _addSkill() async {
    final controller = TextEditingController();
    final blurb = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a skill'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'e.g. Spanish Tutoring'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: blurb,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Short description (optional)'),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    final skillName = name?.trim() ?? '';
    if (skillName.isEmpty) return;
    try {
      await Api.post('/api/users/me/skills', body: {'name': skillName, 'blurb': blurb.text.trim()});
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  Future<void> _deleteSkill(Skill skill) async {
    try {
      await Api.delete('/api/users/me/skills/${skill.id}');
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
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
            onPressed: () async {
              await Api.clearSession();
              if (!mounted) return;
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
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: _buildBody(),
        ),
      ),
    );
  }

  List<Widget> _buildBody() {
    if (_loading && _profile == null) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 70),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_error != null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_rounded, color: AppColors.inkFaint, size: 40),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ];
    }

    final p = _profile!;
    return [
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
                  child: Text(
                    p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                    style: const TextStyle(
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
                      color: p.isAvailable ? AppColors.success : AppColors.inkFaint,
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
                  Text(p.name,
                      style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 13, color: AppColors.inkFaint),
                      const SizedBox(width: 3),
                      Text(p.grid ?? 'Near you',
                          style: const TextStyle(fontSize: 12, color: AppColors.inkFaint)),
                      const SizedBox(width: 10),
                      const Icon(Icons.eco_outlined, size: 13, color: AppColors.sage),
                      const SizedBox(width: 3),
                      Text('${p.karma} karma',
                          style: const TextStyle(fontSize: 12, color: AppColors.inkFaint)),
                    ],
                  ),
                ],
              ),
            ),
            _savingAvailability
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Switch(
                    value: p.isAvailable,
                    onChanged: _toggleAvailability,
                  ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: p.isAvailable ? AppColors.sageLight : AppColors.sand,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          p.isAvailable
              ? 'You\'re visible to neighbors searching nearby.'
              : 'You\'re hidden from search while marked busy.',
          style: TextStyle(
            fontSize: 12.5,
            color: p.isAvailable ? AppColors.sage : AppColors.inkFaint,
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
          for (final s in p.skills)
            Chip(
              label: Text(s.name),
              onDeleted: () => _deleteSkill(s),
              deleteIconColor: AppColors.inkFaint,
              backgroundColor: AppColors.sand,
            ),
          ActionChip(
            avatar: const Icon(Icons.add_rounded, size: 17, color: AppColors.terracottaDeep),
            label: const Text('Add skill',
                style: TextStyle(color: AppColors.terracottaDeep, fontWeight: FontWeight.w600)),
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
    ];
  }
}