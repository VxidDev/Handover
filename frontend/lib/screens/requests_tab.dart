import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/help_request.dart';
import '../services/api.dart';
import '../theme/colors.dart';
import 'chat_page.dart';

class RequestsTab extends StatefulWidget {
  const RequestsTab({super.key, this.isActive = true});

  final bool isActive;

  @override
  State<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final Map<int, List<HelpRequest>> _requests = {0: [], 1: [], 2: []};
  final Map<int, bool> _loading = {0: true, 1: true, 2: true};
  final Map<int, String?> _error = {0: null, 1: null, 2: null};
  final Set<int> _removingIds = {};
  int? _busyRequestId;
  int _currentTabIndex = 0;

  static const _tabs = [
    (label: 'Sent', path: '/api/requests?role=sent&status=pending&amount=50'),
    (label: 'Cancelled', path: '/api/requests?status=cancelled&amount=50'),
    (
      label: 'Received',
      path: '/api/requests?role=received&active=true&amount=50',
    ),
    (label: 'Completed', path: '/api/requests?status=completed&amount=50'),
  ];

  int get _totalCount =>
      _requests.values.fold(0, (sum, list) => sum + list.length);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
        final idx = _tabController.index;
        if (_requests[idx]!.isEmpty && !_loading[idx]! && _error[idx] == null) {
          _load(idx);
        }
      }
    });
    _loadAll();
  }

  @override
  void didUpdateWidget(covariant RequestsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _loadAll();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadAll() {
    for (var i = 0; i < _tabs.length; i++) {
      _load(i);
    }
  }

  Future<void> _load(int tabIndex) async {
    setState(() {
      _loading[tabIndex] = true;
      _error[tabIndex] = null;
    });
    try {
      final res = await Api.get(_tabs[tabIndex].path);
      final items = (res as List)
          .map((e) => HelpRequest.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _requests[tabIndex] = items;
        _loading[tabIndex] = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error[tabIndex] = describeError(e);
        _loading[tabIndex] = false;
      });
    }
  }

  Future<void> _respond(
    HelpRequest request,
    String status, {
    bool? sharePhone,
  }) async {
    setState(() => _busyRequestId = request.id);
    try {
      await Api.patch(
        '/api/requests/${request.id}',
        body: {
          'status': status,
          if (status == 'accepted') 'share_phone': sharePhone ?? false,
        },
      );
      _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _busyRequestId = null);
    }
  }

  Future<void> _accept(HelpRequest request) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final name = request.requesterName.split(' ').first;

    var sharePhone = false;

    final result = await showDialog<bool>(
      context: context,
      barrierColor: isDark
          ? Colors.black.withValues(alpha: 0.6)
          : AppColors.ink.withValues(alpha: 0.4),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final dialogBg = isDark ? AppColors.darkPaper : AppColors.paper;
          final dialogBorder = isDark
              ? AppColors.darkBorder.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.8);

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: dialogBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: dialogBorder, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon and title row
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.sage.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.handshake_rounded,
                          color: AppColors.sage,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Accept handover?',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Description
                  Text(
                    'A private chat with $name will open in Messages. You can coordinate the handover there.',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 14,
                      height: 1.5,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Phone sharing option
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSand.withValues(alpha: 0.5)
                          : AppColors.sand.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: sharePhone
                            ? AppColors.sage.withValues(alpha: 0.3)
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
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
                                color: AppColors.sage.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.phone_outlined,
                                size: 17,
                                color: AppColors.sage,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Share phone number',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    'Revealed only for this handover',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.55),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Transform.scale(
                              scale: 0.85,
                              child: Switch(
                                value: sharePhone,
                                onChanged: (value) =>
                                    setDialogState(() => sharePhone = value),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                theme.colorScheme.onSurface.withValues(alpha: 0.7),
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
                          onPressed: () => Navigator.pop(dialogContext, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.sage,
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
                          child: const Text('Accept'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (result == null || !result || !mounted) return;
    await _respond(request, 'accepted', sharePhone: sharePhone);
  }

  Future<bool> _showCancelDialog(HelpRequest request) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final name = request.providerName.split(' ').first;

    final dialogBg = isDark ? AppColors.darkPaper : AppColors.paper;
    final dialogBorder = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.6);
    final dialogShadow = isDark
        ? Colors.black.withValues(alpha: 0.3)
        : AppColors.ink.withValues(alpha: 0.12);
    final cancelBorder = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.6)
        : AppColors.inkSoft.withValues(alpha: 0.2);

    return await showDialog<bool>(
          context: context,
          barrierColor: isDark
              ? Colors.black.withValues(alpha: 0.5)
              : AppColors.ink.withValues(alpha: 0.3),
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(24),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.undo_rounded,
                      color: AppColors.error,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Withdraw request?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No worries. You can always reach out to $name again later if you change your mind.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(ctx, false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: cancelBorder, width: 1),
                            ),
                            child: Center(
                              child: Text(
                                'Keep it',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(ctx, true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.error.withValues(alpha: 0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'Yes, withdraw',
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
              ),
            ),
          ),
        ) ??
        false;
  }

  Future<void> _cancel(HelpRequest request) async {
    final confirmed = await _showCancelDialog(request);
    if (!confirmed) return;

    HapticFeedback.mediumImpact();
    setState(() => _removingIds.add(request.id));

    final apiFuture = Api.delete('/api/requests/${request.id}');
    await Future.delayed(const Duration(milliseconds: 400));

    try {
      await apiFuture;
      if (!mounted) return;

      setState(() {
        for (final key in _requests.keys) {
          _requests[key]!.removeWhere((r) => r.id == request.id);
        }
        _removingIds.remove(request.id);
      });

      if (mounted) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Request to ${request.providerName.split(' ').first} withdrawn.',
              style: TextStyle(
                color: isDark ? AppColors.darkInk : AppColors.cream,
                fontSize: 13.5,
              ),
            ),
            backgroundColor: isDark ? AppColors.darkPaper : AppColors.ink,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _removingIds.remove(request.id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  String _otherName(HelpRequest request) =>
      request.requesterId == Api.currentUserId
      ? request.providerName
      : request.requesterName;

  Future<void> _complete(HelpRequest request) async {
    setState(() => _busyRequestId = request.id);
    try {
      await Api.patch(
        '/api/requests/${request.id}',
        body: {'status': 'completed'},
      );
      _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Handover marked as completed.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _busyRequestId = null);
    }
  }

  void _openChat(HelpRequest request) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ChatPage(request: request, otherUserName: _otherName(request)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 18, 20, 0),
              child: _header(),
            ),
            const SizedBox(height: 20),
            _buildTabBar(isDark),
            const SizedBox(height: 4),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: List.generate(
                  _tabs.length,
                  (i) => _buildTabContent(i),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Text(
                  'Handshakes',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Text(
                  'Your requests',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.6,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 20, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.terracotta.withValues(alpha: 0.18)
                : AppColors.terracottaTint,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: isDark
                  ? AppColors.terracotta.withValues(alpha: 0.3)
                  : AppColors.terracottaTint.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          child: Text(
            '$_totalCount',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.terracotta : AppColors.terracottaDeep,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 52,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSand.withValues(alpha: 0.6)
              : AppColors.sand.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isDark
                ? AppColors.darkBorder.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tabWidth = constraints.maxWidth / _tabs.length;

            return Stack(
              children: [
                // Sliding pill — no margin, fills full tab width
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  left: _currentTabIndex * tabWidth,
                  width: tabWidth,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkPaper : Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.95),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.2)
                              : AppColors.inkSoft.withValues(alpha: 0.08),
                          blurRadius: 16,
                          spreadRadius: -2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),

                // Tabs
                Positioned.fill(
                  child: Row(
                    children: List.generate(_tabs.length, (i) {
                      final tab = _tabs[i];
                      final count = _requests[i]?.length ?? 0;
                      final isLoading = _loading[i] ?? false;
                      final isSelected = _currentTabIndex == i;

                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() {
                              _currentTabIndex = i;
                            });
                            _tabController.animateTo(i);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutQuart,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      letterSpacing: -0.1,
                                      height: 1.2,
                                      color: isSelected
                                          ? (isDark
                                                ? AppColors.darkInk
                                                : AppColors.ink)
                                          : (isDark
                                                    ? AppColors.darkInk
                                                    : AppColors.ink)
                                                .withValues(alpha: 0.5),
                                    ),
                                    child: Text(
                                      tab.label,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                                if (count > 0 && !isLoading) ...[
                                  const SizedBox(width: 6),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutQuart,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.terracotta.withValues(
                                              alpha: 0.14,
                                            )
                                          : (isDark
                                                    ? AppColors.darkInk
                                                    : AppColors.ink)
                                                .withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(100),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.terracotta.withValues(
                                                alpha: 0.2,
                                              )
                                            : Colors.transparent,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      '$count',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? (isDark
                                                  ? AppColors.terracotta
                                                  : AppColors.terracottaDeep)
                                            : (isDark
                                                      ? AppColors.darkInk
                                                      : AppColors.ink)
                                                  .withValues(alpha: 0.55),
                                        height: 1.0,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTabContent(int tabIndex) {
    final requests = _requests[tabIndex]!;
    final loading = _loading[tabIndex]!;
    final error = _error[tabIndex];

    return RefreshIndicator(
      color: AppColors.terracotta,
      backgroundColor: Theme.of(context).colorScheme.surface,
      onRefresh: () => _load(tabIndex),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 130),
        children: _buildList(tabIndex, requests, loading, error),
      ),
    );
  }

  List<Widget> _buildList(
    int tabIndex,
    List<HelpRequest> requests,
    bool loading,
    String? error,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (loading && requests.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 70),
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

    if (error != null) {
      return [_errorState(error, () => _load(tabIndex), isDark, theme)];
    }

    if (requests.isEmpty) {
      return [_EmptyState(tabIndex: tabIndex)];
    }

    final progressBg = isDark ? AppColors.darkSand : AppColors.sand;
    final isSentTab = tabIndex == 0;

    return [
      if (loading)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: progressBg,
              valueColor: const AlwaysStoppedAnimation(AppColors.terracotta),
            ),
          ),
        ),
      ...requests.map((r) {
        final isRemoving = _removingIds.contains(r.id);
        final canOpenChat = r.status == 'accepted' || r.status == 'completed';
        final card = _RequestCard(
          request: r,
          isReceived: tabIndex == 2,
          busy: _busyRequestId == r.id || isRemoving,
          onRespond: (s) => s == 'accepted' ? _accept(r) : _respond(r, s),
          onCancel: isSentTab ? () => _cancel(r) : null,
          onTap: canOpenChat ? () => _openChat(r) : null,
          onComplete: (!isSentTab || r.status != 'accepted') ? null : () => _complete(r),
        );

        if (isSentTab) {
          return _AnimatedRemoval(
            key: ValueKey(r.id),
            isRemoving: isRemoving,
            child: card,
          );
        }
        return card;
      }),
    ];
  }

  Widget _errorState(
    String error,
    VoidCallback retry,
    bool isDark,
    ThemeData theme,
  ) {
    final errorIconBg = isDark ? AppColors.darkSand : AppColors.sand;
    final errorIconBorder = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.8);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: errorIconBg,
              shape: BoxShape.circle,
              border: Border.all(color: errorIconBorder, width: 1.5),
            ),
            child: Icon(
              Icons.cloud_off_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try again'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.terracotta,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedRemoval extends StatefulWidget {
  const _AnimatedRemoval({
    super.key,
    required this.isRemoving,
    required this.child,
  });

  final bool isRemoving;
  final Widget child;

  @override
  State<_AnimatedRemoval> createState() => _AnimatedRemovalState();
}

class _AnimatedRemovalState extends State<_AnimatedRemoval>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _heightFactor;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _heightFactor = _controller.drive(CurveTween(curve: Curves.easeInOut));
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInCubic));
  }

  @override
  void didUpdateWidget(covariant _AnimatedRemoval oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRemoving && !oldWidget.isRemoving) {
      _controller.forward();
    } else if (!widget.isRemoving && oldWidget.isRemoving) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_controller.value == 0.0 && !widget.isRemoving) {
          return child!;
        }

        return SizeTransition(
          sizeFactor: _heightFactor.drive(
            Tween(
              begin: 1.0,
              end: 0.0,
            ).chain(CurveTween(curve: Curves.easeInOut)),
          ),
          alignment: Alignment.topCenter,
          child: FadeTransition(
            opacity: _opacity,
            child: ScaleTransition(
              scale: _scale,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.isReceived,
    required this.busy,
    required this.onRespond,
    this.onCancel,
    this.onTap,
    this.onComplete,
  });

  final HelpRequest request;
  final bool isReceived;
  final bool busy;
  final void Function(String status) onRespond;
  final VoidCallback? onCancel;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;

  String _timeAgo(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 30) return '${diff.inDays}d';
    return '${date.month}/${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pending = request.status == 'pending';
    final name = isReceived ? request.requesterName : request.providerName;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final profileImage = isReceived
        ? request.requesterProfileImage
        : request.providerProfileImage;

    final avatarBg = isReceived
        ? (isDark
              ? AppColors.terracotta.withValues(alpha: 0.18)
              : AppColors.terracottaTint)
        : (isDark
              ? AppColors.sage.withValues(alpha: 0.18)
              : AppColors.sageLight);

    final avatarFg = isReceived
        ? (isDark ? AppColors.terracotta : AppColors.terracottaDeep)
        : (isDark ? AppColors.sage : AppColors.sage);

    final cardBg = isDark
        ? AppColors.darkPaper.withValues(alpha: 0.92)
        : AppColors.paper.withValues(alpha: 0.92);

    final cardBorder = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.8);

    final cardShadow = isDark
        ? Colors.black.withValues(alpha: 0.25)
        : AppColors.inkSoft.withValues(alpha: 0.05);

    final messageBg = isDark
        ? AppColors.darkSand.withValues(alpha: 0.6)
        : AppColors.sand.withValues(alpha: 0.5);

    final card = Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: cardShadow,
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: avatarBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: cardBorder, width: 1),
                ),
                child: profileImage != null
                    ? ClipOval(
                        child: Image.network(
                          '${Api.baseUrl}$profileImage',
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Text(
                            initial,
                            style: TextStyle(
                              color: avatarFg,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      )
                    : Text(
                        initial,
                        style: TextStyle(
                          color: avatarFg,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'wants help with ${request.skillName}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                    if (_timeAgo(request.createdAt).isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        _timeAgo(request.createdAt),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.45,
                          ),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: request.status),
            ],
          ),
          if (request.message != null && request.message!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: messageBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                request.message!,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ),
          ],
          if (isReceived && pending) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : () => onRespond('declined'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.2),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : () => onRespond('accepted'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.sage,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
          if (!isReceived && pending) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onCancel,
                icon: const Icon(Icons.undo_rounded, size: 18),
                label: const Text('Withdraw request'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.2),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
          if (!isReceived && request.status == 'accepted' && onComplete != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : onComplete,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Mark as completed'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.sage,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: card,
      );
    }
    return card;
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (label, color, bg) = switch (status) {
      'accepted' => (
        'Accepted',
        AppColors.success,
        isDark ? AppColors.sage.withValues(alpha: 0.18) : AppColors.sageLight,
      ),
      'completed' => (
        'Completed',
        AppColors.sage,
        isDark ? AppColors.sage.withValues(alpha: 0.18) : AppColors.sageLight,
      ),
      'declined' => (
        'Declined',
        AppColors.error,
        isDark
            ? AppColors.terracotta.withValues(alpha: 0.18)
            : AppColors.terracottaTint,
      ),
      'cancelled' => (
        'Cancelled',
        isDark ? AppColors.darkInkFaint : AppColors.inkSoft,
        isDark ? AppColors.darkSand : AppColors.sand,
      ),
      _ => (
        'Pending',
        isDark ? AppColors.darkInkFaint : AppColors.inkSoft,
        isDark ? AppColors.darkSand : AppColors.sand,
      ),
    };

    final bgAlpha = isDark ? 0.25 : 0.6;
    final borderAlpha = isDark ? 0.4 : 0.8;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: bg.withValues(alpha: borderAlpha), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tabIndex});

  final int tabIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final iconBg = isDark
        ? AppColors.sage.withValues(alpha: 0.18)
        : AppColors.sageLight.withValues(alpha: 0.6);

    final iconBorder = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.5)
        : Colors.white.withValues(alpha: 0.8);

    final messages = [
      ('No sent requests', "Requests you send to neighbors will appear here."),
      (
        'No cancelled requests',
        "Withdrawn or cancelled requests will appear here.",
      ),
      (
        'No received requests',
        "When neighbors ask you for help, their requests will appear here.",
      ),
      (
        'No completed handovers',
        "Handovers you've marked as completed will appear here.",
      ),
    ];

    final (title, subtitle) = messages[tabIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
              border: Border.all(color: iconBorder, width: 1.5),
            ),
            child: Icon(
              Icons.handshake_outlined,
              size: 32,
              color: isDark ? AppColors.sage : AppColors.sage,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
