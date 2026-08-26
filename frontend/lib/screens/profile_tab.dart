import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import '../models/skill.dart';
import '../models/user_profile.dart';
import '../services/api.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import 'settings_page.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  UserProfile? _profile;
  bool _loading = true;
  String? _error;
  final Set<int> _removingSkillIds = {};
  bool _uploadingImage = false;

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

  Future<void> _deleteSkill(Skill skill) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: isDark
          ? Colors.black.withValues(alpha: 0.6)
          : AppColors.ink.withValues(alpha: 0.4),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkPaper : AppColors.paper,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? AppColors.darkBorder.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.8),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                  size: 24,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Delete "${skill.name}"?',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This skill will be removed from your profile and neighbors won\'t see it anymore.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        side: BorderSide(
                          color: isDark
                              ? AppColors.darkBorder.withValues(alpha: 0.6)
                              : AppColors.inkSoft.withValues(alpha: 0.15),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _removingSkillIds.add(skill.id));
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
      setState(() => _removingSkillIds.remove(skill.id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  void _openSettings() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (image == null || !mounted) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: AppColors.terracotta,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppColors.terracotta,
          cropStyle: CropStyle.circle,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop Photo',
          cropStyle: CropStyle.circle,
          aspectRatioLockEnabled: true,
          aspectRatioPickerButtonHidden: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );
    if (croppedFile == null || !mounted) return;

    setState(() => _uploadingImage = true);
    try {
      final res = await Api.uploadFile('/api/uploads/images', File(croppedFile.path));
      final path = res['path'] as String;
      final updateRes = await Api.patch(
        '/api/users/me',
        body: {'profile_image': path},
      );
      if (!mounted) return;
      final profile = UserProfile.fromJson(updateRes as Map<String, dynamic>);
      setState(() {
        _profile = profile;
        _uploadingImage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingImage = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  Future<void> _removeProfileImage() async {
    setState(() => _uploadingImage = true);
    try {
      final res = await Api.patch(
        '/api/users/me',
        body: {'profile_image': null},
      );
      if (!mounted) return;
      final profile = UserProfile.fromJson(res as Map<String, dynamic>);
      setState(() {
        _profile = profile;
        _uploadingImage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingImage = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  void _showImageOptions() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkPaper : AppColors.paper,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? AppColors.darkBorder.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.9),
            width: 1,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickProfileImage();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                ),
                title: Text(
                  'Remove photo',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final removeConfirmed = await showDialog<bool>(
                    context: context,
                    barrierColor: isDark
                        ? Colors.black.withValues(alpha: 0.6)
                        : AppColors.ink.withValues(alpha: 0.4),
                    builder: (dCtx) => Dialog(
                      backgroundColor: Colors.transparent,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 340),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkPaper : AppColors.paper,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.error,
                              size: 28,
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Remove profile photo?',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.pop(dCtx, false),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () => Navigator.pop(dCtx, true),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.error,
                                    ),
                                    child: const Text('Remove'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                  if (removeConfirmed == true) _removeProfileImage();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        color: AppColors.terracotta,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _buildContent(context),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 130)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedText = theme.colorScheme.onSurface.withValues(alpha: 0.55);

    if (_loading && _profile == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 120),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppColors.terracotta,
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSand : AppColors.sand,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? AppColors.darkBorder.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.8),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Couldn\'t load profile',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: mutedText, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final p = _profile!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeroCard(
          profile: p,
          onSettings: _openSettings,
          onPickImage: _pickProfileImage,
          onRemoveImage: _removeProfileImage,
          onShowImageOptions: _showImageOptions,
          uploadingImage: _uploadingImage,
        ),
        const SizedBox(height: 16),
        _StatsRow(profile: p),
        const SizedBox(height: 28),
        _SectionHeader(
          title: 'Your skills',
          subtitle: 'Skills you\'ve offered to help neighbors with.',
          action: _SkillsCount(count: p.skills.length),
        ),
        const SizedBox(height: 10),
        _SkillsSection(
          skills: p.skills,
          removingSkillIds: _removingSkillIds,
          onDelete: _deleteSkill,
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.profile,
    required this.onSettings,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onShowImageOptions,
    required this.uploadingImage,
  });

  final UserProfile profile;
  final VoidCallback onSettings;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final VoidCallback onShowImageOptions;
  final bool uploadingImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final avatarColor = AppColors.avatarFor(profile.name, isDark: isDark);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkPaper : AppColors.paper,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? AppColors.darkBorder.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.9),
            width: 1,
          ),
          boxShadow: isDark
              ? AppTheme.darkCardShadow
              : [
                  BoxShadow(
                    color: AppColors.inkSoft.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PROFILE',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
                _SettingsButton(onTap: onSettings),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                GestureDetector(
                  onTap: uploadingImage ? null : onPickImage,
                  onLongPress: profile.profileImage != null
                      ? () => onShowImageOptions()
                      : null,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: avatarColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder.withValues(alpha: 0.4)
                                : Colors.white.withValues(alpha: 0.9),
                            width: 2,
                          ),
                        ),
                        child: uploadingImage
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: avatarColor,
                                ),
                              )
                            : profile.profileImage != null
                                ? ClipOval(
                                    child: Image.network(
                                      '${Api.baseUrl}${profile.profileImage}',
                                      width: 52,
                                      height: 52,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Text(
                                        profile.name.isNotEmpty
                                            ? profile.name[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          color: avatarColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 22,
                                        ),
                                      ),
                                    ),
                                  )
                                : Text(
                                    profile.name.isNotEmpty
                                        ? profile.name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: avatarColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 22,
                                    ),
                                  ),
                      ),
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: profile.isAvailable
                                ? AppColors.success
                                : (isDark
                                      ? AppColors.darkInkFaint
                                      : AppColors.inkFaint),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkPaper
                                  : AppColors.paper,
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                      if (!uploadingImage)
                        Positioned(
                          right: -14,
                          top: -14,
                          child: Semantics(
                            button: true,
                            label: profile.profileImage != null
                                ? 'Edit profile photo'
                                : 'Add profile photo',
                            child: GestureDetector(
                              onTap: onPickImage,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                ),
                                child: Align(
                                  alignment: Alignment.bottomRight,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: AppColors.terracotta,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark
                                            ? AppColors.darkPaper
                                            : AppColors.paper,
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      profile.profileImage != null
                                          ? Icons.edit_rounded
                                          : Icons.camera_alt_rounded,
                                      size: 10,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          letterSpacing: -0.3,
                          height: 1.15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        profile.email,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.55,
                          ),
                          fontSize: 12.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (profile.phone != null &&
                          profile.phone!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          profile.phone!,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.55,
                            ),
                            fontSize: 12.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: profile.isAvailable
                    ? (isDark
                          ? AppColors.sage.withValues(alpha: 0.15)
                          : AppColors.sageLight)
                    : (isDark
                          ? AppColors.darkSand.withValues(alpha: 0.5)
                          : AppColors.sand.withValues(alpha: 0.7)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    profile.isAvailable
                        ? Icons.check_circle_outline_rounded
                        : Icons.pause_circle_outline_rounded,
                    size: 16,
                    color: profile.isAvailable
                        ? AppColors.sage
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 12.5,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        children: [
                          TextSpan(
                            text: profile.isAvailable
                                ? 'Available to help'
                                : 'Busy',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text: profile.isAvailable
                                ? '  ·  Visible in nearby searches'
                                : '  ·  Hidden from searches',
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsButton extends StatefulWidget {
  const _SettingsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_SettingsButton> createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<_SettingsButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _rotationAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
    setState(() => _isPressed = true);
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    setState(() => _isPressed = false);
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSand.withValues(
                        alpha: _isPressed ? 1.0 : 0.6,
                      )
                    : AppColors.sand.withValues(alpha: _isPressed ? 1.0 : 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkBorder.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.8),
                  width: 1,
                ),
              ),
              child: Transform.rotate(
                angle: _rotationAnimation.value * 3.14159,
                child: Icon(
                  Icons.settings_rounded,
                  size: 20,
                  color: _isPressed
                      ? AppColors.terracotta
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkPaper : AppColors.paper,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? AppColors.darkBorder.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.8),
            width: 1,
          ),
          boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            _StatTile(
              icon: Icons.eco_outlined,
              iconColor: AppColors.sage,
              label: 'Karma',
              value: '${profile.karma}',
            ),
            _VerticalDivider(isDark: isDark),
            _StatTile(
              icon: Icons.stars_rounded,
              iconColor: AppColors.terracotta,
              label: 'Skills',
              value: '${profile.skills.length}',
            ),
            _VerticalDivider(isDark: isDark),
            _StatTile(
              icon: Icons.calendar_today_rounded,
              iconColor: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              label: 'Joined',
              value: _formatJoinDate(profile.createdAt),
            ),
          ],
        ),
      ),
    );
  }

  String _formatJoinDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays < 1) return 'Today';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: isDark
          ? AppColors.darkBorder.withValues(alpha: 0.4)
          : AppColors.inkSoft.withValues(alpha: 0.08),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle, this.action});

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  fontSize: 16,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: 12), action!],
      ],
    );
  }
}

class _SkillsCount extends StatelessWidget {
  const _SkillsCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSand : AppColors.sand,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}

class _SkillsSection extends StatelessWidget {
  const _SkillsSection({
    required this.skills,
    required this.removingSkillIds,
    required this.onDelete,
  });

  final List<Skill> skills;
  final Set<int> removingSkillIds;
  final ValueChanged<Skill> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? AppColors.darkPaper : AppColors.paper;
    final cardBorder = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.5)
        : Colors.white.withValues(alpha: 0.8);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: skills.isEmpty
          ? Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cardBorder, width: 1),
                boxShadow: isDark
                    ? AppTheme.darkCardShadow
                    : AppTheme.cardShadow,
              ),
              child: const _EmptySkillsState(),
            )
          : Column(
              children: [
                for (final skill in skills)
                  _AnimatedSkillCard(
                    key: ValueKey(skill.id),
                    isRemoving: removingSkillIds.contains(skill.id),
                    skill: skill,
                    onDelete: () => onDelete(skill),
                  ),
              ],
            ),
    );
  }
}

class _AnimatedSkillCard extends StatefulWidget {
  const _AnimatedSkillCard({
    super.key,
    required this.isRemoving,
    required this.skill,
    required this.onDelete,
  });

  final bool isRemoving;
  final Skill skill;
  final VoidCallback onDelete;

  @override
  State<_AnimatedSkillCard> createState() => _AnimatedSkillCardState();
}

class _AnimatedSkillCardState extends State<_AnimatedSkillCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    _heightFactor = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeInOutQuart),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant _AnimatedSkillCard oldWidget) {
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
        if (_controller.value == 0.0 && !widget.isRemoving) {
          return child!;
        }
        return ClipRect(
          child: Align(
            heightFactor: _heightFactor.value,
            alignment: Alignment.topCenter,
            child: Opacity(opacity: _opacity.value, child: child),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _SkillCard(skill: widget.skill, onDelete: widget.onDelete),
      ),
    );
  }
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({required this.skill, required this.onDelete});

  final Skill skill;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? AppColors.darkPaper : AppColors.paper;
    final cardBorder = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.5)
        : Colors.white.withValues(alpha: 0.8);

    final hasBlurb = skill.blurb.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.terracotta.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 20,
                  color: isDark
                      ? AppColors.terracotta
                      : AppColors.terracottaDeep,
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skill.name,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (hasBlurb) ...[
                      const SizedBox(height: 4),
                      Text(
                        skill.blurb,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(14),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptySkillsState extends StatelessWidget {
  const _EmptySkillsState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final iconBg = isDark
        ? AppColors.terracotta.withValues(alpha: 0.18)
        : AppColors.terracottaTint;
    final iconFg = isDark ? AppColors.terracotta : AppColors.terracottaDeep;

    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          child: Icon(Icons.lightbulb_outline_rounded, size: 26, color: iconFg),
        ),
        const SizedBox(height: 14),
        Text(
          'No skills yet',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Tap the + button to create your first post and offer help to neighbors.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

