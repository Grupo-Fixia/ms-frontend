import '../../domain/technician_registration.dart';

/// Puerto para enviar el registro de técnico.
abstract interface class TechnicianRegistrationRepository {
  Future<void> register(TechnicianRegistration registration);
}
