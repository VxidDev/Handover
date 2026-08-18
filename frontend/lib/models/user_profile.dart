import 'skill.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.isAvailable,
    required this.karma,
    required this.skills,
    this.grid,
    this.phone,
  });

  final int id;
  final String email;
  final String name;
  final bool isAvailable;
  final int karma;
  final String? grid;
  final String? phone;
  final List<Skill> skills;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as int,
    email: json['email'] as String,
    name: json['name'] as String,
    isAvailable: json['is_available'] as bool? ?? true,
    karma: json['karma'] as int? ?? 0,
    grid: json['grid'] as String?,
    phone: json['phone'] as String?,
    skills: (json['skills'] as List<dynamic>? ?? [])
        .map((e) => Skill.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
