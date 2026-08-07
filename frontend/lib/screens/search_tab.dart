import 'package:flutter/material.dart';
import '../data/mock_neighbors.dart';
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

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List get _results => mockNeighbors
      .where((n) => n.km <= _radius)
      .where((n) =>
          _query.text.trim().isEmpty ||
          n.skill.toLowerCase().contains(_query.text.trim().toLowerCase()))
      .toList();

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: ListView(
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
              onChanged: (_) => setState(() {}),
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
              onChanged: (v) => setState(() => _radius = v),
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
                Text('(${results.length})', style: const TextStyle(color: AppColors.inkFaint, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 12),
            if (results.isEmpty)
              const _EmptyResults()
            else
              ...results.map((n) => SkillCard(neighbor: n)),
          ],
        ),
      ),
    );
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