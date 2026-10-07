import '../application/ports/technician_registration_repository.dart';
import '../domain/technician_registration.dart';
import '../domain/technician_registration_exceptions.dart';

/// Simula el fallo del servicio hasta que se aborde su integración.
class PendingTechnicianRegistrationRepository
    implements TechnicianRegistrationRepository {
  const PendingTechnicianRegistrationRepository();

  @override
  Future<void> register(TechnicianRegistration registration) async {
    throw const TechnicianRegistrationFailure(
      'No fue posible conectar con el servidor. Inténtalo de nuevo.',
    );
  }
}
