import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'map_picker.dart';
import '../models/neighbor_skill.dart';
import '../services/api.dart';
import '../theme/colors.dart';
import '../widgets/radius_chip_selector.dart';
import '../widgets/skill_card.dart';
import '../widgets/staggered_entrance.dart';

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final _query = TextEditingController();

  double _radius = 2;
  Timer? _debounce;

  List<NeighborSkill> _results = [];
  bool _loading = true;
  String? _error;

  bool _availableOnly = false;
  String _sortBy = 'distance';

  static const _defaultRadius = 2.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Good night 🌙';
    if (hour < 12) return 'Good morning ☀️';
    if (hour < 18) return 'Good afternoon 👋';
    return 'Good evening 🌆';
  }

  String get _radiusLabel {
    if (_radius == _radius.roundToDouble()) {
      return _radius.toInt().toString();
    }
    return _radius.toStringAsFixed(1);
  }

  bool get _hasActiveFilters =>
      _radius != _defaultRadius || _availableOnly || _sortBy != 'distance';

  void _onQueryChanged(String value) {
    setState(() {});
    _scheduleSearch();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  void _submitSearch() {
    _debounce?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();
    _load();
  }

  void _clearSearch() {
    _debounce?.cancel();
    _query.clear();
    setState(() {});
    _load();
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FiltersBottomSheet(
        initialRadius: _radius,
        initialAvailableOnly: _availableOnly,
        initialSortBy: _sortBy,
      ),
    );

    if (result != null) {
      final newRadius = result['radius'] as double;
      final newAvailableOnly = result['available_only'] as bool;
      final newSortBy = result['sort_by'] as String;
      if (newRadius != _radius ||
          newAvailableOnly != _availableOnly ||
          newSortBy != _sortBy) {
        setState(() {
          _radius = newRadius;
          _availableOnly = newAvailableOnly;
          _sortBy = newSortBy;
        });
        _scheduleSearch();
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await Api.get(
        '/api/skills',
        query: {
          'q': _query.text.trim(),
          'radius_km': _radius.toStringAsFixed(1),
          'lat': (Api.currentLat ?? 0.0).toString(),
          'lng': (Api.currentLng ?? 0.0).toString(),
          if (_availableOnly) 'available': 'true',
          'sort': _sortBy,
        },
      );

      final items = (res as List)
          .map((e) => NeighborSkill.fromSearchResult(e as Map<String, dynamic>))
          .toList();

      if (!mounted) return;

      setState(() {
        _results = items;
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

  Future<void> _requestHelp(NeighborSkill neighbor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.black.withValues(alpha: 0.5)
          : AppColors.ink.withValues(alpha: 0.3),
      builder: (ctx) => _RequestHelpDialog(neighbor: neighbor),
    );
    if (confirmed == true && mounted) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.terracotta,
          backgroundColor: theme.colorScheme.surface,
          onRefresh: _load,
          child: StaggeredEntrance(
            duration: const Duration(milliseconds: 1000),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollStartNotification) {
                  FocusManager.instance.primaryFocus?.unfocus();
                }
                return false;
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
                children: [
                  StaggeredItem(index: 0, child: _header(context)),
                  const SizedBox(height: 16),
                  StaggeredItem(index: 1, child: _searchBar(context)),
                  const SizedBox(height: 20),
                  StaggeredItem(index: 2, child: _resultsHeader(context)),
                  const SizedBox(height: 10),
                  ..._buildResults(context, startIndex: 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _greeting,
          style: TextStyle(
            fontSize: 12.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Find help nearby',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.6,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _searchBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark
        ? AppColors.darkSand.withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.75);

    final borderColor = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.85);

    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.12)
        : AppColors.inkSoft.withValues(alpha: 0.04);

    final filterIconColor = _hasActiveFilters
        ? (isDark ? AppColors.terracotta : AppColors.terracottaDeep)
        : theme.colorScheme.onSurface.withValues(alpha: 0.4);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _query,
              onChanged: _onQueryChanged,
              onSubmitted: (_) => _submitSearch(),
              textInputAction: TextInputAction.search,
              style: TextStyle(
                fontSize: 14.5,
                color: theme.colorScheme.onSurface,
                height: 1.2,
              ),
              decoration: InputDecoration(
                hintText: 'Search a skill…',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
                  fontSize: 14.5,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  size: 20,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 44,
                ),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : GestureDetector(
                        onTap: _clearSearch,
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.35,
                          ),
                        ),
                      ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 13,
                  horizontal: 12,
                ),
              ),
            ),
          ),

          // Divider
          Container(
            width: 1,
            height: 20,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),

          // Filter icon
          GestureDetector(
            onTap: _openFilters,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.tune_rounded, size: 19, color: filterIconColor),
                  if (_hasActiveFilters)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.terracotta,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultsHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Text(
          'Nearby neighbors',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            fontSize: 15.5,
          ),
        ),
        const SizedBox(width: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSand : AppColors.sand,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            '${_results.length}',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ),
        if (_hasActiveFilters) ...[
          const Spacer(),
          GestureDetector(
            onTap: () {
              setState(() => _radius = _defaultRadius);
              _scheduleSearch();
            },
            child: Text(
              'Reset · ${_radiusLabel}km',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.terracotta : AppColors.terracottaDeep,
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildResults(BuildContext context, {int startIndex = 3}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (Api.currentLat == null) {
      final iconBg = isDark ? AppColors.darkSand : AppColors.sand;
      final iconBorder = isDark
          ? AppColors.darkBorder.withValues(alpha: 0.6)
          : Colors.white.withValues(alpha: 0.8);

      return [
        StaggeredItem(
          index: startIndex,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: iconBorder, width: 1.5),
                  ),
                  child: Icon(
                    Icons.map_outlined,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    size: 24,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Set your location to find nearby skills',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'We need your area to match you with neighbors.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () async {
                    final selection = await Navigator.of(context)
                        .push<GridSelection>(MaterialPageRoute(
                      builder: (_) => LocationGridPickerPage(
                        initialLat: Api.currentLat ?? 52.23,
                        initialLng: Api.currentLng ?? 21.01,
                      ),
                    ));
                    if (selection != null && mounted) {
                      try {
                        await Api.patch(
                          '/api/users/me',
                          body: {
                            'lat': selection.centerLat,
                            'lng': selection.centerLng,
                            'grid': selection.cellId,
                          },
                        );
                        Api.currentLat = selection.centerLat;
                        Api.currentLng = selection.centerLng;
                      } catch (_) {}
                      _load();
                    }
                  },
                  icon: const Icon(Icons.map_rounded, size: 17),
                  label: const Text('Set your area'),
                  style: FilledButton.styleFrom(
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    if (_loading && _results.isEmpty) {
      return [
        StaggeredItem(
          index: startIndex,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 56),
            child: Column(
              children: List.generate(3, (_) => _SkeletonCard(isDark: isDark)),
            ),
          ),
        ),
      ];
    }

    if (_error != null) {
      final errorIconBg = isDark ? AppColors.darkSand : AppColors.sand;
      final errorIconBorder = isDark
          ? AppColors.darkBorder.withValues(alpha: 0.6)
          : Colors.white.withValues(alpha: 0.8);

      return [
        StaggeredItem(
          index: startIndex,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: errorIconBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: errorIconBorder, width: 1.5),
                  ),
                  child: Icon(
                    Icons.cloud_off_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    size: 24,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Something went wrong',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: const Text('Try again'),
                  style: FilledButton.styleFrom(
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    if (_results.isEmpty) {
      return [
        StaggeredItem(
          index: startIndex,
          child: _EmptyResults(
            hasQuery: _query.text.trim().isNotEmpty,
            onClear: _clearSearch,
          ),
        ),
      ];
    }

    final progressBg = isDark ? AppColors.darkSand : AppColors.sand;

    return [
      if (_loading)
        StaggeredItem(
          index: startIndex,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                minHeight: 2.5,
                backgroundColor: progressBg,
                valueColor: const AlwaysStoppedAnimation(AppColors.terracotta),
              ),
            ),
          ),
        ),
      ..._results.asMap().entries.map((entry) {
        final idx = entry.key;
        final n = entry.value;
        final itemIndex = startIndex + idx + (_loading ? 1 : 0);

        return StaggeredItem(
          index: itemIndex,
          begin: const Offset(0, 0.06),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SkillCard(neighbor: n, onRequest: () => _requestHelp(n)),
          ),
        );
      }),
    ];
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.hasQuery, required this.onClear});

  final bool hasQuery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final iconBg = isDark ? AppColors.darkSand : AppColors.sand;
    final iconBorder = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.8);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
              border: Border.all(color: iconBorder, width: 1.5),
            ),
            child: Icon(
              Icons.search_off_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              size: 24,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No matches yet',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 14.5,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            hasQuery
                ? 'Try a different skill or widen your radius.'
                : 'Try widening your radius to see more neighbors.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          if (hasQuery) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear_rounded, size: 16),
              label: const Text('Clear search'),
              style: TextButton.styleFrom(
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FiltersBottomSheet extends StatefulWidget {
  const _FiltersBottomSheet({
    required this.initialRadius,
    required this.initialAvailableOnly,
    required this.initialSortBy,
  });

  final double initialRadius;
  final bool initialAvailableOnly;
  final String initialSortBy;

  @override
  State<_FiltersBottomSheet> createState() => _FiltersBottomSheetState();
}

class _FiltersBottomSheetState extends State<_FiltersBottomSheet> {
  late double _radius = widget.initialRadius;
  late bool _availableOnly = widget.initialAvailableOnly;
  late String _sortBy = widget.initialSortBy;

  String get _radiusLabel {
    if (_radius == _radius.roundToDouble()) {
      return _radius.toInt().toString();
    }
    return _radius.toStringAsFixed(1);
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.15,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filters',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        _radius = 2.0;
                        _availableOnly = false;
                        _sortBy = 'distance';
                      }),
                      child: Text(
                        'Reset',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Adjust your search area to find neighbors nearby.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Icon(
                      Icons.near_me_rounded,
                      size: 15,
                      color: AppColors.terracotta,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Distance',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$_radiusLabel km',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.65,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                RadiusChipSelector(
                  value: _radius,
                  onChanged: (v) => setState(() => _radius = v),
                ),
                const SizedBox(height: 16),
                // Available only toggle
                GestureDetector(
                  onTap: () => setState(() => _availableOnly = !_availableOnly),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                          color: _availableOnly
                              ? AppColors.sage
                              : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Available only',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: _availableOnly,
                            onChanged: (v) => setState(() => _availableOnly = v),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Sort by
                Row(
                  children: [
                    const Icon(
                      Icons.sort_rounded,
                      size: 15,
                      color: AppColors.terracotta,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Sort by',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SortChip(
                      label: 'Distance',
                      icon: Icons.near_me_rounded,
                      selected: _sortBy == 'distance',
                      onTap: () => setState(() => _sortBy = 'distance'),
                    ),
                    _SortChip(
                      label: 'Karma',
                      icon: Icons.eco_outlined,
                      selected: _sortBy == 'karma',
                      onTap: () => setState(() => _sortBy = 'karma'),
                    ),
                    _SortChip(
                      label: 'Name',
                      icon: Icons.person_outline_rounded,
                      selected: _sortBy == 'name',
                      onTap: () => setState(() => _sortBy = 'name'),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop({
                      'radius': _radius,
                      'available_only': _availableOnly,
                      'sort_by': _sortBy,
                    }),
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
                      'Apply',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
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

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.terracotta.withValues(alpha: 0.12)
              : (isDark ? AppColors.darkSand : AppColors.sand),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected
                ? AppColors.terracotta.withValues(alpha: 0.3)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected
                  ? (isDark ? AppColors.terracotta : AppColors.terracottaDeep)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? (isDark ? AppColors.terracotta : AppColors.terracottaDeep)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestHelpDialog extends StatefulWidget {
  const _RequestHelpDialog({required this.neighbor});

  final NeighborSkill neighbor;

  @override
  State<_RequestHelpDialog> createState() => _RequestHelpDialogState();
}

class _RequestHelpDialogState extends State<_RequestHelpDialog>
    with SingleTickerProviderStateMixin {
  final _message = TextEditingController();
  bool _sending = false;
  bool _success = false;
  String? _error;

  late final AnimationController _highFiveController;
  late final Animation<double> _successFade;

  @override
  void initState() {
    super.initState();
    _highFiveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _successFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _highFiveController,
        curve: const Interval(0.0, 0.2, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _highFiveController.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    FocusManager.instance.primaryFocus?.unfocus();

    final skillId = widget.neighbor.skillId;
    if (skillId == null) {
      setState(() {
        _sending = false;
        _error = 'This skill has no id — please try again.';
      });
      return;
    }

    try {
      await Api.post(
        '/api/requests',
        body: {'skill_id': skillId, 'message': _message.text.trim()},
      );

      if (!mounted) return;

      setState(() {
        _success = true;
        _sending = false;
      });
      _highFiveController.forward();

      Future.delayed(const Duration(milliseconds: 2200), () {
        if (!mounted) return;
        Navigator.of(context).pop(true);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = describeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final dialogBg = isDark ? AppColors.darkPaper : AppColors.paper;
    final dialogBorder = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.6);
    final dialogShadow = isDark
        ? Colors.black.withValues(alpha: 0.3)
        : AppColors.ink.withValues(alpha: 0.12);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: dialogBg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: dialogBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: dialogShadow,
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: _success
            ? _buildSuccessAnimation(context)
            : _buildRequestForm(context),
      ),
    );
  }

  Widget _buildSuccessAnimation(BuildContext context) {
    final theme = Theme.of(context);
    final firstName = widget.neighbor.name.split(' ').first;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 120,
            height: 100,
            child: _HighFiveAnimation(controller: _highFiveController),
          ),
          const SizedBox(height: 20),
          FadeTransition(
            opacity: _successFade,
            child: Text(
              'High five sent! ✋',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 6),
          FadeTransition(
            opacity: _successFade,
            child: Text(
              '$firstName will get back to you soon.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestForm(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final firstName = widget.neighbor.name.split(' ').first;
    final avatarColor = AppColors.avatarFor(
      widget.neighbor.name,
      isDark: isDark,
    );

    final avatarBorder = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.5)
        : Colors.white.withValues(alpha: 0.8);

    final textFieldBg = isDark
        ? AppColors.darkSand.withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.7);

    final textFieldBorder = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.7)
        : AppColors.inkSoft.withValues(alpha: 0.15);

    final errorBorder = AppColors.error.withValues(alpha: 0.4);

    final cancelBorder = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.6)
        : AppColors.inkSoft.withValues(alpha: 0.2);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: avatarColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: avatarBorder, width: 1.5),
                ),
                child: widget.neighbor.ownerProfileImage != null
                    ? ClipOval(
                        child: Image.network(
                          '${Api.baseUrl}${widget.neighbor.ownerProfileImage}',
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Text(
                            widget.neighbor.name.isNotEmpty
                                ? widget.neighbor.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: avatarColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 19,
                            ),
                          ),
                        ),
                      )
                    : Text(
                        widget.neighbor.name.isNotEmpty
                            ? widget.neighbor.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: avatarColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 19,
                        ),
                      ),
              ),
              const SizedBox(height: 14),
              Text(
                'Ask $firstName for help',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'They\'ll get a notification and can accept or decline.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          child: Container(
            decoration: BoxDecoration(
              color: textFieldBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _error != null ? errorBorder : textFieldBorder,
                width: 1,
              ),
            ),
            child: TextField(
              controller: _message,
              autofocus: true,
              maxLines: 3,
              style: TextStyle(
                fontSize: 13.5,
                color: theme.colorScheme.onSurface,
                height: 1.4,
              ),
              decoration: InputDecoration(
                hintText: 'What do you need help with? (optional)',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
                  fontSize: 13.5,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 15,
                  color: AppColors.error,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12.5,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _sending ? null : () => Navigator.pop(context, false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: cancelBorder, width: 1),
                    ),
                    child: Center(
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.65,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: _send,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: _sending
                          ? AppColors.terracotta.withValues(alpha: 0.6)
                          : AppColors.terracotta,
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.terracotta.withValues(
                            alpha: isDark ? 0.3 : 0.2,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.send_rounded,
                                  size: 15,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 7),
                                Text(
                                  'Send request',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HighFiveAnimation extends StatefulWidget {
  const _HighFiveAnimation({required this.controller});

  final AnimationController controller;

  @override
  State<_HighFiveAnimation> createState() => _HighFiveAnimationState();
}

class _HighFiveAnimationState extends State<_HighFiveAnimation> {
  List<_Particle> _particles = [];
  bool _triggered = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value;

        if (t >= 0.35 && !_triggered) {
          _triggered = true;
          _particles = _generateParticles(isDark: isDark);
        }

        double leftX, leftY, rightX, rightY, scale, leftRot, rightRot;
        double rippleScale, rippleOpacity;
        double particleProgress;

        if (t < 0.35) {
          final p = Curves.easeOutCubic.transform(t / 0.35);
          leftX = -65 + (62 * p);
          leftY = 60 - (70 * p);
          rightX = 65 - (62 * p);
          rightY = 60 - (70 * p);
          leftRot = 0.4 - (0.6 * p);
          rightRot = -0.4 + (0.6 * p);
          scale = 1.0;
          rippleScale = 0;
          rippleOpacity = 0;
          particleProgress = 0;
        } else if (t < 0.65) {
          final p = (t - 0.35) / 0.30;
          final recoil = Curves.easeOutQuart.transform(p);
          leftX = 4 - (34 * recoil);
          leftY = -10 + (10 * recoil);
          rightX = -4 + (34 * recoil);
          rightY = -10 + (10 * recoil);
          leftRot = -0.2 - (0.15 * recoil);
          rightRot = 0.2 + (0.15 * recoil);
          if (p < 0.15) {
            scale = 1.0 - (0.15 * (p / 0.15));
          } else {
            scale = 0.85 + (0.15 * ((p - 0.15) / 0.85));
          }
          final rippleP = p;
          rippleScale = 1.0 + (rippleP * 3.0);
          rippleOpacity = (1 - rippleP).clamp(0.0, 1.0);
          particleProgress = p;
        } else {
          leftX = -30;
          leftY = 0;
          leftRot = -0.35;
          rightX = 30;
          rightY = 0;
          rightRot = 0.35;
          scale = 1.0;
          rippleScale = 0;
          rippleOpacity = 0;
          particleProgress = 1.0;
        }

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (rippleOpacity > 0.01)
              Transform.scale(
                scale: rippleScale,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.terracotta.withValues(
                        alpha: rippleOpacity * 0.6,
                      ),
                      width: 4,
                    ),
                  ),
                ),
              ),
            for (final p in _particles)
              Transform.translate(
                offset: Offset(
                  p.dx * particleProgress * 80,
                  p.dy * particleProgress * 80 - (particleProgress * 25),
                ),
                child: Transform.scale(
                  scale:
                      (1 + particleProgress * 0.5) *
                      (1 - particleProgress * 0.8),
                  child: Container(
                    width: p.size,
                    height: p.size,
                    decoration: BoxDecoration(
                      color: p.color.withValues(
                        alpha: (1 - particleProgress).clamp(0.0, 1.0),
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            Transform.translate(
              offset: Offset(leftX, leftY),
              child: Transform.rotate(
                angle: leftRot,
                child: Transform.scale(
                  scale: scale,
                  child: Transform.flip(
                    flipX: true,
                    child: Icon(
                      Icons.front_hand_rounded,
                      color: AppColors.terracotta,
                      size: 64,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.25 : 0.15,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(rightX, rightY),
              child: Transform.rotate(
                angle: rightRot,
                child: Transform.scale(
                  scale: scale,
                  child: Icon(
                    Icons.front_hand_rounded,
                    color: AppColors.terracottaDeep,
                    size: 64,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.25 : 0.15,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<_Particle> _generateParticles({bool isDark = false}) {
    final random = math.Random();
    final particles = <_Particle>[];
    for (int i = 0; i < 16; i++) {
      final angle = (i / 16) * math.pi * 2;
      final speed = 0.6 + random.nextDouble() * 0.4;
      particles.add(
        _Particle(
          dx: math.cos(angle) * speed,
          dy: math.sin(angle) * speed,
          size: 5 + random.nextDouble() * 6,
          color: i % 2 == 0
              ? AppColors.terracotta
              : (isDark ? AppColors.gold : AppColors.goldTint),
        ),
      );
    }
    return particles;
  }
}

class _Particle {
  final double dx;
  final double dy;
  final double size;
  final Color color;

  _Particle({
    required this.dx,
    required this.dy,
    required this.size,
    required this.color,
  });
}

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard({required this.isDark});
  final bool isDark;

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    final cardBg = isDark
        ? AppColors.darkPaper.withValues(alpha: 0.88)
        : AppColors.paper.withValues(alpha: 0.9);
    final cardBorder = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.5)
        : Colors.white.withValues(alpha: 0.8);
    final shimmerColor = isDark
        ? AppColors.darkSand.withValues(alpha: 0.7)
        : AppColors.sand.withValues(alpha: 0.8);

    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, _) {
        return Opacity(
          opacity: _opacity.value,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        height: 16,
                        decoration: BoxDecoration(
                          color: shimmerColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 48,
                      height: 22,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 40,
                      height: 12,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
