/// Zona donde el técnico atiende (RF-011): una ciudad y, si se quiere
/// precisar, un círculo dentro de ella.
class CoverageZone {
  const CoverageZone({
    required this.city,
    this.latitude,
    this.longitude,
    this.radiusKm,
    this.updatedAt,
  });

  final String city;
  final double? latitude;
  final double? longitude;
  final int? radiusKm;
  final DateTime? updatedAt;

  /// `false` si la zona es toda la ciudad.
  bool get hasCircle =>
      latitude != null && longitude != null && radiusKm != null;
}

/// Datos para declarar o reemplazar la zona de atención. Latitud, longitud y
/// radio van juntos o se omiten los tres.
class CoverageZoneUpdate {
  const CoverageZoneUpdate({
    required this.city,
    this.latitude,
    this.longitude,
    this.radiusKm,
  });

  final String city;
  final double? latitude;
  final double? longitude;
  final int? radiusKm;
}
