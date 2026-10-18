import '../../../../../core/constants/service_category.dart';
import '../../domain/technician_specialties.dart';

/// Puerto de salida: especialidades del técnico autenticado (GC-325).
///
/// Todos los métodos lanzan `TechnicianSpecialtiesFailure` si el backend
/// rechaza la solicitud o no se puede contactar.
abstract interface class TechnicianSpecialtiesRepository {
  /// Catálogo habilitado de especialidades y servicios.
  Future<List<ServiceCategoryOption>> fetchCatalog();

  Future<TechnicianSpecialties> fetchSpecialties();

  /// Reemplaza por completo la selección y devuelve la guardada. Un conjunto
  /// vacío las retira todas.
  Future<TechnicianSpecialties> updateSpecialties(
    Set<ServiceCategory> categories,
  );
}
