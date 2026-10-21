class CoverageZone {
  const CoverageZone({required this.city, required this.radiusKm});

  static const minRadiusKm = 1;
  static const maxRadiusKm = 50;

  final String city;
  final int radiusKm;

  bool get isValid =>
      city.trim().isNotEmpty &&
      radiusKm >= minRadiusKm &&
      radiusKm <= maxRadiusKm;
}
