import 'ports/technician_availability_repository.dart';
import '../domain/technician_service_settings.dart';

class GetTechnicianServiceSettings {
  const GetTechnicianServiceSettings(this._repository);
  final TechnicianAvailabilityRepository _repository;
  Future<TechnicianServiceSettings> call() => _repository.fetchSettings();
}
