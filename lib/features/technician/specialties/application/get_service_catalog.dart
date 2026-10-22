import '../domain/technician_specialties.dart';
import 'ports/technician_specialties_repository.dart';

/// Caso de uso: consultar el catálogo de especialidades y servicios (GC-294).
class GetServiceCatalog {
  const GetServiceCatalog(this._repository);

  final TechnicianSpecialtiesRepository _repository;

  Future<List<ServiceCategoryOption>> call() => _repository.fetchCatalog();
}
