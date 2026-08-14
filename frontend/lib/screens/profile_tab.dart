import 'package:flutter/material.dart';

import '../models/skill.dart';
import '../models/user_profile.dart';
import '../services/api.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import 'intro_page.dart';
import 'map_picker.dart';

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
  bool _savingLocation = false;
  final Set<int> _removingSkillIds = {};

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
      final res = await Api.patch(
        '/api/users/me',
        body: {'is_available': value},
      );

      if (!mounted) return;

      setState(() {
        _profile = UserProfile.fromJson(res as Map<String, dynamic>);
        _savingAvailability = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _savingAvailability = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeError(e))),
      );
    }
  }

  Future<void> _chooseLocation() async {
    final selection = await Navigator.of(context).push<GridSelection>(
      MaterialPageRoute(
        builder: (_) => LocationGridPickerPage(
          initialLat: Api.demoLat,
          initialLng: Api.demoLng,
        ),
      ),
    );

    if (selection == null || !mounted) return;

    setState(() => _savingLocation = true);

    try {
      final res = await Api.patch(
        '/api/users/me',
        body: {
          'grid': selection.cellId,
        },
      );

      if (!mounted) return;

      setState(() {
        _profile = UserProfile.fromJson(res as Map<String, dynamic>);
        _savingLocation = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your area has been updated.')),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _savingLocation = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeError(e))),
      );
    }
  }

  Future<void> _addSkill() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _AddSkillBottomSheet(),
    );

    if (result == null) return;

    final name = result['name']!.trim();
    final blurb = result['blurb']!.trim();

    if (name.isEmpty) return;

    try {
      await Api.post(
        '/api/users/me/skills',
        body: {'name': name, 'blurb': blurb},
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeError(e))),
      );
    }
  }

  Future<void> _deleteSkill(Skill skill) async {
    // Mark as removing to trigger exit animation
    setState(() => _removingSkillIds.add(skill.id));

    // Wait for exit animation to complete
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    try {
      await Api.delete('/api/users/me/skills/${skill.id}');

      if (mounted) {
        setState(() => _removingSkillIds.remove(skill.id));
      }

      await _load();
    } catch (e) {
      if (!mounted) return;

      // Remove from set — triggers smooth reverse animation
      setState(() => _removingSkillIds.remove(skill.id));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeError(e))),
      );
    }
  }

  void _confirmSignOut() {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: Text(
          'You\'ll need to sign back in to see nearby requests.',
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 13.5,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('My skill wallet')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
          children: _buildBody(),
        ),
      ),
    );
  }

  List<Widget> _buildBody() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? AppColors.darkPaper : AppColors.paper;
    final cardBorder = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.8);
    final cardShadow = isDark ? AppTheme.darkCardShadow : AppTheme.cardShadow;
    final avatarBg = isDark
        ? AppColors.terracotta.withValues(alpha: 0.18)
        : AppColors.terracottaTint;
    final avatarFg = isDark ? AppColors.terracotta : AppColors.terracottaDeep;
    final mutedText = theme.colorScheme.onSurface.withValues(alpha: 0.5);

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
              Icon(
                Icons.cloud_off_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
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
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorder, width: 1),
          boxShadow: cardShadow,
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: avatarBg,
                  child: Text(
                    p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: avatarFg,
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
                      color: p.isAvailable
                          ? AppColors.success
                          : (isDark ? AppColors.darkInkFaint : AppColors.inkFaint),
                      shape: BoxShape.circle,
                      border: Border.all(color: cardBg, width: 2.5),
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
                  Text(
                    p.name,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.place_outlined, size: 13, color: mutedText),
                      const SizedBox(width: 3),
                      Text(
                        p.grid ?? 'Near you',
                        style: TextStyle(fontSize: 12, color: mutedText),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.eco_outlined, size: 13, color: AppColors.sage),
                      const SizedBox(width: 3),
                      Text(
                        '${p.karma} karma',
                        style: TextStyle(fontSize: 12, color: mutedText),
                      ),
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
          color: p.isAvailable
              ? (isDark ? AppColors.sage.withValues(alpha: 0.18) : AppColors.sageLight)
              : (isDark ? AppColors.darkSand : AppColors.sand),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          p.isAvailable
              ? 'You\'re visible to neighbors searching nearby.'
              : 'You\'re hidden from search while marked busy.',
          style: TextStyle(
            fontSize: 12.5,
            color: p.isAvailable ? AppColors.sage : mutedText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      const SizedBox(height: 12),
      _locationCard(p),
      const SizedBox(height: 28),
      Text('Skills you offer', style: theme.textTheme.titleMedium),
      const SizedBox(height: 4),
      Text(
        'These show up when neighbors search for help.',
        style: TextStyle(fontSize: 12.5, color: mutedText),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in p.skills)
            _AnimatedSkillRemoval(
              key: ValueKey(s.id),
              isRemoving: _removingSkillIds.contains(s.id),
              child: Chip(
                label: Text(s.name),
                onDeleted: () => _deleteSkill(s),
                deleteIconColor: mutedText,
                backgroundColor: isDark ? AppColors.darkSand : AppColors.sand,
              ),
            ),
          ActionChip(
            avatar: Icon(Icons.add_rounded, size: 17, color: avatarFg),
            label: Text(
              'Add skill',
              style: TextStyle(
                color: avatarFg,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: avatarBg,
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

  Widget _locationCard(UserProfile p) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? AppColors.darkPaper : AppColors.paper;
    final cardBorder = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.8);
    final cardShadow = isDark ? AppTheme.darkCardShadow : AppTheme.cardShadow;
    final iconTileBg = isDark
        ? AppColors.terracotta.withValues(alpha: 0.18)
        : AppColors.terracottaTint;
    final iconFg = isDark ? AppColors.terracotta : AppColors.terracottaDeep;
    final mutedText = theme.colorScheme.onSurface.withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconTileBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.map_outlined,
                  size: 20,
                  color: iconFg,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Privacy area',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'You appear as a rough grid cell, not an exact address.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: mutedText,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSand : AppColors.sand,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 15,
                  color: mutedText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.grid ?? 'Not set yet',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _savingLocation ? null : _chooseLocation,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.terracotta,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              icon: _savingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.edit_location_alt_outlined, size: 18),
              label: Text(
                p.grid == null ? 'Choose on map' : 'Update on map',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedSkillRemoval extends StatefulWidget {
  const _AnimatedSkillRemoval({
    super.key,
    required this.isRemoving,
    required this.child,
  });

  final bool isRemoving;
  final Widget child;

  @override
  State<_AnimatedSkillRemoval> createState() => _AnimatedSkillRemovalState();
}

class _AnimatedSkillRemovalState extends State<_AnimatedSkillRemoval>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late final Animation<double> _widthFactor;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Opacity fades out in the first 65% — fast start, then graceful slow-down
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    // Scale shrinks subtly throughout the whole animation — "being absorbed" feel
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInCubic,
      ),
    );

    // Width collapse starts 50ms after fade begins, with smooth easeInOutQuart
    _widthFactor = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 1.0, curve: Curves.easeInOutQuart),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant _AnimatedSkillRemoval oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRemoving && !oldWidget.isRemoving) {
      _controller.forward();
    } else if (!widget.isRemoving && oldWidget.isRemoving) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // When idle, return the child directly for zero overhead
        if (_controller.value == 0.0 && !widget.isRemoving) {
          return child!;
        }

        // ClipRect prevents the scaled chip from overflowing as space shrinks
        return ClipRect(
          child: Align(
            // widthFactor drives the space collapse — Wrap reflows siblings smoothly
            widthFactor: _widthFactor.value,
            alignment: Alignment.centerLeft,
            child: Opacity(
              opacity: _opacity.value,
              child: Transform.scale(
                scale: _scale.value,
                alignment: Alignment.center,
                child: child,
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _AddSkillBottomSheet extends StatefulWidget {
  const _AddSkillBottomSheet();

  @override
  State<_AddSkillBottomSheet> createState() => _AddSkillBottomSheetState();
}

class _AddSkillBottomSheetState extends State<_AddSkillBottomSheet>
    with SingleTickerProviderStateMixin {
  final _name = TextEditingController();
  final _blurb = TextEditingController();
  bool _submitting = false;
  String? _error;

  late final AnimationController _successController;
  late final Animation<double> _successScale;
  late final Animation<double> _successOpacity;

  @override
  void initState() {
    super.initState();
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _successScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _successController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _successOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _successController.dispose();
    _name.dispose();
    _blurb.dispose();
    super.dispose();
  }

  void _submit() async {
    final name = _name.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Please enter a skill name.');
      return;
    }

    setState(() => _submitting = true);

    // Play success animation
    _successController.forward();

    // Wait for animation to play, then close
    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;

    Navigator.of(context).pop({
      'name': name,
      'blurb': _blurb.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    final dialogBg = isDark ? AppColors.darkPaper : AppColors.paper;
    final successColor = isDark ? AppColors.sage : AppColors.sage;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        decoration: BoxDecoration(
          color: dialogBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                Text(
                  'Add a skill',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Neighbors nearby will see this when they search for help.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Skill name field
                Text(
                  'SKILL NAME',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _name,
                  autofocus: true,
                  maxLength: 50,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Spanish Tutoring',
                    counterText: '',
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkSand.withValues(alpha: 0.5)
                        : AppColors.sand.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    errorText: _error,
                    errorStyle: TextStyle(fontSize: 12, color: AppColors.error),
                  ),
                ),
                const SizedBox(height: 16),

                // Blurb field
                Text(
                  'DESCRIPTION',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _blurb,
                  maxLines: 3,
                  maxLength: 200,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Tell neighbors what you can help with…',
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkSand.withValues(alpha: 0.5)
                        : AppColors.sand.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          side: BorderSide(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.terracotta,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: AnimatedBuilder(
                          animation: _successController,
                          builder: (context, child) {
                            if (_successController.value > 0.0) {
                              return FadeTransition(
                                opacity: _successOpacity,
                                child: ScaleTransition(
                                  scale: _successScale,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_rounded,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Added!',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            return child!;
                          },
                          child: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Add skill'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}