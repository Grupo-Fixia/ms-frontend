import '../../../../core/constants/service_category.dart';

/// Técnico que puede atender una solicitud del cliente (GC-474): ofrece su
/// categoría, atiende su ciudad y tiene horario a esa hora. Solo datos
/// públicos; nunca su zona exacta, distancia ni contacto.
class CompatibleTechnician {
  const CompatibleTechnician({
    required this.userId,
    required this.displayName,
    required this.categories,
    this.city,
  });

  final String userId;
  final String displayName;
  final List<ServiceCategory> categories;
  final String? city;
}

/// Una página de técnicos compatibles. Puede venir corta o vacía con
/// [nextCursor]: hay que seguir pidiendo hasta que sea `null`.
class CompatibleTechniciansPage {
  const CompatibleTechniciansPage({required this.items, this.nextCursor});

  final List<CompatibleTechnician> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}
