class NeighborSkill {
  final int? skillId;
  final int ownerId;
  final String skill;
  final String blurb;
  final String name;
  final double? km;
  final String? grid;
  final bool available;
  final int karma;
  final List<String> images;

  NeighborSkill({
    this.skillId,
    required this.ownerId,
    required this.skill,
    required this.blurb,
    required this.name,
    this.km,
    this.grid,
    required this.available,
    required this.karma,
    this.images = const [],
  });

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';

  factory NeighborSkill.fromSearchResult(Map<String, dynamic> json) {
    return NeighborSkill(
      skillId: json['skill_id'] as int?,
      ownerId: json['owner_id'] as int,
      skill: json['skill_name'] as String,
      blurb: json['blurb'] as String? ?? '',
      name: json['owner_name'] as String,
      km: (json['distance_km'] as num?)?.toDouble(),
      grid: json['grid'] as String?,
      available: json['available'] as bool? ?? true,
      karma: json['karma'] as int? ?? 0,
      images:
          (json['images'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
