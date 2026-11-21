/// Reputación pública de un técnico (GC-446): promedio de las calificaciones
/// que le dieron sus clientes y cuántas son. ms-users la calcula de las
/// evaluaciones reales; si no tiene ninguna llega `null` y no se inventa.
class Reputation {
  const Reputation({required this.average, required this.count});

  /// Entre 1 y 5, con un decimal.
  final double average;
  final int count;

  /// `null` si el JSON no trae una reputación válida.
  static Reputation? fromJson(Object? json) {
    if (json is! Map) return null;
    final average = json['average'];
    final count = json['count'];
    if (average is! num || count is! num || count <= 0) return null;
    if (average < 1 || average > 5) return null;
    return Reputation(average: average.toDouble(), count: count.toInt());
  }

  /// "4,4" (coma decimal, como se escribe en Colombia).
  String get averageLabel => average.toStringAsFixed(1).replaceAll('.', ',');

  /// "1 calificación" / "8 calificaciones".
  String get countLabel =>
      count == 1 ? '1 calificación' : '$count calificaciones';
}
