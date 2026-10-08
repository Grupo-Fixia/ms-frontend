import 'dart:async';

import 'package:ms_frontend/features/technician/profile/application/ports/technician_profile_repository.dart';
import 'package:ms_frontend/features/technician/profile/domain/professional_profile_update.dart';
import 'package:ms_frontend/features/technician/profile/domain/technician_profile.dart';
import 'package:ms_frontend/features/technician/profile/domain/technician_profile_exceptions.dart';

/// Repositorio de prueba: devuelve el perfil indicado, guarda lo recibido y
/// puede fallar o demorarse.
class FakeTechnicianProfileRepository implements TechnicianProfileRepository {
  FakeTechnicianProfileRepository({
    required this.profile,
    this.fetchFailure,
    this.updateFailure,
    this.pendingUpdate,
  });

  TechnicianProfile profile;
  TechnicianProfileFailure? fetchFailure;
  TechnicianProfileFailure? updateFailure;
  final Completer<void>? pendingUpdate;

  int fetchCalls = 0;
  int updateCalls = 0;
  ProfessionalProfileUpdate? lastUpdate;

  @override
  Future<TechnicianProfile> fetchProfile() async {
    fetchCalls++;
    final failure = fetchFailure;
    if (failure != null) throw failure;
    return profile;
  }

  @override
  Future<TechnicianProfile> updateProfile(
    ProfessionalProfileUpdate update,
  ) async {
    updateCalls++;
    lastUpdate = update;
    await pendingUpdate?.future;
    final failure = updateFailure;
    if (failure != null) throw failure;
    profile = TechnicianProfile(
      technicianId: profile.technicianId,
      verificationStatus: profile.verificationStatus,
      professionalDescription: update.professionalDescription,
      yearsOfExperience: update.yearsOfExperience,
      categories: update.categories,
      updatedAt: DateTime(2026, 10, 8, 11),
    );
    return profile;
  }
}
