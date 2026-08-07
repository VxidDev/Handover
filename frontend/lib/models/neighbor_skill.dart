class NeighborSkill {
  const NeighborSkill({
    required this.name,
    required this.skill,
    required this.blurb,
    required this.grid,
    required this.km,
    this.available = true,
  });

  final String name;
  final String skill;
  final String blurb;
  final String grid;
  final double km;
  final bool available;

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';
}