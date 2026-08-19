class Skill {
  const Skill({required this.id, required this.name, required this.blurb});

  final int id;
  final String name;
  final String blurb;

  factory Skill.fromJson(Map<String, dynamic> json) => Skill(
    id: json['id'] as int,
    name: json['name'] as String,
    blurb: json['blurb'] as String? ?? '',
  );
}
