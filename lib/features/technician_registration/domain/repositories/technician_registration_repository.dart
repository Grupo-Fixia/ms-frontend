import '../entities/technician_registration.dart';

abstract interface class TechnicianRegistrationRepository {
  Future<void> register(TechnicianRegistration registration);
}
