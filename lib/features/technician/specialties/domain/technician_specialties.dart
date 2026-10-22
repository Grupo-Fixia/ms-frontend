import '../../../../core/constants/service_category.dart';

/// Especialidades y servicios que ofrece el técnico (GC-294, RF-010).
class TechnicianSpecialties {
  const TechnicianSpecialties({required this.categories, this.updatedAt});

  /// Vacío si el técnico aún no ha seleccionado ninguna.
  final Set<ServiceCategory> categories;
  final DateTime? updatedAt;
}

/// Una opción del catálogo habilitado, con el nombre que define el backend.
class ServiceCategoryOption {
  const ServiceCategoryOption({required this.category, required this.name});

  final ServiceCategory category;
  final String name;
}
