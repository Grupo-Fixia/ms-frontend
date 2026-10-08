import 'dart:async';

import 'package:ms_frontend/features/auth/registration/application/ports/account_registration_repository.dart';
import 'package:ms_frontend/features/auth/registration/domain/account_registration.dart';
import 'package:ms_frontend/features/auth/registration/domain/registration_exceptions.dart';

/// Repositorio de prueba: guarda lo recibido y puede fallar o demorarse.
class FakeAccountRegistrationRepository implements AccountRegistrationRepository {
  FakeAccountRegistrationRepository({this.failure, this.pending});

  final RegistrationFailure? failure;
  final Completer<void>? pending;

  AccountRegistration? saved;
  int calls = 0;

  @override
  Future<void> register(AccountRegistration registration) async {
    calls++;
    saved = registration;
    await pending?.future;
    final failure = this.failure;
    if (failure != null) throw failure;
  }
}
