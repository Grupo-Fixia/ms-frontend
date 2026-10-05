import '../../domain/entities/technician_registration.dart';
import '../../domain/repositories/technician_registration_repository.dart';
import '../datasources/technician_registration_remote_data_source.dart';

class TechnicianRegistrationRepositoryImpl
    implements TechnicianRegistrationRepository {
  const TechnicianRegistrationRepositoryImpl(this._remoteDataSource);

  final TechnicianRegistrationRemoteDataSource _remoteDataSource;

  @override
  Future<void> register(TechnicianRegistration registration) {
    return _remoteDataSource.register(registration);
  }
}
