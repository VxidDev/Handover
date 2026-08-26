import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import '../services/api.dart';
import '../theme/colors.dart';
import 'home_shell.dart';
import 'map_picker.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with SingleTickerProviderStateMixin {
  final _pageController = PageController();
  final _skillNameController = TextEditingController();
  final _skillDescController = TextEditingController();
  int _currentPage = 0;
  bool _savingSkill = false;
  bool _uploadingImage = false;
  bool _locationSet = false;
  bool _skillAdded = false;

  late final AnimationController _bgController;
  late final Animation<double> _bgRotation;

  static const _pageCount = 3;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    )..repeat();
    _bgRotation = Tween<double>(begin: 0, end: 2 * math.pi).animate(_bgController);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _skillNameController.dispose();
    _skillDescController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    HapticFeedback.lightImpact();
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  void _nextPage() => _goToPage(_currentPage + 1);

  void _finish() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  Future<void> _pickLocation() async {
    final lat = Api.currentLat ?? 52.23;
    final lng = Api.currentLng ?? 21.01;

    final result = await Navigator.of(context).push<GridSelection>(
      MaterialPageRoute(
        builder: (_) => LocationGridPickerPage(initialLat: lat, initialLng: lng),
      ),
    );

    if (result == null || !mounted) return;

    try {
      await Api.post(
        '/api/users/me/location',
        body: {
          'lat': result.centerLat,
          'lng': result.centerLng,
          'grid_cell': result.cellId,
        },
      );
      Api.currentLat = result.centerLat;
      Api.currentLng = result.centerLng;
      setState(() => _locationSet = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeError(e)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (!mounted) return;
    _nextPage();
  }

  Future<void> _addSkill() async {
    final name = _skillNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a skill name'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _savingSkill = true);
    try {
      await Api.post(
        '/api/users/me/skills',
        body: {
          'name': name,
          'blurb': _skillDescController.text.trim(),
        },
      );
      setState(() => _skillAdded = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingSkill = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeError(e)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    setState(() => _savingSkill = false);

    if (!mounted) return;
    _nextPage();
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
      final res = await Api.uploadFile(
        '/api/uploads/images',
        File(croppedFile.path),
      );
      final path = res['path'] as String;
      await Api.patch('/api/users/me', body: {'profile_image': path});
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeError(e)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    setState(() => _uploadingImage = false);

    if (!mounted) return;
    _finish();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -120,
                right: -120,
                child: AnimatedBuilder(
                  animation: _bgRotation,
                  builder: (_, _) => Transform.rotate(
                    angle: _bgRotation.value,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? AppColors.terracotta.withValues(alpha: 0.06)
                              : AppColors.terracottaTint.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -80,
                left: -60,
                child: AnimatedBuilder(
                  animation: _bgRotation,
                  builder: (_, _) => Transform.rotate(
                    angle: -_bgRotation.value * 0.7,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? AppColors.sage.withValues(alpha: 0.06)
                              : AppColors.sageLight.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Semantics(
                          label: _currentPage == 0
                              ? 'Welcome to Handover'
                              : 'Step ${_currentPage + 1} of $_pageCount',
                          child: Text(
                            _currentPage == 0
                                ? 'Welcome'
                                : 'Step ${_currentPage + 1}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _currentPage == 2 ? null : _finish,
                          style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            tapTargetSize: MaterialTapTargetSize.padded,
                          ),
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (i) => setState(() => _currentPage = i),
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildLocationPage(context, isDark),
                        _buildSkillPage(context, isDark),
                        _buildPhotoPage(context, isDark),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: _buildPageIndicator(isDark),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationPage(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        AppColors.terracotta.withValues(alpha: 0.25),
                        AppColors.terracotta.withValues(alpha: 0.12),
                      ]
                    : [AppColors.terracottaTint, AppColors.terracottaLight],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_on_outlined,
              size: 34,
              color: isDark ? AppColors.terracotta : AppColors.terracottaDeep,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Where are you?',
            style: theme.textTheme.headlineMedium?.copyWith(
              letterSpacing: -0.8,
              fontWeight: FontWeight.w700,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Set your location so neighbors can find you nearby. '
            'We only show your neighborhood, never your exact address.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 14.5,
              height: 1.5,
            ),
          ),
          const Spacer(),
          Semantics(
            button: true,
            label: 'Set location',
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _pickLocation,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.terracotta,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                  elevation: 0,
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.map_rounded, size: 18),
                    const SizedBox(width: 8),
                    const Text('Set location'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _nextPage,
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(
                'I\'ll do this later',
                style: TextStyle(
                  color: isDark
                      ? AppColors.terracotta
                      : AppColors.terracottaDeep,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSkillPage(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final inputBg = isDark
        ? AppColors.darkSand.withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.72);
    final inputBorder = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.7)
        : Colors.white.withValues(alpha: 0.9);
    final inputShadow = isDark
        ? Colors.black.withValues(alpha: 0.2)
        : AppColors.inkSoft.withValues(alpha: 0.04);

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        AppColors.sage.withValues(alpha: 0.25),
                        AppColors.sage.withValues(alpha: 0.12),
                      ]
                    : [AppColors.sageLight, AppColors.sageLight.withValues(alpha: 0.5)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 34,
              color: isDark ? AppColors.sage : AppColors.sage,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'What can you help with?',
            style: theme.textTheme.headlineMedium?.copyWith(
              letterSpacing: -0.8,
              fontWeight: FontWeight.w700,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Add a skill so neighbors know what you can offer. '
            'You can always add more later.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 14.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          Semantics(
            label: 'Skill name',
            child: _GlassField(
              controller: _skillNameController,
              hintText: 'Skill name (e.g. Gardening)',
              icon: Icons.star_outline_rounded,
              inputBg: inputBg,
              inputBorder: inputBorder,
              inputShadow: inputShadow,
            ),
          ),
          const SizedBox(height: 14),
          Semantics(
            label: 'Skill description, optional',
            child: _GlassField(
              controller: _skillDescController,
              hintText: 'Short description (optional)',
              icon: Icons.description_outlined,
              inputBg: inputBg,
              inputBorder: inputBorder,
              inputShadow: inputShadow,
              maxLines: 2,
            ),
          ),
          const Spacer(),
          Semantics(
            button: true,
            label: 'Add skill',
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _savingSkill ? null : _addSkill,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.sage,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                  elevation: 0,
                  disabledBackgroundColor:
                      AppColors.sage.withValues(alpha: 0.5),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
                child: _savingSkill
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Add skill'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _savingSkill ? null : _nextPage,
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(
                'Skip for now',
                style: TextStyle(
                  color: isDark
                      ? AppColors.terracotta
                      : AppColors.terracottaDeep,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPhotoPage(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        AppColors.gold.withValues(alpha: 0.25),
                        AppColors.gold.withValues(alpha: 0.12),
                      ]
                    : [AppColors.goldTint, AppColors.goldTint.withValues(alpha: 0.5)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_add_outlined,
              size: 34,
              color: isDark ? AppColors.gold : AppColors.gold,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Add a profile photo',
            style: theme.textTheme.headlineMedium?.copyWith(
              letterSpacing: -0.8,
              fontWeight: FontWeight.w700,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'A photo helps neighbors recognize you and builds trust in the community.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 14.5,
              height: 1.5,
            ),
          ),
          const Spacer(),
          Center(
            child: Semantics(
              button: true,
              label: 'Choose profile photo',
              child: GestureDetector(
                onTap: _uploadingImage ? null : _pickProfileImage,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSand : AppColors.sand,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.8),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.terracotta.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: _uploadingImage
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.terracotta,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt_outlined,
                              size: 36,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap to add',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          const Spacer(),
          Semantics(
            button: true,
            label: 'Choose photo from gallery',
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _uploadingImage ? null : _pickProfileImage,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.terracotta,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                  elevation: 0,
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
                child: const Text('Choose photo'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _uploadingImage ? null : _finish,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.sage,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
                elevation: 0,
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
              child: const Text('Get started'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pageCount, (i) {
        final isActive = i == _currentPage;
        final isCompleted = (i == 0 && _locationSet) || (i == 1 && _skillAdded);
        return GestureDetector(
          onTap: i <= _currentPage ? () => _goToPage(i) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: isActive ? 28 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.terracotta
                  : isCompleted
                      ? AppColors.sage
                      : isDark
                          ? AppColors.darkBorder
                          : AppColors.border,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        );
      }),
    );
  }
}

class _GlassField extends StatelessWidget {
  const _GlassField({
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.inputBg,
    required this.inputBorder,
    required this.inputShadow,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final Color inputBg;
  final Color inputBorder;
  final Color inputShadow;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: inputBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: inputShadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(
          fontSize: 14.5,
          color: theme.colorScheme.onSurface,
          height: 1.2,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            fontSize: 14.5,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
          prefixIcon: Icon(
            icon,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            size: 20,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
