import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/chat_message.dart';
import '../models/help_request.dart';
import '../services/api.dart';
import '../theme/colors.dart';
import '../widgets/report_dialog.dart';

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

  List<ChatMessage> get _messages =>
      _messagesById.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  @override
  void initState() {
    super.initState();
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
                  enabled: !_connecting && _channel != null,
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
        onReport: messages[index].senderId == Api.currentUserId
            ? null
            : () => showReportDialog(
                context,
                contentType: 'chat_message',
                contentId: messages[index].id,
                title: 'Chat message',
              ),
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
  const _MessageBubble({
    required this.message,
    required this.mine,
    this.onReport,
  });

  final ChatMessage message;
  final bool mine;
  final VoidCallback? onReport;

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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 10,
                    color: mine
                        ? Colors.white.withValues(alpha: 0.68)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.42),
                  ),
                ),
                if (!mine && onReport != null) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: onReport,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.flag_outlined,
                        size: 12,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.35,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
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
