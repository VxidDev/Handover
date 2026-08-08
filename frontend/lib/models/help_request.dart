class HelpRequest {
  const HelpRequest({
    required this.id,
    required this.status,
    required this.requesterId,
    required this.requesterName,
    required this.providerId,
    required this.providerName,
    required this.skillName,
    this.message,
    this.createdAt,
  });

  final int id;
  final String status;
  final int requesterId;
  final String requesterName;
  final int providerId;
  final String providerName;
  final String skillName;
  final String? message;
  final DateTime? createdAt;

  factory HelpRequest.fromJson(Map<String, dynamic> json) => HelpRequest(
        id: json['id'] as int,
        status: json['status'] as String,
        requesterId: json['requester_id'] as int,
        requesterName: json['requester_name'] as String,
        providerId: json['provider_id'] as int,
        providerName: json['provider_name'] as String,
        skillName: json['skill_name'] as String,
        message: json['message'] as String?,
        createdAt:
            json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      );
}