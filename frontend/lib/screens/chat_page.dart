import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
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
  bool _otherTyping = false;
  Timer? _otherTypingTimer;
  Timer? _sendTypingTimer;

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
      _reconnectAttempts = 0;
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
      } else if (type == 'typing') {
        final typingUserId = payload['user_id'] as int?;
        if (typingUserId != null && typingUserId != Api.currentUserId) {
          setState(() => _otherTyping = true);
          _otherTypingTimer?.cancel();
          _otherTypingTimer = Timer(const Duration(seconds: 5), () {
            if (mounted) setState(() => _otherTyping = false);
          });
        }
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

  int _reconnectAttempts = 0;

  void _scheduleReconnect(int generation) {
    if (_disposed || generation != _connectionGeneration) return;
    _reconnectTimer?.cancel();
    final delay = Duration(
      seconds: (3 * (1 << _reconnectAttempts.clamp(0, 5))).toInt(),
    );
    _reconnectTimer = Timer(delay, _connect);
    _reconnectAttempts++;
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

  void _send({String? body, String? imageUrl}) {
    final text = body ?? _composer.text.trim();
    if ((text.isEmpty && imageUrl == null) || text.length > 2000 || _channel == null || _sending) {
      return;
    }
    setState(() => _sending = true);
    try {
      final msg = <String, dynamic>{'type': 'message', 'body': text};
      if (imageUrl != null) msg['image_url'] = imageUrl;
      _channel!.sink.add(jsonEncode(msg));
      if (body == null) _composer.clear();
      setState(() => _sending = false);
    } catch (_) {
      setState(() {
        _sending = false;
        _error = 'Message not sent. Wait for the chat to reconnect.';
      });
    }
  }

  void _sendTyping() {
    if (_channel == null) return;
    try {
      _channel!.sink.add(jsonEncode({'type': 'typing'}));
    } catch (_) {}
  }

  void _onComposerTextChanged() {
    if (_sendTypingTimer?.isActive ?? false) return;
    _sendTyping();
    _sendTypingTimer = Timer(const Duration(seconds: 2), () {});
  }

  Future<void> _pickAndSendImage() async {
    if (_channel == null || _sending) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null || !mounted) return;
    setState(() => _sending = true);
    try {
      final file = File(picked.path);
      final result = await Api.uploadFile('/api/upload', file);
      final imageUrl = result['url'] as String? ?? result['path'] as String?;
      if (imageUrl != null && mounted) {
        _send(body: '', imageUrl: imageUrl);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = 'Image could not be sent.';
        });
      }
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
        _showRatingDialog();
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

  void _showRatingDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RatingSheet(requestId: widget.request.id),
    );
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
    _otherTypingTimer?.cancel();
    _sendTypingTimer?.cancel();
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
                if (_otherTyping)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          '${widget.otherUserName.split(' ').first} is typing',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 16,
                          height: 12,
                          child: _TypingDots(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                _Composer(
                  controller: _composer,
                  enabled: !_connecting && _channel != null && isAccepted,
                  sending: _sending,
                  onSend: () => _send(),
                  onPickImage: _pickAndSendImage,
                  onTextChanged: _onComposerTextChanged,
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

    final List<Widget> items = [];
    DateTime? prevDate;
    for (var i = 0; i < messages.length; i++) {
      final msg = messages[i];
      final msgDate = DateTime(msg.createdAt.year, msg.createdAt.month, msg.createdAt.day);
      if (prevDate == null || msgDate != prevDate) {
        items.add(_DateSeparator(date: msg.createdAt));
        prevDate = msgDate;
      }
      items.add(
        _MessageBubble(
          message: msg,
          mine: msg.senderId == Api.currentUserId,
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
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

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(date.year, date.month, date.day);
    String label;
    if (messageDay == today) {
      label = 'Today';
    } else if (messageDay == today.subtract(const Duration(days: 1))) {
      label = 'Yesterday';
    } else {
      label = '${date.month}/${date.day}/${date.year}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots({required this.color});
  final Color color;

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
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
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final offset = i * 0.33;
            final value = ((_controller.value - offset) % 1.0);
            final opacity = value < 0.5
                ? (value * 2).clamp(0.3, 1.0)
                : ((1.0 - value) * 2).clamp(0.3, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Opacity(
                opacity: opacity.toDouble(),
                child: Text(
                  '.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: widget.color,
                  ),
                ),
              ),
            );
          }),
        );
      },
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
            if (message.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  '${Api.baseUrl}${message.imageUrl}',
                  width: 240,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      Icons.broken_image_rounded,
                      color: mine
                          ? Colors.white.withValues(alpha: 0.6)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            if (message.body.isNotEmpty)
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
    this.onPickImage,
    this.onTextChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback? onPickImage;
  final VoidCallback? onTextChanged;

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

  void _changed() {
    setState(() {});
    widget.onTextChanged?.call();
  }

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
              const SizedBox(width: 4),
              if (widget.onPickImage != null)
                IconButton(
                  onPressed: widget.enabled ? widget.onPickImage : null,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  tooltip: 'Send image',
                  visualDensity: VisualDensity.compact,
                ),
              const SizedBox(width: 4),
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

class _RatingSheet extends StatefulWidget {
  const _RatingSheet({required this.requestId});

  final int requestId;

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  int _stars = 0;
  final _review = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _review.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars == 0 || _submitting) return;
    setState(() => _submitting = true);
    try {
      await Api.post(
        '/api/requests/${widget.requestId}/rate',
        body: {
          'stars': _stars,
          'review': _review.text.trim(),
        },
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = true;
      });
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) Navigator.of(context).pop();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    final dialogBg = isDark ? AppColors.darkPaper : AppColors.paper;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        decoration: BoxDecoration(
          color: dialogBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: _submitted ? _buildSuccess(theme) : _buildForm(theme, isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.star_rounded,
            color: AppColors.gold,
            size: 28,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Thanks for your feedback!',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildForm(ThemeData theme, bool isDark) {
    final cancelBorder = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.6)
        : AppColors.inkSoft.withValues(alpha: 0.2);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.star_rounded,
            color: AppColors.gold,
            size: 28,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Rate your experience',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final index = i + 1;
            final filled = index <= _stars;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _stars = index);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 40,
                  color: filled
                      ? AppColors.gold
                      : theme.colorScheme.onSurface.withValues(alpha: 0.25),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSand.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? AppColors.darkBorder.withValues(alpha: 0.7)
                  : AppColors.inkSoft.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: TextField(
            controller: _review,
            maxLines: 3,
            style: TextStyle(
              fontSize: 13.5,
              color: theme.colorScheme.onSurface,
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText: 'Leave a review (optional)',
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
                fontSize: 13.5,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: cancelBorder, width: 1),
                  ),
                  child: Center(
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _stars == 0 ? null : _submit,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _stars == 0
                        ? AppColors.gold.withValues(alpha: 0.4)
                        : AppColors.gold,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: _stars > 0
                        ? [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Submit',
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
    );
  }
}