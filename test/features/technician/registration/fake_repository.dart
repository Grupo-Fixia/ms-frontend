import 'dart:async';

import 'package:ms_frontend/features/technician/registration/application/ports/technician_registration_repository.dart';
import 'package:ms_frontend/features/technician/registration/domain/technician_registration.dart';
import 'package:ms_frontend/features/technician/registration/domain/technician_registration_exceptions.dart';

class FakeTechnicianRegistrationRepository
    implements TechnicianRegistrationRepository {
  FakeTechnicianRegistrationRepository({this.failure, this.pending});

  final TechnicianRegistrationFailure? failure;
  final Completer<void>? pending;

  TechnicianRegistration? saved;
  int calls = 0;

  @override
  Future<void> register(TechnicianRegistration registration) async {
    calls++;
    saved = registration;
    await pending?.future;
    final failure = this.failure;
    if (failure != null) throw failure;
  }
}
