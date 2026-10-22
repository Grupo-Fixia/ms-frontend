import '../../../../core/constants/service_category.dart';
import '../domain/technician_specialties.dart';
import 'ports/technician_specialties_repository.dart';

/// Caso de uso: seleccionar o actualizar las especialidades del técnico
/// (GC-294). La selección reemplaza por completo la anterior.
class UpdateTechnicianSpecialties {
  const UpdateTechnicianSpecialties(this._repository);

  final TechnicianSpecialtiesRepository _repository;

  Future<TechnicianSpecialties> call(Set<ServiceCategory> categories) =>
      _repository.updateSpecialties(Set.unmodifiable(categories));
}
