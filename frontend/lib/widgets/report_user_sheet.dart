import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api.dart';
import '../theme/colors.dart';

class ReportUserSheet extends StatefulWidget {
  const ReportUserSheet({super.key, required this.userId});

  final int userId;

  @override
  State<ReportUserSheet> createState() => _ReportUserSheetState();
}

class _ReportUserSheetState extends State<ReportUserSheet> {
  String? _reason;
  final _details = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;

  static const _reasons = [
    'Spam',
    'Inappropriate content',
    'Harassment',
    'Fake profile',
    'Other',
  ];

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await Api.post(
        '/api/safety/report',
        body: {
          'reported_id': widget.userId,
          'reason': _reason,
          'details': _details.text.trim(),
        },
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(e))));
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: _submitted
                ? _buildSuccess(context, theme)
                : _buildForm(context, theme, isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess(BuildContext context, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.sage.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.sage,
            size: 28,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Report submitted',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Thank you for helping keep the community safe. We\'ll review your report.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.terracotta,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
              padding: const EdgeInsets.symmetric(vertical: 15),
              elevation: 0,
            ),
            child: const Text(
              'Done',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context, ThemeData theme, bool isDark) {
    final cancelBorder = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.6)
        : AppColors.inkSoft.withValues(alpha: 0.2);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.flag_outlined,
                size: 20,
                color: AppColors.error,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Report user',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Why are you reporting this person?',
          style: TextStyle(
            fontSize: 13.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        ..._reasons.map(
          (reason) => GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _reason = reason);
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: [
                  Icon(
                    _reason == reason
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off_rounded,
                    size: 20,
                    color: _reason == reason
                        ? AppColors.terracotta
                        : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    reason,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSand.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? AppColors.darkBorder.withValues(alpha: 0.7)
                  : AppColors.inkSoft.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: TextField(
            controller: _details,
            maxLines: 3,
            style: TextStyle(
              fontSize: 13.5,
              color: theme.colorScheme.onSurface,
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText: 'Additional details (optional)',
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
                fontSize: 13.5,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: cancelBorder, width: 1),
                  ),
                  child: Center(
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _reason == null ? null : _submit,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _reason == null
                        ? AppColors.error.withValues(alpha: 0.4)
                        : AppColors.error,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: _reason != null
                        ? [
                            BoxShadow(
                              color: AppColors.error.withValues(alpha: 0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Submit report',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
