// create_post_sheet.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api.dart';
import '../theme/colors.dart';

class CreatePostSheet extends StatefulWidget {
  const CreatePostSheet({super.key});

  @override
  State<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<CreatePostSheet>
    with SingleTickerProviderStateMixin {
  final _name = TextEditingController();
  final _blurb = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile?> _images = [null, null, null];

  bool _submitting = false;
  String? _uploadProgress;
  String? _error;
  bool _titleError = false;

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

  Future<void> _pickImage(int index) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _images[index] = image;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Couldn\'t open image picker. Please check permissions.';
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images[index] = null;
    });
  }

  void _submit() async {
    final name = _name.text.trim();
    final blurb = _blurb.text.trim();

    if (name.isEmpty) {
      setState(() {
        _error = 'Please enter a title.';
        _titleError = true;
      });
      return;
    }

    if (blurb.isEmpty) {
      setState(() {
        _error = 'Please enter a description.';
        _titleError = false;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final imagePaths = <String>[];
      final imagesToUpload = _images.where((img) => img != null).toList();
      for (int i = 0; i < imagesToUpload.length; i++) {
        final img = imagesToUpload[i]!;
        if (mounted) {
          setState(() => _uploadProgress = 'Uploading image ${i + 1} of ${imagesToUpload.length}');
        }
        final uploaded = await Api.uploadFile(
          '/api/uploads/images',
          File(img.path),
        );
        imagePaths.add(uploaded['path'] as String);
      }
      if (mounted) {
        setState(() => _uploadProgress = null);
      }

      await Api.post(
        '/api/users/me/skills',
        body: {'name': name, 'blurb': blurb, 'image_paths': imagePaths},
      );

      if (!mounted) return;

      _successController.forward();
      await Future.delayed(const Duration(milliseconds: 700));

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = describeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    final dialogBg = isDark ? AppColors.darkPaper : AppColors.paper;

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
                  'Create a post',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Share your skill with neighbors nearby.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Image picker
                Text(
                  'PHOTOS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(3, (index) {
                    return Expanded(
                      child: GestureDetector(
                        onTap: _images[index] == null
                            ? () => _pickImage(index)
                            : () => _removeImage(index),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSand.withValues(alpha: 0.5)
                                  : AppColors.sand.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkBorder.withValues(
                                        alpha: 0.3,
                                      )
                                    : AppColors.inkSoft.withValues(alpha: 0.1),
                                width: 1,
                              ),
                            ),
                            child: _images[index] == null
                                ? Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 32,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.4),
                                  )
                                : Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(11),
                                        child: Image.file(
                                          File(_images[index]!.path),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.6,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),

                // Title field
                Text(
                  'TITLE',
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
                    if (_error != null) setState(() { _error = null; _titleError = false; });
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
                    errorText: _titleError ? _error : null,
                    errorStyle: TextStyle(fontSize: 12, color: AppColors.error),
                  ),
                ),
                const SizedBox(height: 16),

                // Description field
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
                  maxLines: 4,
                  maxLength: 500,
                  onChanged: (_) {
                    if (_error != null) setState(() { _error = null; _titleError = false; });
                  },
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'Describe what you can help with, your experience, availability...',
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkSand.withValues(alpha: 0.5)
                        : AppColors.sand.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    errorText: !_titleError ? _error : null,
                    errorStyle: TextStyle(fontSize: 12, color: AppColors.error),
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                          side: BorderSide(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.15,
                            ),
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
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_rounded,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Posted!',
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
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (_uploadProgress != null) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        _uploadProgress!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ],
                                )
                              : const Text('Post'),
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
