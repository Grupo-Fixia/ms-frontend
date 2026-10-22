import '../domain/technician_specialties.dart';
import 'ports/technician_specialties_repository.dart';

/// Caso de uso: consultar las especialidades del técnico (GC-294).
class GetTechnicianSpecialties {
  const GetTechnicianSpecialties(this._repository);

  final TechnicianSpecialtiesRepository _repository;

  Future<TechnicianSpecialties> call() => _repository.fetchSpecialties();
}
