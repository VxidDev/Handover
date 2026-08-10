import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/help_request.dart';
import '../services/api.dart';
import '../theme/colors.dart';

class RequestsTab extends StatefulWidget {
  const RequestsTab({super.key, this.isActive = true});

  final bool isActive;

  @override
  State<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab> {
  List<HelpRequest> _requests = [];
  bool _loading = true;
  String? _error;
  int? _busyRequestId;
  final Set<int> _removingIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RequestsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Api.get('/api/requests');
      final items = (res as List)
          .map((e) => HelpRequest.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _requests = items;
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

  Future<void> _respond(HelpRequest request, String status) async {
    setState(() => _busyRequestId = request.id);
    try {
      await Api.patch('/api/requests/${request.id}', body: {'status': status});
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeError(e))),
      );
    } finally {
      if (mounted) setState(() => _busyRequestId = null);
    }
  }

  Future<bool> _showCancelDialog(HelpRequest request) async {
    final name = request.providerName.split(' ').first;
    
    return await showDialog<bool>(
      context: context,
      barrierColor: AppColors.ink.withValues(alpha: 0.3),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.12),
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
                child: const Icon(Icons.undo_rounded, color: AppColors.error, size: 28),
              ),
              const SizedBox(height: 20),
              const Text(
                'Withdraw request?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No worries. You can always reach out to $name again later if you change your mind.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppColors.inkSoft.withValues(alpha: 0.85),
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
                          border: Border.all(color: AppColors.inkSoft.withValues(alpha: 0.2), width: 1),
                        ),
                        child: const Center(
                          child: Text(
                            'Keep it',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.inkSoft),
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
                            BoxShadow(color: AppColors.error.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 6)),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'Yes, withdraw',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
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
    ) ?? false;
  }

  Future<void> _cancel(HelpRequest request) async {
    final confirmed = await _showCancelDialog(request);
    if (!confirmed) return;

    HapticFeedback.mediumImpact();
    
    // Step 1: Mark as removing → triggers exit animation
    setState(() => _removingIds.add(request.id));

    final apiFuture = Api.delete('/api/requests/${request.id}');

    // Step 2: Wait for exit animation to finish
    await Future.delayed(const Duration(milliseconds: 400));

    try {
      await apiFuture;
      if (!mounted) return;
      
      // Step 3: Remove from list → space smoothly collapses
      setState(() {
        _requests.removeWhere((r) => r.id == request.id);
        _removingIds.remove(request.id);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request to ${request.providerName.split(' ').first} withdrawn.'),
            backgroundColor: AppColors.ink,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _removingIds.remove(request.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final received = _requests.where((r) => r.providerId == Api.currentUserId).toList();
    final sent = _requests.where((r) => r.requesterId == Api.currentUserId).toList();

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
            children: _buildSections(received, sent),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Handshakes',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.inkFaint,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your requests',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.6,
                height: 1.1,
              ),
        ),
      ],
    );
  }

  List<Widget> _buildSections(List<HelpRequest> received, List<HelpRequest> sent) {
    if (_loading && _requests.isEmpty) {
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
    
    if (_error != null) {
      return [
        _header(),
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.sand,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
                ),
                child: const Icon(Icons.cloud_off_rounded, color: AppColors.inkFaint, size: 28),
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
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.terracotta,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ];
    }
    
    if (_requests.isEmpty) {
      return [
        _header(),
        const SizedBox(height: 40),
        const _EmptyState(),
      ];
    }
    
    return [
      _header(),
      const SizedBox(height: 24),
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
      if (received.isNotEmpty) ...[
        _sectionHeader('Neighbors asking you', received.length),
        const SizedBox(height: 12),
        ...received.map((r) => _RequestCard(
              request: r,
              isReceived: true,
              busy: _busyRequestId == r.id,
              onRespond: (s) => _respond(r, s),
            )),
      ],
      if (sent.isNotEmpty) ...[
        if (received.isNotEmpty) const SizedBox(height: 24),
        _sectionHeader('You asked for help', sent.length),
        const SizedBox(height: 12),
        ...sent.map((r) {
          final isRemoving = _removingIds.contains(r.id);
          return _AnimatedRemoval(
            key: ValueKey(r.id),
            isRemoving: isRemoving,
            child: _RequestCard(
              request: r,
              isReceived: false,
              busy: _busyRequestId == r.id || isRemoving,
              onRespond: (s) => _respond(r, s),
              onCancel: () => _cancel(r),
            ),
          );
        }),
      ],
    ];
  }

  Widget _sectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
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
            '$count',
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
}

/// Wraps a card with smooth exit animation: fades, scales, and collapses height
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

class _AnimatedRemovalState extends State<_AnimatedRemoval> with SingleTickerProviderStateMixin {
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
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInCubic),
    );
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
        // When not removing, just show the child normally
        if (_controller.value == 0.0 && !widget.isRemoving) {
          return child!;
        }

        return SizeTransition(
          sizeFactor: _heightFactor.drive(Tween(begin: 1.0, end: 0.0).chain(
            CurveTween(curve: Curves.easeInOut),
          )),
          axisAlignment: -1.0,
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
  });

  final HelpRequest request;
  final bool isReceived;
  final bool busy;
  final void Function(String status) onRespond;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final pending = request.status == 'pending';
    final name = isReceived ? request.requesterName : request.providerName;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    
    final avatarBg = isReceived ? AppColors.terracottaTint : AppColors.sageLight;
    final avatarFg = isReceived ? AppColors.terracottaDeep : AppColors.sage;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.paper.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.inkSoft.withValues(alpha: 0.05),
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
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                    width: 1,
                  ),
                ),
                child: Text(
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
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'wants help with ${request.skillName}',
                      style: TextStyle(
                        color: AppColors.inkSoft.withValues(alpha: 0.9),
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
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
                color: AppColors.sand.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                request.message!,
                style: TextStyle(
                  color: AppColors.inkSoft.withValues(alpha: 0.95),
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
                      side: BorderSide(color: AppColors.error.withValues(alpha: 0.2)),
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
                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      'accepted' => ('Accepted', AppColors.success, AppColors.sageLight),
      'declined' => ('Declined', AppColors.error, AppColors.terracottaTint),
      'cancelled' => ('Cancelled', AppColors.inkSoft, AppColors.sand),
      _ => ('Pending', AppColors.inkSoft, AppColors.sand),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: bg.withValues(alpha: 0.8),
          width: 1,
        ),
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
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.sageLight.withValues(alpha: 0.6),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.8),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.handshake_outlined,
              size: 32,
              color: AppColors.sage,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No requests yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'When you ask a neighbor for help — or someone asks you — it\'ll show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.inkSoft.withValues(alpha: 0.9),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}