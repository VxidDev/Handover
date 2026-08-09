import 'dart:async';

import 'package:flutter/material.dart';

import '../models/neighbor_skill.dart';
import '../services/api.dart';
import '../theme/colors.dart';
import '../widgets/radius_chip_selector.dart';
import '../widgets/skill_card.dart';

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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await Api.get('/api/skills', query: {
        'q': _query.text.trim(),
        'radius_km': _radius.toStringAsFixed(1),
        'lat': Api.demoLat.toString(),
        'lng': Api.demoLng.toString(),
      });

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
    final message = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ask ${neighbor.name.split(' ').first} for help'),
        content: TextField(
          controller: message,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'What do you need? (optional)',
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send request'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final skillId = neighbor.skillId;

      if (skillId == null) {
        throw const ApiException('Skill has no id');
      }

      await Api.post('/api/requests', body: {
        'skill_id': skillId,
        'message': message.text.trim(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request sent to ${neighbor.name.split(' ').first}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cream,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.terracotta,
          backgroundColor: Colors.white,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 130),
            children: [
              _header(context),
              const SizedBox(height: 20),
              _searchField(),
              const SizedBox(height: 18),
              _distanceCard(),
              const SizedBox(height: 18),
              _privacyNote(),
              const SizedBox(height: 26),
              _resultsHeader(context),
              const SizedBox(height: 12),
              ..._buildResults(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _greeting,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.inkFaint,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Find help nearby',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.6,
                height: 1.1,
              ),
        ),
      ],
    );
  }

  Widget _searchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.inkSoft.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: _query,
        onChanged: _onQueryChanged,
        onSubmitted: (_) => _submitSearch(),
        textInputAction: TextInputAction.search,
        style: const TextStyle(
          fontSize: 14.5,
          color: AppColors.ink,
        ),
        decoration: InputDecoration(
          hintText: 'Search a skill… e.g. plumbing',
          hintStyle: const TextStyle(
            color: AppColors.inkFaint,
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.inkFaint,
            size: 22,
          ),
          suffixIcon: _query.text.isEmpty
              ? null
              : IconButton(
                  onPressed: _clearSearch,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.inkFaint,
                  ),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 16,
          ),
        ),
      ),
    );
  }

  Widget _distanceCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.inkSoft.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.near_me_rounded,
                size: 16,
                color: AppColors.terracottaDeep,
              ),
              const SizedBox(width: 7),
              const Text(
                'Distance',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
              const Spacer(),
              Text(
                '$_radiusLabel km',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.inkSoft.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RadiusChipSelector(
            value: _radius,
            onChanged: (v) {
              setState(() => _radius = v);
              _scheduleSearch();
            },
          ),
        ],
      ),
    );
  }

  Widget _privacyNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.terracottaTint.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.terracottaTint.withValues(alpha: 0.7),
          width: 1,
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: AppColors.terracottaDeep,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Neighbors appear as approximate areas and distances. Exact locations are shared only after both sides accept.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.terracottaDeep,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultsHeader(BuildContext context) {
    return Row(
      children: [
        Text(
          'Nearby neighbors',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.sand,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            '${_results.length}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.inkSoft,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildResults() {
    if (_loading && _results.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 64),
          child: Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: AppColors.terracotta,
              ),
            ),
          ),
        ),
      ];
    }

    if (_error != null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 44),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.sand,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: AppColors.inkFaint,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.inkSoft.withValues(alpha: 0.9),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ];
    }

    if (_results.isEmpty) {
      return [
        _EmptyResults(
          hasQuery: _query.text.trim().isNotEmpty,
          onClear: _clearSearch,
        ),
      ];
    }

    return [
      if (_loading)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: AppColors.sand,
              valueColor: const AlwaysStoppedAnimation(AppColors.terracotta),
            ),
          ),
        ),
      ..._results.map(
        (n) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: SkillCard(
            neighbor: n,
            onRequest: () => _requestHelp(n),
          ),
        ),
      ),
    ];
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({
    required this.hasQuery,
    required this.onClear,
  });

  final bool hasQuery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.sand,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.8),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.search_off_rounded,
              color: AppColors.inkFaint,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No matches yet',
            style: TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasQuery
                ? 'Try a different skill or widen your radius.'
                : 'Try widening your radius to see more neighbors nearby.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.inkFaint.withValues(alpha: 0.95),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          if (hasQuery) ...[
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear_rounded, size: 18),
              label: const Text('Clear search'),
            ),
          ],
        ],
      ),
    );
  }
}