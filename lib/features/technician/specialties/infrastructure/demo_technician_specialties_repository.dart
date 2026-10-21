import '../../../../core/constants/service_category.dart';
import '../application/ports/technician_specialties_repository.dart';
import '../domain/technician_specialties.dart';

/// Implementación en memoria del puerto de especialidades para la demo sin
/// sesión. Con sesión real se usa `HttpTechnicianSpecialtiesRepository`.
class DemoTechnicianSpecialtiesRepository
    implements TechnicianSpecialtiesRepository {
  DemoTechnicianSpecialtiesRepository({
    Set<ServiceCategory> initial = const {
      ServiceCategory.plumbing,
      ServiceCategory.electrical,
    },
  }) : _selected = {...initial};

  Set<ServiceCategory> _selected;

  @override
  Future<List<ServiceCategoryOption>> fetchCatalog() async => [
        for (final category in ServiceCategory.values)
          ServiceCategoryOption(category: category, name: category.label),
      ];

  @override
  Future<TechnicianSpecialties> fetchSpecialties() async =>
      TechnicianSpecialties(categories: {..._selected});

  @override
  Future<TechnicianSpecialties> updateSpecialties(
    Set<ServiceCategory> categories,
  ) async {
    _selected = {...categories};
    return TechnicianSpecialties(
      categories: {..._selected},
      updatedAt: DateTime.now(),
    );
  }
}
