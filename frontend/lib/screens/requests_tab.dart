import 'package:flutter/material.dart';
import '../models/help_request.dart';
import '../services/api.dart';
import '../theme/colors.dart';

class RequestsTab extends StatefulWidget {
  const RequestsTab({super.key, this.isActive = true});

  /// Whether this tab is currently selected in [HomeShell]. When it becomes
  /// active the list reloads so newly sent/received requests show up.
  final bool isActive;

  @override
  State<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab> {
  List<HelpRequest> _requests = [];
  bool _loading = true;
  String? _error;
  int? _busyRequestId;

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

  @override
  Widget build(BuildContext context) {
    final received = _requests.where((r) => r.providerId == Api.currentUserId).toList();
    final sent = _requests.where((r) => r.requesterId == Api.currentUserId).toList();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('Requests')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: _buildSections(received, sent),
        ),
      ),
    );
  }

  List<Widget> _buildSections(List<HelpRequest> received, List<HelpRequest> sent) {
    if (_loading && _requests.isEmpty) {
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
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_rounded, color: AppColors.inkFaint, size: 40),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
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
    if (_requests.isEmpty) {
      return const [_EmptyState()];
    }
    return [
      if (_loading) const LinearProgressIndicator(minHeight: 2),
      if (received.isNotEmpty) _sectionHeader('Neighbors asking you', received.length),
      ...received.map((r) => _RequestCard(
            request: r,
            isReceived: true,
            busy: _busyRequestId == r.id,
            onRespond: (s) => _respond(r, s),
          )),
      if (sent.isNotEmpty) _sectionHeader('You asked for help', sent.length),
      ...sent.map((r) => _RequestCard(
            request: r,
            isReceived: false,
            busy: _busyRequestId == r.id,
            onRespond: (s) => _respond(r, s),
          )),
    ];
  }

  Widget _sectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 10),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 6),
          Text('($count)', style: const TextStyle(color: AppColors.inkFaint, fontSize: 13)),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.isReceived,
    required this.busy,
    required this.onRespond,
  });

  final HelpRequest request;
  final bool isReceived;
  final bool busy;
  final void Function(String status) onRespond;

  @override
  Widget build(BuildContext context) {
    final pending = request.status == 'pending';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.sageLight,
                child: Text(
                  isReceived
                      ? (request.requesterName.isNotEmpty ? request.requesterName[0] : '?')
                      : (request.providerName.isNotEmpty ? request.providerName[0] : '?'),
                  style: const TextStyle(color: AppColors.sage, fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isReceived ? request.requesterName : request.providerName,
                      style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'wants ${request.skillName} help',
                      style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              StatusBadge(status: request.status),
            ],
          ),
          if (request.message != null && request.message!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              request.message!,
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 13, height: 1.4),
            ),
          ],
          if (isReceived && pending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : () => onRespond('declined'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : () => onRespond('accepted'),
                    child: busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Accept'),
                  ),
                ),
              ],
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
      _ => ('Pending', AppColors.inkSoft, AppColors.sand),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 70),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.sageLight, shape: BoxShape.circle),
            child: const Icon(Icons.handshake_outlined, size: 32, color: AppColors.sage),
          ),
          const SizedBox(height: 18),
          const Text(
            'No requests yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
          const SizedBox(height: 6),
          const Text(
            'When you ask a neighbor for help — or someone asks you — it\'ll show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.inkSoft, height: 1.5),
          ),
        ],
      ),
    );
  }
}