import 'package:flutter/material.dart';

import '../models/help_request.dart';
import '../services/api.dart';
import '../theme/colors.dart';
import 'chat_page.dart';

class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key, this.isActive = true});

  final bool isActive;

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  List<HelpRequest> _requests = [];
  List<HelpRequest> _hiddenRequests = [];
  bool _loading = true;
  String? _error;
  bool _showHidden = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MessagesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await Api.get(
        '/api/requests',
        query: {'status': 'accepted'},
      );
      final requests =
          (response as List<dynamic>)
              .map((item) => HelpRequest.fromJson(item as Map<String, dynamic>))
              .toList()
            ..sort(
              (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
                a.createdAt ?? DateTime(0),
              ),
            );
final results = await Future.wait([
        Api.get('/api/requests', query: {'status': 'accepted'}),
        Api.get('/api/requests', query: {'status': 'completed'}),
        Api.get('/api/requests', query: {'hidden': 'true'}),
      ]);
      final requests = [
        for (final res in results.take(2))
          ...(res as List<dynamic>)
              .map((item) => HelpRequest.fromJson(item as Map<String, dynamic>)),
      ]..sort(
          (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          ),
        );
      final hiddenRequests = (results[2] as List<dynamic>)
          .map((item) => HelpRequest.fromJson(item as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _hiddenRequests = hiddenRequests;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = describeError(error);
        _loading = false;
      });
    }
  }

  String _otherName(HelpRequest request) =>
      request.requesterId == Api.currentUserId
      ? request.providerName
      : request.requesterName;

  void _open(HelpRequest request) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ChatPage(request: request, otherUserName: _otherName(request)),
      ),
    );
  }

  void _hide(HelpRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hide conversation?'),
        content: const Text(
          'This conversation will be hidden from your list. '
          'You can unhide it from the Hidden section.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Hide'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await Api.post('/api/requests/${request.id}/hide');
      if (!mounted) return;
      setState(() {
        _requests.removeWhere((r) => r.id == request.id);
        _hiddenRequests.insert(0, request);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeError(e))),
      );
    }
  }

  void _unhide(HelpRequest request) async {
    try {
      await Api.delete('/api/requests/${request.id}/hide');
      if (!mounted) return;
      setState(() {
        _hiddenRequests.removeWhere((r) => r.id == request.id);
        _requests.insert(0, request);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Conversations',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Messages',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(child: _body(theme)),
          ],
        ),
      ),
    );
  }

  Widget _body(ThemeData theme) {
    if (_loading && _requests.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.terracotta),
      );
    }
    if (_error != null && _requests.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 90),
            Icon(
              Icons.cloud_off_rounded,
              size: 42,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Center(
              child: FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ),
          ],
        ),
      );
    }
    if (_requests.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 88),
            const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 44,
              color: AppColors.terracotta,
            ),
            const SizedBox(height: 14),
            Text(
              'No accepted handovers yet',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Chats appear here after a request is accepted.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.terracotta,
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 130),
        itemCount: _requests.length + (_loading ? 1 : 0) + _hiddenSectionCount,
        separatorBuilder: (_, index) {
          final adjusted = index - (_loading ? 1 : 0);
          if (adjusted == _requests.length) return const SizedBox(height: 6);
          if (adjusted > _requests.length) return const SizedBox(height: 8);
          return const SizedBox(height: 10);
        },
        itemBuilder: (context, index) {
          if (index == 0 && _loading) {
            return const LinearProgressIndicator(minHeight: 2);
          }
          final adjusted = index - (_loading ? 1 : 0);
          if (adjusted < _requests.length) {
            final request = _requests[adjusted];
            return _ConversationCard(
              request: request,
              otherUserName: _otherName(request),
              onTap: () => _open(request),
              onLongPress: () => _hide(request),
            );
          }
          return _buildHiddenSection(context, theme);
        },
      ),
    );
  }

  int get _hiddenSectionCount {
    if (_hiddenRequests.isEmpty) return 0;
    return 1;
  }

  Widget _buildHiddenSection(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _showHidden = !_showHidden),
          child: Row(
            children: [
              Icon(
                _showHidden
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.keyboard_arrow_right_rounded,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 4),
              Text(
                'Hidden (${_hiddenRequests.length})',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        if (_showHidden) ...[
          const SizedBox(height: 10),
          for (final request in _hiddenRequests) ...[
            _HiddenCard(
              request: request,
              otherUserName: _otherName(request),
              onUnhide: () => _unhide(request),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.request,
    required this.otherUserName,
    required this.onTap,
    required this.onLongPress,
  });

  final HelpRequest request;
  final String otherUserName;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: isDark ? AppColors.darkPaper : AppColors.paper,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.avatarFor(
                  otherUserName,
                  isDark: isDark,
                ).withValues(alpha: 0.18),
                foregroundColor: AppColors.avatarFor(
                  otherUserName,
                  isDark: isDark,
                ),
                child: Text(
                  otherUserName.isEmpty ? '?' : otherUserName[0].toUpperCase(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      otherUserName,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      request.skillName,
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HiddenCard extends StatelessWidget {
  const _HiddenCard({
    required this.request,
    required this.otherUserName,
    required this.onUnhide,
  });

  final HelpRequest request;
  final String otherUserName;
  final VoidCallback onUnhide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMe = request.requesterId == Api.currentUserId;
    final profileImage = isMe
        ? request.providerProfileImage
        : request.requesterProfileImage;
    final avatarColor = AppColors.avatarFor(otherUserName, isDark: isDark);

    return Material(
      color: isDark
          ? AppColors.darkPaper.withValues(alpha: 0.5)
          : AppColors.paper.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? AppColors.darkBorder.withValues(alpha: 0.4)
                : AppColors.border.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: avatarColor.withValues(alpha: 0.12),
              foregroundImage: profileImage != null
                  ? NetworkImage('${Api.baseUrl}$profileImage')
                  : null,
              child: profileImage == null
                  ? Text(
                      otherUserName.isEmpty
                          ? '?'
                          : otherUserName[0].toUpperCase(),
                      style: TextStyle(
                        color: avatarColor.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    otherUserName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    request.skillName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onUnhide,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder.withValues(alpha: 0.6)
                        : AppColors.inkSoft.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  'Unhide',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
