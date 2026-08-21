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
    this.bannedUntil,
  });

  final int id;
  final String email;
  final String name;
  final bool isAvailable;
  final int karma;
  final String? grid;
  final String? phone;
  final DateTime? bannedUntil;
  final List<Skill> skills;
  final DateTime createdAt;

  bool get isBanned => bannedUntil != null && bannedUntil!.isAfter(DateTime.now());

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as int,
    email: json['email'] as String,
    name: json['name'] as String,
    isAvailable: json['is_available'] as bool? ?? true,
    karma: json['karma'] as int? ?? 0,
    grid: json['grid'] as String?,
    phone: json['phone'] as String?,
    bannedUntil: json['banned_until'] != null
        ? DateTime.parse(json['banned_until'] as String)
        : null,
    createdAt: DateTime.parse(json['created_at'] as String),
    skills: (json['skills'] as List<dynamic>? ?? [])
        .map((e) => Skill.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
