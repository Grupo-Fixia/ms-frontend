import 'dart:async';

import 'package:ms_frontend/features/client_registration/application/ports/client_registration_repository.dart';
import 'package:ms_frontend/features/client_registration/domain/client_registration.dart';
import 'package:ms_frontend/features/client_registration/domain/client_registration_exceptions.dart';

/// Repositorio de prueba: guarda lo recibido y puede fallar o demorarse.
class FakeClientRegistrationRepository implements ClientRegistrationRepository {
  FakeClientRegistrationRepository({this.failure, this.pending});

  final ClientRegistrationFailure? failure;
  final Completer<void>? pending;

  ClientRegistration? saved;
  int calls = 0;

  @override
  Future<void> register(ClientRegistration registration) async {
    calls++;
    saved = registration;
    await pending?.future;
    final failure = this.failure;
    if (failure != null) throw failure;
  }
}
