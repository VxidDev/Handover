class NeighborSkill {
  const NeighborSkill({
    required this.name,
    required this.skill,
    required this.blurb,
    this.grid,
    this.km,
    this.available = true,
    this.skillId,
    this.ownerId,
  });

  final String name;
  final String skill;
  final String blurb;
  final String? grid;
  final double? km;
  final bool available;
  final int? skillId;
  final int? ownerId;

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';

  factory NeighborSkill.fromSearchResult(Map<String, dynamic> json) => NeighborSkill(
        skillId: json['skill_id'] as int?,
        ownerId: json['owner_id'] as int?,
        name: json['owner_name'] as String? ?? '',
        skill: json['skill_name'] as String? ?? '',
        blurb: json['blurb'] as String? ?? '',
        grid: json['grid'] as String?,
        km: (json['distance_km'] as num?)?.toDouble(),
        available: json['available'] as bool? ?? true,
      );
}