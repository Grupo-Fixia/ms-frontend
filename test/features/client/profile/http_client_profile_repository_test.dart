import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/features/client/profile/domain/client_profile_exceptions.dart';
import 'package:ms_frontend/features/client/profile/domain/client_profile_update.dart';
import 'package:ms_frontend/features/client/profile/infrastructure/http_client_profile_repository.dart';

const _endpoint = 'http://localhost/api/users/clients/me/profile';

/// Respuesta como la de ms-users: JSON en UTF-8 sin charset en el header.
http.Response _json(int status, Object? body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json'},
    );

HttpClientProfileRepository _repository(MockClientHandler handler) =>
    HttpClientProfileRepository(
      client: MockClient(handler),
      baseUrl: Uri.parse('http://localhost'),
      authorizedHttp: AuthorizedHttp(
        accessToken: () => 'token-1',
        renewSession: () async => false,
      ),
    );

TypeMatcher<ClientProfileFailure> _failure(String message) =>
    isA<ClientProfileFailure>().having((f) => f.message, 'message', message);

const _profileJson = {
  'id': 'usr-1',
  'email': 'ana@fixia.com',
  'firstName': 'Ana María',
  'lastName': 'Pérez',
  'documentType': 'CC',
  'documentNumber': '1020304050',
  'phone': '+573001234567',
  'createdAt': '2026-10-01T12:00:00Z',
};

const _update = ClientProfileUpdate(
  firstName: 'Ana María',
  lastName: 'Pérez',
  phone: '+573001234567',
);

void main() {
  test('consulta el perfil con el token y lee las tildes en UTF-8', () async {
    late http.Request sent;
    final profile = await _repository((request) async {
      sent = request;
      return _json(200, _profileJson);
    }).fetchProfile();

    expect(sent.method, 'GET');
    expect(sent.url.toString(), _endpoint);
    expect(sent.headers['Authorization'], 'Bearer token-1');
    expect(profile.id, 'usr-1');
    expect(profile.firstName, 'Ana María');
    expect(profile.lastName, 'Pérez');
    expect(profile.documentType, 'CC');
    expect(profile.documentNumber, '1020304050');
    expect(profile.phone, '+573001234567');
    expect(profile.createdAt, DateTime.utc(2026, 10, 1, 12));
  });

  test('actualiza solo nombre, apellido y teléfono', () async {
    late http.Request sent;
    final saved = await _repository((request) async {
      sent = request;
      return _json(200, _profileJson);
    }).updateProfile(_update);

    expect(sent.method, 'PUT');
    expect(sent.url.toString(), _endpoint);
    expect(sent.headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(sent.body), {
      'firstName': 'Ana María',
      'lastName': 'Pérez',
      'phone': '+573001234567',
    });
    expect(saved.email, 'ana@fixia.com');
  });

  test('campos opcionales ausentes no rompen', () async {
    final profile = await _repository((_) async => _json(200, {
          'id': 'usr-1',
          'email': 'ana@fixia.com',
          'firstName': null,
          'phone': 3,
          'createdAt': 7,
        })).fetchProfile();

    expect(profile.firstName, '');
    expect(profile.lastName, '');
    expect(profile.phone, '');
    expect(profile.documentType, isNull);
    expect(profile.createdAt, isNull);
  });

  for (final body in [
    null,
    'texto',
    {'id': 'usr-1'},
    {'email': 'a@b.co'}
  ]) {
    test('respuesta inválida ($body) es un error genérico', () async {
      await expectLater(
        _repository((_) async => _json(200, body)).fetchProfile(),
        throwsA(_failure(HttpClientProfileRepository.unexpectedErrorMessage)),
      );
    });
  }

  test('200 que no es JSON es un error genérico', () async {
    await expectLater(
      _repository((_) async => http.Response('<html>', 200)).fetchProfile(),
      throwsA(_failure(HttpClientProfileRepository.unexpectedErrorMessage)),
    );
  });

  test('400 trae los errores por campo', () async {
    await expectLater(
      _repository((_) async => _json(400, {
            'detail': 'Hay datos que debe corregir',
            'errors': [
              {'field': 'phone', 'message': 'El teléfono no es válido'},
              {'field': 'phone', 'message': 'Otro'},
              {'field': 'x', 'message': ''},
              'basura',
            ],
          })).updateProfile(_update),
      throwsA(_failure(HttpClientProfileRepository.invalidDataMessage).having(
          (f) => f.fieldErrors,
          'fieldErrors',
          {'phone': 'El teléfono no es válido'})),
    );
  });

  test('400 sin errores por campo muestra el detail', () async {
    await expectLater(
      _repository((_) async => _json(400, {
            'detail': 'El cuerpo de la solicitud no es válido',
          })).updateProfile(_update),
      throwsA(_failure('El cuerpo de la solicitud no es válido')),
    );
  });

  for (final (status, message) in [
    (403, HttpClientProfileRepository.forbiddenMessage),
    (404, HttpClientProfileRepository.notFoundMessage),
    (500, HttpClientProfileRepository.unexpectedErrorMessage),
  ]) {
    test('$status se traduce a un mensaje claro', () async {
      await expectLater(
        _repository((_) async => _json(status, {})).fetchProfile(),
        throwsA(_failure(message)),
      );
    });
  }

  test('si la sesión no se puede renovar, la sesión expiró', () async {
    await expectLater(
      _repository((_) async => http.Response('', 401)).fetchProfile(),
      throwsA(_failure(HttpClientProfileRepository.sessionExpiredMessage)
          .having((f) => f.isSessionExpired, 'isSessionExpired', isTrue)),
    );
  });

  test('sin red se pide revisar la conexión', () async {
    await expectLater(
      _repository((_) => throw http.ClientException('sin red'))
          .updateProfile(_update),
      throwsA(_failure(HttpClientProfileRepository.connectionErrorMessage)),
    );
  });
}
