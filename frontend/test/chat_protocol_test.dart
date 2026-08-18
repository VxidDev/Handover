import 'package:flutter_test/flutter_test.dart';
import 'package:handover/models/chat_message.dart';
import 'package:handover/services/api.dart';

void main() {
  test('room WebSocket URI uses the API host and a scoped room token', () {
    final uri = Api.roomWebSocketUri(42, 'room-secret');

    expect(uri.scheme, Uri.parse(Api.baseUrl).scheme == 'https' ? 'wss' : 'ws');
    expect(uri.host, Uri.parse(Api.baseUrl).host);
    expect(uri.path, '/api/requests/42/chat');
    expect(uri.queryParameters, {'token': 'room-secret'});
  });

  test('chat message parses the server payload', () {
    final message = ChatMessage.fromJson({
      'id': 9,
      'request_id': 42,
      'sender_id': 3,
      'sender_name': 'Sam',
      'body': 'On my way',
      'created_at': '2026-08-18T12:00:00Z',
    });

    expect(message.id, 9);
    expect(message.requestId, 42);
    expect(message.senderId, 3);
    expect(message.body, 'On my way');
    expect(message.createdAt.isUtc, isTrue);
  });
}
