import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

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
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.ink.withValues(alpha: 0.3),
      builder: (ctx) => _RequestHelpDialog(neighbor: neighbor),
    );

    if (confirmed != true) return;

    try {
      final skillId = neighbor.skillId;

      if (skillId == null) {
        throw const ApiException('Skill has no id');
      }

      await Api.post('/api/requests', body: {
        'skill_id': skillId,
        'message': neighbor.blurb, // Or however you pass the message
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('High five sent to ${neighbor.name.split(' ').first}! ✋'),
          backgroundColor: AppColors.ink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
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
          child: StaggeredEntrance(
            duration: const Duration(milliseconds: 1000),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 130),
              children: [
                StaggeredItem(index: 0, child: _header(context)),
                const SizedBox(height: 20),
                StaggeredItem(index: 1, child: _searchField()),
                const SizedBox(height: 18),
                StaggeredItem(index: 2, child: _distanceCard()),
                const SizedBox(height: 18),
                StaggeredItem(index: 3, child: _privacyNote()),
                const SizedBox(height: 26),
                StaggeredItem(index: 4, child: _resultsHeader(context)),
                const SizedBox(height: 12),
                ..._buildResults(startIndex: 5),
              ],
            ),
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

  List<Widget> _buildResults({int startIndex = 5}) {
    if (_loading && _results.isEmpty) {
      return [
        StaggeredItem(
          index: startIndex,
          child: const Padding(
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
        ),
      ];
    }

    if (_error != null) {
      return [
        StaggeredItem(
          index: startIndex,
          child: Padding(
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

    return [
      if (_loading)
        StaggeredItem(
          index: startIndex,
          child: Padding(
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
        ),
      ..._results.asMap().entries.map((entry) {
        final idx = entry.key;
        final n = entry.value;
        
        final itemIndex = startIndex + idx + (_loading ? 1 : 0);
        
        return StaggeredItem(
          index: itemIndex,
          begin: const Offset(0, 0.08),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: SkillCard(
              neighbor: n,
              onRequest: () => _requestHelp(n),
            ),
          ),
        );
      }),
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

class _RequestHelpDialog extends StatefulWidget {
  const _RequestHelpDialog({required this.neighbor});

  final NeighborSkill neighbor;

  @override
  State<_RequestHelpDialog> createState() => _RequestHelpDialogState();
}

class _RequestHelpDialogState extends State<_RequestHelpDialog> with SingleTickerProviderStateMixin {
  final _message = TextEditingController();
  bool _sending = false;
  bool _success = false;

  late final Animation<double> _successScale;
  late final Animation<double> _successFade;
  late final AnimationController _highFiveController;

  @override
  void initState() {
    super.initState();
    _highFiveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _successScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _highFiveController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOutBack),
      ),
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

  void _send() {
    if (_sending) return;
    setState(() => _sending = true);

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _success = true);
      _highFiveController.forward();

      Future.delayed(const Duration(milliseconds: 2200), () {
        if (!mounted) return;
        Navigator.of(context).pop(true);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.6),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.12),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: _success
            ? _buildSuccessAnimation()
            : _buildRequestForm(),
      ),
    );
  }

  Widget _buildSuccessAnimation() {
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
            child: const Text(
              'High five sent! ✋',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
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
                color: AppColors.inkSoft.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestForm() {
    final firstName = widget.neighbor.name.split(' ').first;
    final avatarColor = AppColors.avatarFor(widget.neighbor.name);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: avatarColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  widget.neighbor.name.isNotEmpty
                      ? widget.neighbor.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: avatarColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Ask $firstName for help',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'They\'ll get a notification and can accept or decline.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.inkSoft.withValues(alpha: 0.8),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.inkSoft.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _message,
              autofocus: true,
              maxLines: 3,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.ink,
                height: 1.4,
              ),
              decoration: InputDecoration(
                hintText: 'What do you need help with? (optional)',
                hintStyle: TextStyle(
                  color: AppColors.inkFaint.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: AppColors.inkSoft.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkSoft,
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
                  onTap: _sending ? null : _send,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _sending
                          ? AppColors.terracotta.withValues(alpha: 0.6)
                          : AppColors.terracotta,
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.terracotta.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send_rounded, size: 16, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Send request',
                                  style: TextStyle(
                                    fontSize: 14,
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

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value;

        // Generate particles exactly once at the clap moment
        if (t >= 0.35 && !_triggered) {
          _triggered = true;
          _particles = _generateParticles();
        }

        double leftX, leftY, rightX, rightY, scale, leftRot, rightRot;
        double rippleScale, rippleOpacity;
        double particleProgress;

        if (t < 0.35) {
          // Phase 1: Approach - hands tilt INWARD toward each other
          final p = Curves.easeOutCubic.transform(t / 0.35);
          
          leftX = -65 + (62 * p);
          leftY = 60 - (70 * p);
          rightX = 65 - (62 * p);
          rightY = 60 - (70 * p);
          
          // Tilting inward toward each other
          leftRot = 0.4 - (0.6 * p);  // 0.4 → -0.2 (tilts left)
          rightRot = -0.4 + (0.6 * p); // -0.4 → 0.2 (tilts right)
          
          scale = 1.0;
          rippleScale = 0;
          rippleOpacity = 0;
          particleProgress = 0;
        } else if (t < 0.65) {
          // Phase 2: Impact & Recoil - hands tilt OUTWARD (opposite directions)
          final p = (t - 0.35) / 0.30;
          final recoil = Curves.easeOutQuart.transform(p);
          
          leftX = 4 - (34 * recoil);
          leftY = -10 + (10 * recoil);
          rightX = -4 + (34 * recoil);
          rightY = -10 + (10 * recoil);
          
          // Left hand tilts MORE left, right hand tilts MORE right
          leftRot = -0.2 - (0.15 * recoil);   // -0.2 → -0.35
          rightRot = 0.2 + (0.15 * recoil);    // 0.2 → 0.35
          
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
          // Phase 3: Settle
          leftX = -30; leftY = 0; leftRot = -0.35;
          rightX = 30; rightY = 0; rightRot = 0.35;
          scale = 1.0;
          rippleScale = 0;
          rippleOpacity = 0;
          particleProgress = 1.0;
        }

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Ripple
            if (rippleOpacity > 0.01)
              Transform.scale(
                scale: rippleScale,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.terracotta.withValues(alpha: rippleOpacity * 0.6),
                      width: 4,
                    ),
                  ),
                ),
              ),

            // Particles
            for (final p in _particles)
              Transform.translate(
                offset: Offset(
                  p.dx * particleProgress * 80,
                  p.dy * particleProgress * 80 - (particleProgress * 25),
                ),
                child: Transform.scale(
                  scale: (1 + particleProgress * 0.5) * (1 - particleProgress * 0.8),
                  child: Container(
                    width: p.size,
                    height: p.size,
                    decoration: BoxDecoration(
                      color: p.color.withValues(alpha: (1 - particleProgress).clamp(0.0, 1.0)),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),

            // Left Hand
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
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  )
                ),
              ),
            ),

            // Right Hand (Identical icon, symmetrical rotation)
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
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: Offset(0, 4),
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

  List<_Particle> _generateParticles() {
    final random = math.Random();
    final particles = <_Particle>[];
    for (int i = 0; i < 16; i++) {
      final angle = (i / 16) * math.pi * 2;
      final speed = 0.6 + random.nextDouble() * 0.4;
      particles.add(_Particle(
        dx: math.cos(angle) * speed,
        dy: math.sin(angle) * speed,
        size: 5 + random.nextDouble() * 6,
        color: i % 2 == 0 ? AppColors.terracotta : AppColors.goldTint,
      ));
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