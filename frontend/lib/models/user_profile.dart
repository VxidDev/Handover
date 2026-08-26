import 'skill.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.isAvailable,
    required this.karma,
    required this.skills,
    required this.createdAt,
    this.grid,
    this.phone,
    this.profileImage,
    this.tosAcceptedAt,
    this.privacyAcceptedAt,
  });

  final int id;
  final String email;
  final String name;
  final bool isAvailable;
  final int karma;
  final String? grid;
  final String? phone;
  final String? profileImage;
  final List<Skill> skills;
  final DateTime createdAt;
  final DateTime? tosAcceptedAt;
  final DateTime? privacyAcceptedAt;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as int,
    email: json['email'] as String,
    name: json['name'] as String,
    isAvailable: json['is_available'] as bool? ?? true,
    karma: json['karma'] as int? ?? 0,
    grid: json['grid'] as String?,
    phone: json['phone'] as String?,
    profileImage: json['profile_image'] as String?,
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime(0),
    tosAcceptedAt: json['tos_accepted_at'] != null
        ? DateTime.tryParse(json['tos_accepted_at'] as String)
        : null,
    privacyAcceptedAt: json['privacy_accepted_at'] != null
        ? DateTime.tryParse(json['privacy_accepted_at'] as String)
        : null,
    skills: (json['skills'] as List<dynamic>? ?? [])
        .map((e) => Skill.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
