import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/chat_message.dart';
import '../models/help_request.dart';
import '../services/api.dart';
import '../theme/colors.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.request,
    required this.otherUserName,
  });

  final HelpRequest request;
  final String otherUserName;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _composer = TextEditingController();
  final _scrollController = ScrollController();
  final Map<int, ChatMessage> _messagesById = {};
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _reconnectTimer;
  String? _phone;
  String? _error;
  bool _connecting = true;
  bool _sending = false;
  bool _disposed = false;
  bool _fallbackLoaded = false;
  int _connectionGeneration = 0;
  String _status = 'accepted';
  bool _completing = false;

  List<ChatMessage> get _messages =>
      _messagesById.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  @override
  void initState() {
    super.initState();
    _status = widget.request.status;
    _connect();
  }

  Future<void> _connect() async {
    final generation = ++_connectionGeneration;
    _reconnectTimer?.cancel();
    await _socketSubscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    if (!_disposed && mounted) {
      setState(() {
        _connecting = true;
        _error = null;
      });
    }

    try {
      final response =
          await Api.post('/api/requests/${widget.request.id}/room-token')
              as Map<String, dynamic>;
      if (_disposed || generation != _connectionGeneration) return;
      final contact = response['contact_info'] as Map<String, dynamic>?;
      final channel = WebSocketChannel.connect(
        Api.roomWebSocketUri(widget.request.id, response['token'] as String),
      );
      _channel = channel;
      if (mounted) {
        setState(() {
          _phone = contact?['phone'] as String?;
          _connecting = false;
        });
      }
      _socketSubscription = channel.stream.listen(
        _handleSocketEvent,
        onError: (_) => _socketEnded(generation),
        onDone: () => _socketEnded(generation),
        cancelOnError: true,
      );
    } catch (error) {
      if (_disposed || generation != _connectionGeneration) return;
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = describeError(error);
        });
      }
      await _loadFallbackHistory();
      _scheduleReconnect(generation);
    }
  }

  void _handleSocketEvent(dynamic event) {
    try {
      final payload = jsonDecode(event as String) as Map<String, dynamic>;
      if (mounted && (_connecting || _error != null)) {
        setState(() {
          _connecting = false;
          _error = null;
        });
      }
      final type = payload['type'];
      if (type == 'history') {
        _addMessages(
          (payload['messages'] as List<dynamic>).map(
            (item) => ChatMessage.fromJson(item as Map<String, dynamic>),
          ),
        );
      } else if (type == 'message') {
        _addMessages([
          ChatMessage.fromJson(payload['message'] as Map<String, dynamic>),
        ]);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'A chat update could not be read.');
    }
  }

  void _addMessages(Iterable<ChatMessage> messages) {
    if (!mounted) return;
    setState(() {
      for (final message in messages) {
        _messagesById[message.id] = message;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _socketEnded(int generation) async {
    if (_disposed || generation != _connectionGeneration) return;
    if (mounted) {
      setState(() {
        _connecting = true;
        _channel = null;
        _error = 'Connection paused. Reconnecting…';
      });
    }
    await _loadFallbackHistory();
    _scheduleReconnect(generation);
  }

  void _scheduleReconnect(int generation) {
    if (_disposed || generation != _connectionGeneration) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), _connect);
  }

  Future<void> _loadFallbackHistory() async {
    if (_fallbackLoaded) return;
    _fallbackLoaded = true;
    try {
      final response = await Api.get(
        '/api/requests/${widget.request.id}/messages',
      );
      if (_disposed) return;
      final rawMessages = response is List<dynamic>
          ? response
          : (response as Map<String, dynamic>)['messages'] as List<dynamic>? ??
                [];
      _addMessages(
        rawMessages.map(
          (item) => ChatMessage.fromJson(item as Map<String, dynamic>),
        ),
      );
    } catch (_) {
      _fallbackLoaded = false;
    }
  }

  void _send() {
    final body = _composer.text.trim();
    if (body.isEmpty || body.length > 2000 || _channel == null || _sending) {
      return;
    }
    setState(() => _sending = true);
    try {
      _channel!.sink.add(jsonEncode({'type': 'message', 'body': body}));
      _composer.clear();
      setState(() => _sending = false);
    } catch (_) {
      setState(() {
        _sending = false;
        _error = 'Message not sent. Wait for the chat to reconnect.';
      });
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finishHandover() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final firstName = widget.otherUserName.split(' ').first;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: isDark
          ? Colors.black.withValues(alpha: 0.6)
          : AppColors.ink.withValues(alpha: 0.4),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkPaper : AppColors.paper,
            borderRadius: BorderRadius.circular(28),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.sage.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  color: AppColors.sage,
                  size: 28,
                ),
              ),
              const SizedBox(height: 18),

              Text(
                'Mark as completed?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Nice work helping $firstName! The handover will close and move to Completed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),

              // History info card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSand.withValues(alpha: 0.5)
                      : AppColors.sand.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 17,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Chat history stays available anytime.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder.withValues(alpha: 0.6)
                                : AppColors.inkSoft.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Not yet',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7),
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
                          color: AppColors.sage,
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.sage.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'Complete',
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
    );

    if (confirmed != true || !mounted) return;

    HapticFeedback.lightImpact();
    setState(() => _completing = true);
    try {
      await Api.patch(
        '/api/requests/${widget.request.id}',
        body: {'status': 'completed'},
      );
      if (mounted) {
        setState(() => _status = 'completed');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Handover marked as completed.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeError(e))));
      }
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  Future<void> _withdrawHandover() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final firstName = widget.otherUserName.split(' ').first;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: isDark
          ? Colors.black.withValues(alpha: 0.6)
          : AppColors.ink.withValues(alpha: 0.4),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkPaper : AppColors.paper,
            borderRadius: BorderRadius.circular(28),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.undo_rounded,
                  color: AppColors.error,
                  size: 26,
                ),
              ),
              const SizedBox(height: 18),

              Text(
                'Withdraw from handover?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$firstName will be notified and this chat will close.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),

              // Karma impact card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSand.withValues(alpha: 0.5)
                      : AppColors.sand.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.eco_outlined,
                      size: 17,
                      color: isDark ? AppColors.terracotta : AppColors.terracottaDeep,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Karma impact',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                    const Text(
                      '−1',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.error,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder.withValues(alpha: 0.6)
                                : AppColors.inkSoft.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Keep it',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7),
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
                              color: AppColors.error.withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'Withdraw',
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
    );

    if (confirmed != true || !mounted) return;

    HapticFeedback.mediumImpact();
    setState(() => _completing = true);
    try {
      await Api.patch(
        '/api/requests/${widget.request.id}',
        body: {'status': 'cancelled'},
      );
      if (mounted) {
        setState(() => _status = 'cancelled');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Handover withdrawn.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeError(e))));
      }
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _connectionGeneration++;
    _reconnectTimer?.cancel();
    _socketSubscription?.cancel();
    _channel?.sink.close();
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAccepted = _status == 'accepted';
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherUserName),
            Text(
              widget.request.skillName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
        actions: [
          if (isAccepted)
            TextButton.icon(
              onPressed: _completing ? null : _withdrawHandover,
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Withdraw'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
            ),
          if (isAccepted)
            TextButton.icon(
              onPressed: _completing ? null : _finishHandover,
              icon: _completing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.sage,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline, size: 20),
              label: const Text('Finish'),
              style: TextButton.styleFrom(foregroundColor: AppColors.sage),
            ),
          if (!isAccepted && _status == 'completed')
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  'Completed',
                  style: TextStyle(
                    color: AppColors.sage,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                if (_phone != null && _phone!.isNotEmpty)
                  _ContactBanner(phone: _phone!, name: widget.otherUserName),
                _SafetyNotice(connecting: _connecting, error: _error),
                Expanded(child: _messageList()),
                _Composer(
                  controller: _composer,
                  enabled: !_connecting && _channel != null && isAccepted,
                  sending: _sending,
                  onSend: _send,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _messageList() {
    final messages = _messages;
    if (_connecting && messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.terracotta),
      );
    }
    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Start the conversation about this handover.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      itemCount: messages.length,
      itemBuilder: (context, index) => _MessageBubble(
        message: messages[index],
        mine: messages[index].senderId == Api.currentUserId,
      ),
    );
  }
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice({required this.connecting, required this.error});

  final bool connecting;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            error != null ? Icons.sync_problem_rounded : Icons.shield_outlined,
            size: 14,
            color: error != null ? AppColors.busy : AppColors.sage,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              error ??
                  (connecting
                      ? 'Connecting securely…'
                      : 'Chats are server-readable for safety and moderation, not end-to-end encrypted.'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactBanner extends StatelessWidget {
  const _ContactBanner({required this.phone, required this.name});

  final String phone;
  final String name;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.sage.withValues(alpha: 0.16)
            : AppColors.sageLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_outlined, size: 19, color: AppColors.sage),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$name shared $phone for this exchange',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.mine});

  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final localTime = message.createdAt.toLocal();
    final time =
        '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.fromLTRB(13, 9, 13, 7),
        decoration: BoxDecoration(
          color: mine
              ? AppColors.terracotta
              : (isDark ? AppColors.darkPaper : AppColors.paper),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(17),
            topRight: const Radius.circular(17),
            bottomLeft: Radius.circular(mine ? 17 : 4),
            bottomRight: Radius.circular(mine ? 4 : 17),
          ),
          border: mine
              ? null
              : Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
        ),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  message.senderName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.sage,
                  ),
                ),
              ),
            Text(
              message.body,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: mine ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              time,
              style: TextStyle(
                fontSize: 10,
                color: mine
                    ? Colors.white.withValues(alpha: 0.68)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.42),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool sending;
  final VoidCallback onSend;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant _Composer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSend =
        widget.enabled &&
        !widget.sending &&
        widget.controller.text.trim().isNotEmpty &&
        widget.controller.text.trim().length <= 2000;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  enabled: widget.enabled,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Message',
                    counterText: '',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: canSend ? widget.onSend : null,
                icon: const Icon(Icons.arrow_upward_rounded),
                tooltip: 'Send message',
              ),
            ],
          ),
        ),
      ),
    );
  }
}