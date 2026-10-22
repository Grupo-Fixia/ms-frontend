import '../../domain/service_application.dart';

/// Puerto de salida: postulaciones del técnico autenticado (GC-345).
///
/// Todos los métodos lanzan `ApplicationFailure` si el backend rechaza la
/// solicitud o no se puede contactar.
abstract interface class ApplicationRepository {
  /// Registra la postulación (estado `applied`).
  Future<ServiceApplication> apply(String serviceRequestId);

  /// Postulaciones del técnico, la más reciente primero.
  Future<List<ServiceApplication>> listMine();

  Future<ServiceApplication> getMine(String id);
}
