class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.requestId,
    required this.senderId,
    required this.senderName,
    required this.body,
    required this.createdAt,
    this.imageUrl,
  });

  final int id;
  final int requestId;
  final int senderId;
  final String senderName;
  final String body;
  final DateTime createdAt;
  final String? imageUrl;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as int,
    requestId: json['request_id'] as int,
    senderId: json['sender_id'] as int,
    senderName: json['sender_name'] as String,
    body: json['body'] as String,
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime(2024),
    imageUrl: json['image_url'] as String?,
  );
}
