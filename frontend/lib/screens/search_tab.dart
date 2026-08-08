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

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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
        SnackBar(content: Text('Request sent to ${neighbor.name.split(' ').first}')),
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
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            children: [
              const Text(
                'Good afternoon 👋',
                style: TextStyle(fontSize: 13, color: AppColors.inkFaint, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text('Find help nearby', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 20),
              TextField(
                controller: _query,
                onChanged: (_) => _scheduleSearch(),
                decoration: const InputDecoration(
                  hintText: 'Search a skill… e.g. plumbing',
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.inkFaint),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.near_me_rounded, size: 16, color: AppColors.terracottaDeep),
                  const SizedBox(width: 6),
                  const Text(
                    'Within',
                    style: TextStyle(fontSize: 13, color: AppColors.inkSoft, fontWeight: FontWeight.w600),
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
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.terracottaTint,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.terracottaDeep),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Neighbors show as an approximate grid area and distance. Exact locations reveal only after both sides accept.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.terracottaDeep, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text('Nearby neighbors', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 6),
                  Text('(${_results.length})', style: const TextStyle(color: AppColors.inkFaint, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 12),
              ..._buildResults(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildResults() {
    if (_loading && _results.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_error != null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_rounded, color: AppColors.inkFaint, size: 40),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.inkSoft, fontSize: 13, height: 1.4),
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
    if (_results.isEmpty) {
      return const [_EmptyResults()];
    }
    return [
      if (_loading) const LinearProgressIndicator(minHeight: 2),
      ..._results.map((n) => SkillCard(neighbor: n, onRequest: () => _requestHelp(n))),
    ];
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.sand, shape: BoxShape.circle),
            child: const Icon(Icons.search_off_rounded, color: AppColors.inkFaint, size: 26),
          ),
          const SizedBox(height: 14),
          const Text(
            'No matches yet',
            style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 14.5),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try widening your radius or a different skill.',
            style: TextStyle(color: AppColors.inkFaint, fontSize: 12.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}