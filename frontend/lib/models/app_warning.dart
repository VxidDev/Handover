class AppWarning {
  const AppWarning({required this.id, required this.reason, required this.createdAt});

  final int id;
  final String reason;
  final DateTime createdAt;

  factory AppWarning.fromJson(Map<String, dynamic> json) => AppWarning(
    id: json['id'] as int,
    reason: json['reason'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}