import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'api.dart';

typedef NotificationCallback = void Function(Map<String, dynamic> event);

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  int _reconnectDelay = 3;
  bool _disposed = false;

  final List<NotificationCallback> _listeners = [];

  void addListener(NotificationCallback cb) => _listeners.add(cb);
  void removeListener(NotificationCallback cb) => _listeners.remove(cb);

  void connect() {
    if (Api.token == null) return;
    _disposed = false;
    _reconnectDelay = 3;
    _doConnect();
  }

  void disconnect() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  void _doConnect() {
    if (_disposed || Api.token == null) return;
    _sub?.cancel();
    _channel?.sink.close();

    final uri = Api.notificationWebSocketUri;
    _channel = WebSocketChannel.connect(uri);

    _sub = _channel!.stream.listen(
      (data) {
        _reconnectDelay = 3;
        try {
          final event = jsonDecode(data as String) as Map<String, dynamic>;
          for (final cb in _listeners) {
            cb(event);
          }
        } catch (_) {}
      },
      onError: (_) => _scheduleReconnect(),
      onDone: _scheduleReconnect,
    );
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelay), () {
      _reconnectDelay = (_reconnectDelay * 2).clamp(3, 30);
      _doConnect();
    });
  }
}
