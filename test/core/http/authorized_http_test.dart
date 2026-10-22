import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ms_frontend/core/http/authorized_http.dart';

class _Session {
  _Session({this.token = 'token-1', this.renewTo, this.canRenew = true});

  String? token;
  final String? renewTo;
  final bool canRenew;
  int renewCalls = 0;

  Future<bool> renew() async {
    renewCalls++;
    if (!canRenew) return false;
    token = renewTo;
    return true;
  }
}

AuthorizedHttp _http(_Session session, {Duration? timeout}) => AuthorizedHttp(
      accessToken: () => session.token,
      renewSession: session.renew,
      timeout: timeout ?? const Duration(seconds: 15),
    );

void main() {
  test('envía el access token y los headers de JSON', () async {
    late Map<String, String> sent;
    final response = await _http(_Session()).send((headers) async {
      sent = headers;
      return http.Response('ok', 200);
    });

    expect(response.statusCode, 200);
    expect(sent['Authorization'], 'Bearer token-1');
    expect(sent['Accept'], contains('application/json'));
  });

  test('devuelve tal cual las respuestas que no son 401', () async {
    final response =
        await _http(_Session()).send((_) async => http.Response('falla', 500));

    expect(response.statusCode, 500);
  });

  test('ante un 401 renueva la sesión una vez y reintenta', () async {
    final session = _Session(renewTo: 'token-2');
    final tokens = <String?>[];

    final response = await _http(session).send((headers) async {
      tokens.add(headers['Authorization']);
      return http.Response('', tokens.length == 1 ? 401 : 200);
    });

    expect(response.statusCode, 200);
    expect(tokens, ['Bearer token-1', 'Bearer token-2']);
    expect(session.renewCalls, 1);
  });

  test('si no se puede renovar, la sesión expiró', () async {
    final session = _Session(canRenew: false);

    await expectLater(
      _http(session).send((_) async => http.Response('', 401)),
      throwsA(isA<SessionExpiredException>()),
    );
  });

  test(
      'si el reintento con el token recién renovado también es 401, no saca '
      'al usuario: devuelve la respuesta (sin bucles)', () async {
    final session = _Session(renewTo: 'token-2');
    var calls = 0;

    final response = await _http(session).send((_) async {
      calls++;
      return http.Response('', 401);
    });

    expect(response.statusCode, 401);
    expect(calls, 2);
    expect(session.renewCalls, 1);
    expect(session.token, 'token-2', reason: 'la sesión sigue viva');
  });

  test('sin token no envía nada', () async {
    var calls = 0;

    await expectLater(
      _http(_Session(token: null)).send((_) async {
        calls++;
        return http.Response('', 200);
      }),
      throwsA(isA<SessionExpiredException>()),
    );
    expect(calls, 0);
  });

  test('si la renovación deja la sesión sin token, la sesión expiró', () async {
    final session = _Session(renewTo: null);

    await expectLater(
      _http(session).send((_) async => http.Response('', 401)),
      throwsA(isA<SessionExpiredException>()),
    );
  });

  test('sin red el backend no está disponible', () async {
    await expectLater(
      _http(_Session()).send((_) => throw http.ClientException('sin red')),
      throwsA(isA<BackendUnreachableException>()),
    );
  });

  test('si se agota el tiempo el backend no está disponible', () async {
    await expectLater(
      _http(_Session(), timeout: const Duration(milliseconds: 10))
          .send((_) => Completer<http.Response>().future),
      throwsA(isA<BackendUnreachableException>()),
    );
  });

  group('renovaciones simultáneas (hallazgo de QA en #35)', () {
    /// Sesión como la real: el refresh token sirve una vez, así que una
    /// segunda renovación con el mismo token falla.
    late String token;
    late int renewCalls;
    late Set<String> usedRefreshTokens;
    late String refreshToken;

    setUp(() {
      token = 'vencido';
      renewCalls = 0;
      usedRefreshTokens = {};
      refreshToken = 'r1';
    });

    Future<bool> renew() async {
      renewCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (!usedRefreshTokens.add(refreshToken)) return false;
      refreshToken = 'r${renewCalls + 1}';
      token = 'nuevo-$renewCalls';
      return true;
    }

    AuthorizedHttp client() =>
        AuthorizedHttp(accessToken: () => token, renewSession: renew);

    Future<http.Response> backend(Map<String, String> headers) async {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return http.Response(
        '',
        headers['Authorization'] == 'Bearer vencido' ? 401 : 200,
      );
    }

    test(
        'cinco peticiones con 401 a la vez: una renovación, ninguna pierde '
        'la sesión', () async {
      final authorized = client();

      final responses =
          await Future.wait(List.generate(5, (_) => authorized.send(backend)));

      expect(responses.map((r) => r.statusCode), everyElement(200));
      expect(renewCalls, 1);
    });

    test('una petición que salió con el token viejo reintenta sin renovar',
        () async {
      final authorized = client();
      // Otra petición ya renovó mientras esta viajaba.
      final response = await authorized.send((headers) async {
        final sentWith = headers['Authorization'];
        if (sentWith == 'Bearer vencido') {
          token = 'renovado-por-otra';
          return _status(401);
        }
        return _status(sentWith == 'Bearer renovado-por-otra' ? 200 : 500);
      });

      expect(response.statusCode, 200);
      expect(renewCalls, 0);
    });

    test('terminada una renovación, la siguiente vez se puede volver a renovar',
        () async {
      final authorized = client();
      await authorized.send(backend);
      token = 'vencido';

      final response = await authorized.send(backend);

      expect(response.statusCode, 200);
      expect(renewCalls, 2);
    });

    test('si la renovación lanza un error, la sesión expiró', () async {
      final authorized = AuthorizedHttp(
        accessToken: () => 'vencido',
        renewSession: () => throw StateError('falla'),
      );

      await expectLater(
        authorized.send(backend),
        throwsA(isA<SessionExpiredException>()),
      );
    });
  });
}

http.Response _status(int status) => http.Response('', status);
