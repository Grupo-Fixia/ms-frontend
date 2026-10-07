import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/features/auth/data/http_auth_repository.dart';
import 'package:ms_frontend/features/auth/domain/auth_exceptions.dart';
import 'package:ms_frontend/features/auth/domain/user_profile.dart';

import 'fake_auth_repository.dart';

HttpAuthRepository _repository(
  Future<http.Response> Function(http.Request request) handler, {
  Duration timeout = const Duration(seconds: 5),
}) =>
    HttpAuthRepository(
      client: MockClient(handler),
      baseUrl: Uri.parse('http://localhost'),
      timeout: timeout,
    );

/// Respuesta JSON en UTF-8 sin charset, como `application/problem+json`.
http.Response _json(Object body, int status) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: const {'content-type': 'application/problem+json'},
    );

Future<AuthFailure> _failureOf(Future<Object?> call) async {
  try {
    await call;
  } on AuthFailure catch (failure) {
    return failure;
  }
  fail('Se esperaba un AuthFailure');
}

void main() {
  group('login', () {
    test('envía el correo y la contraseña y devuelve los tokens', () async {
      late http.Request sent;
      final repository = _repository((request) async {
        sent = request;
        return _json({
          'accessToken': 'a',
          'refreshToken': 'r',
          'tokenType': 'Bearer',
          'expiresIn': 900,
        }, 200);
      });

      final session = await repository.login(
        email: '  ana@fixia.com ',
        password: 'Segura123',
      );

      expect(sent.method, 'POST');
      expect(sent.url.toString(), 'http://localhost/api/users/auth/login');
      expect(jsonDecode(sent.body), {
        'email': 'ana@fixia.com',
        'password': 'Segura123',
      });
      expect(session.accessToken, 'a');
      expect(session.refreshToken, 'r');
      expect(session.expiresIn, const Duration(seconds: 900));
    });

    test('con 401 usa el detalle del backend, con sus tildes', () async {
      final repository = _repository(
        (_) async => _json({
          'title': 'No autenticado',
          'status': 401,
          'detail': 'Credenciales inválidas',
        }, 401),
      );

      final failure = await _failureOf(
        repository.login(email: 'ana@fixia.com', password: 'mala'),
      );

      expect(failure.message, 'Credenciales inválidas');
    });

    test('con 401 sin detalle usa un mensaje genérico', () async {
      final repository = _repository((_) async => http.Response('', 401));

      final failure = await _failureOf(
        repository.login(email: 'ana@fixia.com', password: 'mala'),
      );

      expect(failure.message, 'Correo o contraseña incorrectos.');
    });

    test('con 400 devuelve los errores por campo', () async {
      final repository = _repository(
        (_) async => _json({
          'detail': 'Hay datos que debe corregir',
          'errors': [
            {'field': 'email', 'message': 'El correo electrónico es obligatorio'},
            {'field': 'password', 'message': 'La contraseña es obligatoria'},
          ],
        }, 400),
      );

      final failure = await _failureOf(
        repository.login(email: '', password: ''),
      );

      expect(failure.message, 'Hay datos que debe corregir');
      expect(failure.fieldErrors, {
        'email': 'El correo electrónico es obligatorio',
        'password': 'La contraseña es obligatoria',
      });
    });

    test('con un error del servidor no filtra detalles', () async {
      final repository = _repository(
        (_) async => _json({'detail': 'NullPointerException en AuthService'}, 500),
      );

      final failure = await _failureOf(
        repository.login(email: 'ana@fixia.com', password: 'x'),
      );

      expect(failure.message, isNot(contains('NullPointer')));
      expect(failure.message, contains('más tarde'));
    });

    test('con 200 pero sin tokens falla en lugar de iniciar sesión', () async {
      final repository = _repository((_) async => _json({'foo': 'bar'}, 200));

      await expectLater(
        repository.login(email: 'ana@fixia.com', password: 'x'),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('sin conexión avisa que no se pudo contactar el servicio', () async {
      final repository = _repository(
        (_) async => throw http.ClientException('connection refused'),
      );

      final failure = await _failureOf(
        repository.login(email: 'ana@fixia.com', password: 'x'),
      );

      expect(failure.message, contains('conectar con el servicio'));
    });

    test('si el servicio no responde a tiempo corta con error de conexión',
        () async {
      final repository = _repository(
        (_) => Completer<http.Response>().future,
        timeout: const Duration(milliseconds: 20),
      );

      final failure = await _failureOf(
        repository.login(email: 'ana@fixia.com', password: 'x'),
      );

      expect(failure.message, contains('conectar con el servicio'));
    });
  });

  group('refresh', () {
    test('envía el refresh token y devuelve la sesión rotada', () async {
      late http.Request sent;
      final repository = _repository((request) async {
        sent = request;
        return _json({
          'accessToken': 'a2',
          'refreshToken': 'r2',
          'tokenType': 'Bearer',
          'expiresIn': 900,
        }, 200);
      });

      final session = await repository.refresh('r1');

      expect(sent.method, 'POST');
      expect(sent.url.toString(), 'http://localhost/api/users/auth/refresh');
      expect(jsonDecode(sent.body), {'refreshToken': 'r1'});
      expect(session.accessToken, 'a2');
      expect(session.refreshToken, 'r2');
    });

    test('con 401 marca el fallo como no autorizado', () async {
      final repository = _repository(
        (_) async => _json({'detail': 'Refresh token inválido o expirado'}, 401),
      );

      final failure = await _failureOf(repository.refresh('usado'));

      expect(failure.isUnauthorized, isTrue);
    });

    test('con un error del servidor NO es no autorizado: el token se conserva',
        () async {
      final repository = _repository((_) async => http.Response('', 500));

      final failure = await _failureOf(repository.refresh('r1'));

      expect(failure.isUnauthorized, isFalse);
    });

    test('sin conexión NO es no autorizado', () async {
      final repository = _repository(
        (_) async => throw http.ClientException('sin red'),
      );

      final failure = await _failureOf(repository.refresh('r1'));

      expect(failure.isUnauthorized, isFalse);
    });
  });

  group('fetchProfile', () {
    test('envía el access token y mapea la cuenta y el rol', () async {
      late http.Request sent;
      final repository = _repository((request) async {
        sent = request;
        return _json({
          'id': fixtureProfile.id,
          'email': 'ana@fixia.com',
          'firstName': 'Ana',
          'lastName': 'Pérez',
          'role': 'PROFESSIONAL',
        }, 200);
      });

      final profile = await repository.fetchProfile('access-token');

      expect(sent.method, 'GET');
      expect(sent.url.toString(), 'http://localhost/api/users/me');
      expect(sent.headers['Authorization'], 'Bearer access-token');
      expect(profile.fullName, 'Ana Pérez');
      expect(profile.role, UserRole.professional);
    });

    test('un rol desconocido no rompe el perfil', () async {
      final repository = _repository(
        (_) async => _json({
          'id': fixtureProfile.id,
          'email': 'ana@fixia.com',
          'firstName': 'Ana',
          'lastName': 'Pérez',
          'role': 'SUPERVISOR',
        }, 200),
      );

      final profile = await repository.fetchProfile('t');

      expect(profile.role, isNull);
    });

    test('con 401 avisa que la sesión expiró', () async {
      final repository = _repository((_) async => http.Response('', 401));

      final failure = await _failureOf(repository.fetchProfile('vencido'));

      expect(failure.message, 'Tu sesión expiró. Inicia sesión de nuevo.');
      expect(failure.isUnauthorized, isTrue);
    });
  });

  group('logout', () {
    test('envía el access token y el refresh token', () async {
      late http.Request sent;
      final repository = _repository((request) async {
        sent = request;
        return http.Response('', 204);
      });

      await repository.logout(fixtureSession);

      expect(sent.method, 'POST');
      expect(sent.url.toString(), 'http://localhost/api/users/auth/logout');
      expect(sent.headers['Authorization'], 'Bearer access-token');
      expect(jsonDecode(sent.body), {'refreshToken': 'refresh-token'});
    });

    test('con 401 lanza AuthFailure', () async {
      final repository = _repository((_) async => http.Response('', 401));

      await expectLater(
        repository.logout(fixtureSession),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('sin conexión lanza AuthFailure', () async {
      final repository = _repository(
        (_) async => throw http.ClientException('sin red'),
      );

      await expectLater(
        repository.logout(fixtureSession),
        throwsA(isA<AuthFailure>()),
      );
    });
  });

  test('AuthSession.toString no expone los tokens', () {
    expect(fixtureSession.toString(), isNot(contains('access-token')));
    expect(fixtureSession.toString(), isNot(contains('refresh-token')));
  });
}
