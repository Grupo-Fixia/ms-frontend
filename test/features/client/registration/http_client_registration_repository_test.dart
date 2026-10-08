import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/features/client/registration/domain/client_registration_exceptions.dart';
import 'package:ms_frontend/features/client/registration/infrastructure/http_client_registration_repository.dart';

import 'fixtures.dart';

final _baseUrl = Uri.parse('http://localhost');

HttpClientRegistrationRepository _repository(
  MockClientHandler handler, {
  Duration timeout = const Duration(seconds: 15),
}) {
  return HttpClientRegistrationRepository(
    client: MockClient(handler),
    baseUrl: _baseUrl,
    timeout: timeout,
  );
}

/// Respuesta como la de ms-users: JSON en UTF-8 y `application/problem+json`
/// sin charset (así responde Spring con ProblemDetail).
http.Response _problem(int status, Map<String, Object?> body) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/problem+json'},
  );
}

Matcher _failure({
  String? message,
  Map<String, String>? fieldErrors,
  bool? isAccountConflict,
}) {
  var matcher = isA<ClientRegistrationFailure>();
  if (isAccountConflict != null) {
    matcher = matcher.having(
      (f) => f.isAccountConflict,
      'isAccountConflict',
      isAccountConflict,
    );
  }
  if (message != null) {
    matcher = matcher.having((f) => f.message, 'message', message);
  }
  if (fieldErrors != null) {
    matcher = matcher.having((f) => f.fieldErrors, 'fieldErrors', fieldErrors);
  }
  return matcher;
}

void main() {
  test('envía POST /api/users/clients con el contrato de ms-users', () async {
    late http.Request sent;
    final repository = _repository((request) async {
      sent = request;
      return http.Response('{"id":"1"}', 201);
    });

    await repository.register(validRegistration(email: ' ana@fixia.com '));

    expect(sent.method, 'POST');
    expect(sent.url.toString(), 'http://localhost/api/users/clients');
    expect(sent.headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(sent.body), {
      'firstName': 'Ana',
      'lastName': 'Pérez',
      'documentType': 'CC',
      'documentNumber': '1020304050',
      'email': 'ana@fixia.com',
      'phone': '3001234567',
      'password': 'Segura123',
      'policyVersion': 'v1.0',
      'consentAccepted': true,
    });
  });

  test('201 Created termina sin error', () async {
    final repository = _repository((_) async => http.Response('', 201));

    await expectLater(repository.register(validRegistration()), completes);
  });

  test('400 convierte los errores del backend en errores por campo', () async {
    final repository = _repository(
      (_) async => _problem(400, {
        'title': 'Datos inválidos',
        'detail': 'Hay datos que debe corregir',
        'errors': [
          {'field': 'email', 'message': 'El correo electrónico no es válido'},
          {'field': 'phone', 'message': 'El teléfono no es válido'},
          {'field': 'phone', 'message': 'Otro error del mismo campo'},
        ],
      }),
    );

    await expectLater(
      repository.register(validRegistration()),
      throwsA(
        _failure(
          message: HttpClientRegistrationRepository.invalidDataMessage,
          fieldErrors: {
            'email': 'El correo electrónico no es válido',
            'phone': 'El teléfono no es válido',
          },
        ),
      ),
    );
  });

  test('decodifica las tildes en UTF-8 aunque falte el charset (DEF-02)',
      () async {
    final repository = _repository(
      (_) async => _problem(400, {
        'errors': [
          {
            'field': 'password',
            'message': 'La contraseña debe incluir letras y números',
          },
        ],
      }),
    );

    await expectLater(
      repository.register(validRegistration()),
      throwsA(
        _failure(fieldErrors: {
          'password': 'La contraseña debe incluir letras y números',
        }),
      ),
    );
  });

  test('400 sin errores por campo usa el detalle del backend', () async {
    final repository = _repository(
      (_) async => _problem(400, {
        'title': 'Solicitud inválida',
        'detail': 'El cuerpo de la solicitud no es válido',
      }),
    );

    await expectLater(
      repository.register(validRegistration()),
      throwsA(
        _failure(
          message: 'El cuerpo de la solicitud no es válido',
          fieldErrors: const {},
        ),
      ),
    );
  });

  test('400 con un cuerpo que no es JSON da un mensaje genérico', () async {
    final repository =
        _repository((_) async => http.Response('<html>error</html>', 400));

    await expectLater(
      repository.register(validRegistration()),
      throwsA(
        _failure(message: HttpClientRegistrationRepository.invalidDataMessage),
      ),
    );
  });

  test('409 informa que la cuenta ya existe', () async {
    final repository = _repository(
      (_) async => _problem(409, {
        'title': 'Cuenta existente',
        'detail': 'Ya existe una cuenta registrada con los datos proporcionados',
      }),
    );

    await expectLater(
      repository.register(validRegistration()),
      throwsA(
        _failure(
          message: HttpClientRegistrationRepository.conflictMessage,
          isAccountConflict: true,
          fieldErrors: const {
            'email': HttpClientRegistrationRepository.conflictFieldMessage,
            'documentNumber':
                HttpClientRegistrationRepository.conflictFieldMessage,
          },
        ),
      ),
    );
  });

  test('409 con el campo indicado por el backend marca solo ese campo',
      () async {
    final repository = _repository(
      (_) async => _problem(409, {
        'title': 'Cuenta existente',
        'errors': [
          {'field': 'email', 'message': 'Este correo ya está registrado'},
        ],
      }),
    );

    await expectLater(
      repository.register(validRegistration()),
      throwsA(
        _failure(
          isAccountConflict: true,
          fieldErrors: const {'email': 'Este correo ya está registrado'},
        ),
      ),
    );
  });

  test('un error del servidor da un mensaje genérico', () async {
    final repository = _repository((_) async => http.Response('', 503));

    await expectLater(
      repository.register(validRegistration()),
      throwsA(
        _failure(
          message: HttpClientRegistrationRepository.unexpectedErrorMessage,
          isAccountConflict: false,
        ),
      ),
    );
  });

  test('sin conexión informa el problema de red', () async {
    final repository = _repository(
      (_) async => throw http.ClientException('Failed to fetch'),
    );

    await expectLater(
      repository.register(validRegistration()),
      throwsA(
        _failure(
          message: HttpClientRegistrationRepository.connectionErrorMessage,
        ),
      ),
    );
  });

  test('si el backend no responde a tiempo informa el problema de red',
      () async {
    final repository = _repository(
      (_) => Completer<http.Response>().future,
      timeout: const Duration(milliseconds: 10),
    );

    await expectLater(
      repository.register(validRegistration()),
      throwsA(
        _failure(
          message: HttpClientRegistrationRepository.connectionErrorMessage,
        ),
      ),
    );
  });
}
