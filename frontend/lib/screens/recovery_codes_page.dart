import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/colors.dart';
import '../widgets/staggered_entrance.dart';

class RecoveryCodesPage extends StatelessWidget {
  const RecoveryCodesPage({super.key, required this.recoveryCodes});

  final List<String> recoveryCodes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final allCodesText = recoveryCodes.join('\n');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: StaggeredEntrance(
          duration: const Duration(milliseconds: 1100),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
            children: [
              StaggeredItem(
                index: 0,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: theme.colorScheme.onSurface,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark
                        ? AppColors.darkSand.withValues(alpha: 0.9)
                        : Colors.white.withValues(alpha: 0.7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              StaggeredItem(
                index: 1,
                child: Text(
                  'Save your recovery codes',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    letterSpacing: -0.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              StaggeredItem(
                index: 2,
                child: Text(
                  'If you lose access to your authenticator app, you can use '
                  'one of these codes to reset your password. Each code can '
                  'only be used once. Store them somewhere safe.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    fontSize: 14.5,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              StaggeredItem(
                index: 3,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSand.withValues(alpha: 0.5)
                        : AppColors.sand.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < recoveryCodes.length; i++) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            recoveryCodes[i],
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                              color: theme.colorScheme.onSurface,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        if (i == 3) const SizedBox(height: 4),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              StaggeredItem(
                index: 4,
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: allCodesText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Recovery codes copied'),
                          backgroundColor: AppColors.ink,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 17),
                    label: const Text('Copy all codes'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurface.withValues(
                        alpha: 0.7,
                      ),
                      side: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder.withValues(alpha: 0.6)
                            : AppColors.inkSoft.withValues(alpha: 0.15),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              StaggeredItem(
                index: 5,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
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
                    child: const Text('Done'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
