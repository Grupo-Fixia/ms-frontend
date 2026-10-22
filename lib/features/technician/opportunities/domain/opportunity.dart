import '../../../../core/constants/service_category.dart';

/// Solicitud abierta y compatible con el técnico (GC-297, RF-014): publicada,
/// con el momento esperado por delante y a la que aún no se ha postulado.
///
/// Solo trae la ubicación aproximada: ni el cliente, ni la dirección exacta,
/// ni las fotos se comparten antes de la contratación.
class Opportunity {
  const Opportunity({
    required this.id,
    required this.category,
    required this.description,
    required this.city,
    required this.zone,
    required this.expectedAt,
    this.latitude,
    this.longitude,
    this.publishedAt,
  });

  final String id;
  final ServiceCategory category;
  final String description;
  final String city;
  final String zone;
  final DateTime expectedAt;
  final double? latitude;
  final double? longitude;
  final DateTime? publishedAt;
}

/// Una página de oportunidades. [nextCursor] es `null` cuando no quedan más.
class OpportunityPage {
  const OpportunityPage({required this.items, this.nextCursor});

  final List<Opportunity> items;

  /// Opaco: se devuelve tal cual para pedir la siguiente página.
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}
