import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/user_profile.dart';
import '../services/api.dart';
import '../services/theme_controller.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import 'intro_page.dart';
import 'legal_page.dart';
import 'map_picker.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  UserProfile? _profile;
  bool _loading = true;
  String? _error;
  bool _savingAvailability = false;
  bool _savingLocation = false;
  bool _savingPhone = false;
  bool _deleting = false;
  final _phoneController = TextEditingController();

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
        _phoneController.text = profile.phone ?? '';
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

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _toggleAvailability(bool value) async {
    setState(() => _savingAvailability = true);
    try {
      final res = await Api.patch('/api/users/me', body: {'is_available': value});
      if (!mounted) return;
      final profile = UserProfile.fromJson(res as Map<String, dynamic>);
      setState(() {
        _profile = profile;
        _savingAvailability = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingAvailability = false);
      _snack(describeError(e));
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
      final res = await Api.patch('/api/users/me', body: {'grid': selection.cellId});
      if (!mounted) return;
      final profile = UserProfile.fromJson(res as Map<String, dynamic>);
      setState(() {
        _profile = profile;
        _savingLocation = false;
      });
      _snack('Your area has been updated.', isError: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingLocation = false);
      _snack(describeError(e));
    }
  }

  Future<void> _savePhone({bool clear = false}) async {
    final phone = clear ? null : _phoneController.text.trim();
    if (!clear && (phone == null || phone.isEmpty)) return;

    setState(() => _savingPhone = true);
    try {
      final res = await Api.patch('/api/users/me', body: {'phone': phone});
      if (!mounted) return;
      final profile = UserProfile.fromJson(res as Map<String, dynamic>);
      setState(() {
        _profile = profile;
        _phoneController.text = profile.phone ?? '';
        _savingPhone = false;
      });
      _snack(
        clear ? 'Phone number cleared.' : 'Phone number saved privately.',
        isError: false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingPhone = false);
      _snack(describeError(e));
    }
  }

  void _snack(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _openLegal(LegalDocument document) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LegalPage(document: document)),
    );
  }

  Future<void> _downloadData() async {
    try {
      final data = await Api.exportMyData();
      if (!mounted) return;
      final pretty = const JsonEncoder.withIndent('  ').convert(data);
      await _showExportSheet(pretty);
    } catch (e) {
      if (!mounted) return;
      _snack(describeError(e));
    }
  }

  Future<void> _showExportSheet(String pretty) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottomSafe = MediaQuery.paddingOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomSafe),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkPaper : AppColors.paper,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Your data export',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'A JSON copy of everything we hold about you, ready to '
                      'share or keep elsewhere.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Flexible(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 260),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSand.withValues(alpha: 0.5)
                              : AppColors.sand.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            pretty,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.4,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: pretty));
                              if (ctx.mounted) Navigator.pop(ctx);
                              _snack('Data copied to clipboard.', isError: false);
                            },
                            icon: const Icon(Icons.copy_rounded, size: 17),
                            label: const Text('Copy'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () async {
                              final saved = await _saveExportFile(pretty);
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (saved != null) {
                                _snack('Saved to $saved', isError: false);
                              } else {
                                _snack('Couldn\'t save the file to this device.');
                              }
                            },
                            icon: const Icon(Icons.download_rounded, size: 17),
                            label: const Text('Save'),
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
      },
    );
  }

  Future<String?> _saveExportFile(String pretty) async {
    if (!Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) {
      return null;
    }
    try {
      final home = Platform.environment['HOME'];
      final baseDir = home == null
          ? Directory.current
          : Directory('$home/Downloads');
      if (!baseDir.existsSync()) {
        baseDir.createSync(recursive: true);
      }
      final stamp = DateTime.now().toIso8601String().split('.').first;
      final file = File(
        '${baseDir.path}/handover-export-$stamp.json',
      );
      await file.writeAsString(pretty);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final email = _profile?.email ?? '';

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DeleteAccountSheet(email: email),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);

    try {
      await Api.deleteAccount();
      await Api.clearSession();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const IntroPage()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      _snack(describeError(e));
    }
  }

  Future<void> _confirmSignOut() async {
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
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkPaper : AppColors.paper,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? AppColors.darkBorder.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.8),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: AppColors.error,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Sign out?',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'You\'ll need to sign back in to see nearby requests and manage '
                'your skills.',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 14,
                  height: 1.5,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                        side: BorderSide(
                          color: isDark
                              ? AppColors.darkBorder.withValues(alpha: 0.6)
                              : AppColors.inkSoft.withValues(alpha: 0.15),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
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
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Sign out'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    await Api.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const IntroPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        color: AppColors.terracotta,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                child: _buildContent(context),
              ),
            ),
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
            Icon(
              Icons.cloud_off_rounded,
              color: mutedText,
              size: 40,
            ),
            const SizedBox(height: 16),
            Text(
              'Couldn\'t load settings',
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
        _SettingsSection(
          title: 'Appearance',
          children: [
            _ThemeSelector(
              current: ThemeController.instance.mode,
              onChanged: (mode) => ThemeController.instance.setMode(mode),
            ),
          ],
        ),
        const SizedBox(height: 20),

        _SettingsSection(
          title: 'Availability',
          children: [
            _SettingsTile(
              icon: p.isAvailable
                  ? Icons.check_circle_outline_rounded
                  : Icons.pause_circle_outline_rounded,
              iconColor: p.isAvailable
                  ? AppColors.sage
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              title: 'Available to help',
              subtitle: p.isAvailable
                  ? 'Neighbors can see you in searches'
                  : 'You\'re hidden from searches',
              trailing: _AnimatedAvailabilitySwitch(
                value: p.isAvailable,
                onChanged: _toggleAvailability,
                isLoading: _savingAvailability,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        _SettingsSection(
          title: 'Privacy',
          children: [
            _SettingsTile(
              icon: Icons.map_outlined,
              iconColor: AppColors.terracotta,
              title: 'Privacy area',
              subtitle: p.grid ?? 'Not set',
              subtitleMuted: p.grid == null,
              trailing: _savingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: _chooseLocation,
            ),
            _SettingsTileDivider(isDark: isDark),
            _PhoneSettingsTile(
              profile: p,
              phoneController: _phoneController,
              savingPhone: _savingPhone,
              onSavePhone: _savePhone,
            ),
          ],
        ),
        const SizedBox(height: 20),

        _SettingsSection(
          title: 'Data & privacy',
          children: [
            _SettingsTile(
              icon: Icons.download_for_offline_outlined,
              iconColor: AppColors.sage,
              title: 'Download my data',
              subtitle: 'Export everything we hold about you (GDPR portability)',
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: _downloadData,
            ),
            _SettingsTileDivider(isDark: isDark),
            _SettingsTile(
              icon: Icons.delete_forever_outlined,
              iconColor: AppColors.error,
              title: 'Delete account',
              subtitle: 'Erase my account and all personal data',
              trailing: _deleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: _deleting ? null : _confirmDeleteAccount,
            ),
          ],
        ),
        const SizedBox(height: 20),

        _SettingsSection(
          title: 'Legal',
          children: [
            _SettingsTile(
              icon: Icons.description_outlined,
              iconColor: AppColors.terracotta,
              title: 'Terms of Service',
              subtitle: 'The rules for using Handover',
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () => _openLegal(LegalDocument.terms),
            ),
            _SettingsTileDivider(isDark: isDark),
            _SettingsTile(
              icon: Icons.privacy_tip_outlined,
              iconColor: AppColors.terracotta,
              title: 'Privacy Policy',
              subtitle: 'How we collect and use your data',
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () => _openLegal(LegalDocument.privacy),
            ),
            _SettingsTileDivider(isDark: isDark),
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              iconColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              title: 'About Handover',
              subtitle: 'Version 1.0.0 · Community-powered mutual aid',
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () => _showAboutSheet(),
            ),
          ],
        ),
        const SizedBox(height: 20),

        _SignOutButton(onTap: _confirmSignOut),
      ],
    );
  }

  void _showAboutSheet() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkPaper : AppColors.paper,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'About Handover',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 14),
                _AboutRow(label: 'App', value: 'Handover 1.0.0'),
                _AboutRow(label: 'What it is', value: 'Community-powered mutual aid'),
                _AboutRow(
                  label: 'Controller',
                  value: 'Handover Community · Within the European Union',
                ),
                _AboutRow(
                  label: 'Privacy contact',
                  value: 'privacy@handover.app',
                ),
                _AboutRow(
                  label: 'Your data',
                  value: 'Stored on EU servers. See the Privacy Policy for details.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({required this.current, required this.onChanged});

  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.terracotta.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.palette_outlined,
                  size: 17,
                  color: AppColors.terracotta,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Choose how the app looks',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _ThemeOption(
                label: 'System',
                icon: Icons.brightness_auto_outlined,
                selected: current == ThemeMode.system,
                onTap: () => onChanged(ThemeMode.system),
              ),
              const SizedBox(width: 10),
              _ThemeOption(
                label: 'Light',
                icon: Icons.light_mode_outlined,
                selected: current == ThemeMode.light,
                onTap: () => onChanged(ThemeMode.light),
              ),
              const SizedBox(width: 10),
              _ThemeOption(
                label: 'Dark',
                icon: Icons.dark_mode_outlined,
                selected: current == ThemeMode.dark,
                onTap: () => onChanged(ThemeMode.dark),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.terracotta.withValues(alpha: isDark ? 0.25 : 0.14)
                : (isDark
                      ? AppColors.darkSand.withValues(alpha: 0.5)
                      : AppColors.sand.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.terracotta.withValues(alpha: 0.8)
                  : (isDark
                        ? AppColors.darkBorder.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.8)),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? AppColors.terracotta
                    : theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppColors.terracotta
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkPaper : AppColors.paper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? AppColors.darkBorder.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.8),
              width: 1,
            ),
            boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.cardShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.subtitleMuted = false,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool subtitleMuted;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: subtitleMuted
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconTheme(
                data: IconThemeData(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  size: 18,
                ),
                child: trailing ?? const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTileDivider extends StatelessWidget {
  const _SettingsTileDivider({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 60),
      child: Container(
        height: 1,
        color: isDark
            ? AppColors.darkBorder.withValues(alpha: 0.4)
            : AppColors.inkSoft.withValues(alpha: 0.08),
      ),
    );
  }
}

class _AnimatedAvailabilitySwitch extends StatefulWidget {
  const _AnimatedAvailabilitySwitch({
    required this.value,
    required this.onChanged,
    required this.isLoading,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isLoading;

  @override
  State<_AnimatedAvailabilitySwitch> createState() =>
      _AnimatedAvailabilitySwitchState();
}

class _AnimatedAvailabilitySwitchState extends State<_AnimatedAvailabilitySwitch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _bounce;

  static const double _trackWidth = 56;
  static const double _trackHeight = 32;
  static const double _trackPadding = 3;
  static const double _thumbSize = 26;

  static const double _thumbLeftOff = _trackPadding;
  static const double _thumbLeftOn =
      _trackWidth - _trackPadding - _thumbSize;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _bounce = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.92,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.92,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 50,
      ),
    ]).animate(_bounceController);
  }

  @override
  void didUpdateWidget(_AnimatedAvailabilitySwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && !widget.isLoading) {
      _bounceController.forward(from: 0);
      HapticFeedback.selectionClick();
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.isLoading) return;
    HapticFeedback.lightImpact();
    widget.onChanged(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isOn = widget.value;

    final trackColor = isOn
        ? AppColors.sage
        : (isDark ? AppColors.darkSand : AppColors.sand.withValues(alpha: 0.9));

    final trackBorderColor = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.5)
        : Colors.white.withValues(alpha: 0.8);

    final thumbIconColor = isOn ? AppColors.sage : AppColors.inkSoft;

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _bounceController,
        builder: (context, _) {
          return Transform.scale(
            scale: _bounce.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              width: _trackWidth,
              height: _trackHeight,
              decoration: BoxDecoration(
                color: trackColor,
                borderRadius: BorderRadius.circular(_trackHeight / 2),
                border: Border.all(color: trackBorderColor, width: 1),
              ),
              child: Stack(
                children: [
                  if (widget.isLoading)
                    Positioned.fill(
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isOn
                                ? Colors.white
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                          ),
                        ),
                      ),
                    ),

                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    top: _trackPadding,
                    left: isOn ? _thumbLeftOn : _thumbLeftOff,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: widget.isLoading ? 0.0 : 1.0,
                      child: Container(
                        width: _thumbSize,
                        height: _thumbSize,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, anim) {
                            return ScaleTransition(
                              scale: anim,
                              child: FadeTransition(opacity: anim, child: child),
                            );
                          },
                          child: Icon(
                            isOn ? Icons.check_rounded : Icons.close_rounded,
                            key: ValueKey(isOn),
                            size: 15,
                            color: thumbIconColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PhoneSettingsTile extends StatefulWidget {
  const _PhoneSettingsTile({
    required this.profile,
    required this.phoneController,
    required this.savingPhone,
    required this.onSavePhone,
  });

  final UserProfile profile;
  final TextEditingController phoneController;
  final bool savingPhone;
  final Future<void> Function({bool clear}) onSavePhone;

  @override
  State<_PhoneSettingsTile> createState() => _PhoneSettingsTileState();
}

class _PhoneSettingsTileState extends State<_PhoneSettingsTile> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasPhone =
        widget.profile.phone != null && widget.profile.phone!.isNotEmpty;

    if (!_editing) {
      return _SettingsTile(
        icon: Icons.lock_outline_rounded,
        iconColor: AppColors.sage,
        title: 'Phone number',
        subtitle: hasPhone ? widget.profile.phone! : 'Not set',
        subtitleMuted: !hasPhone,
        trailing: widget.savingPhone
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right_rounded, size: 20),
        onTap: () => setState(() => _editing = true),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Phone number',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Encrypted at rest. Only shared when you choose.',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSand.withValues(alpha: 0.5)
                  : AppColors.sand.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: widget.phoneController,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              maxLength: 40,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Phone number',
                counterText: '',
                prefixIcon: Icon(
                  Icons.phone_outlined,
                  size: 17,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (hasPhone) ...[
                TextButton(
                  onPressed: widget.savingPhone
                      ? null
                      : () async {
                          await widget.onSavePhone(clear: true);
                          if (mounted) setState(() => _editing = false);
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Clear'),
                ),
                const Spacer(),
              ] else
                const Spacer(),
              TextButton(
                onPressed: widget.savingPhone
                    ? null
                    : () => setState(() => _editing = false),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface.withValues(
                    alpha: 0.7,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 6),
              FilledButton(
                onPressed: widget.savingPhone
                    ? null
                    : () async {
                        await widget.onSavePhone();
                        if (mounted) setState(() => _editing = false);
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.terracotta,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  elevation: 0,
                ),
                child: widget.savingPhone
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSand.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? AppColors.darkBorder.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.8),
            width: 1,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: AppColors.inkSoft.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.logout_rounded,
              size: 19,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 10),
            Text(
              'Sign out',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SCROLLABLE BOTTOM SHEET FOR DELETE ACCOUNT
// -----------------------------------------------------------------------------
class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet({required this.email});

  final String email;

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  late final TextEditingController _confirmController;
  bool _canConfirm = false;

  @override
  void initState() {
    super.initState();
    _confirmController = TextEditingController();
    _confirmController.addListener(_updateConfirmState);
  }

  void _updateConfirmState() {
    final canConfirm = _confirmController.text.trim() == widget.email;
    if (canConfirm != _canConfirm) {
      setState(() {
        _canConfirm = canConfirm;
      });
    }
  }

  @override
  void dispose() {
    _confirmController.removeListener(_updateConfirmState);
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Add bottom padding to account for the keyboard popping up
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkPaper : AppColors.paper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + keyboardHeight,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Header with icon
                Row(
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
                        Icons.warning_amber_rounded,
                        color: AppColors.error,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delete your account?',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'This action cannot be undone',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.error.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Description
                Text(
                  'This will permanently erase your Handover account and all associated data from our servers.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),

                // What gets deleted section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.error.withValues(alpha: 0.08)
                        : AppColors.error.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What will be deleted:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const _DeleteItem(
                        icon: Icons.person_outline_rounded,
                        text: 'Your profile and personal information',
                      ),
                      const _DeleteItem(
                        icon: Icons.school_outlined,
                        text: 'Skills you\'ve published',
                      ),
                      const _DeleteItem(
                        icon: Icons.chat_bubble_outline_rounded,
                        text: 'Messages exchanged with neighbors',
                      ),
                      const _DeleteItem(
                        icon: Icons.assignment_outlined,
                        text: 'Requests you\'ve made or received',
                      ),
                      const _DeleteItem(
                        icon: Icons.location_on_outlined,
                        text: 'Your privacy area and phone number',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // GDPR notice
                Text(
                  'Your data will be permanently removed in accordance with your GDPR right to erasure.',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // Confirmation input
                Text(
                  'To confirm, type your email address:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _confirmController,
                  autocorrect: false,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.email,
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkSand.withValues(alpha: 0.3)
                        : AppColors.sand.withValues(alpha: 0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons - COMPACT & FIXED ERROR
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface.withValues(
                          alpha: 0.75,
                        ),
                        side: BorderSide(
                          color: isDark
                              ? AppColors.darkBorder.withValues(alpha: 0.6)
                              : AppColors.inkSoft.withValues(alpha: 0.2),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        minimumSize: const Size(0, 0), // Fixed: was minSize
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _canConfirm
                          ? () => Navigator.pop(context, true)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.error.withValues(
                          alpha: 0.3,
                        ),
                        disabledForegroundColor: Colors.white.withValues(
                          alpha: 0.6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        minimumSize: const Size(0, 0), // Fixed: was minSize
                        elevation: 0,
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
                const SizedBox(height: 8), // Extra bottom padding for scroll
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteItem extends StatelessWidget {
  const _DeleteItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.error.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}