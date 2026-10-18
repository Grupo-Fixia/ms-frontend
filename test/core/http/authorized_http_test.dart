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

  test('si el reintento también es 401, la sesión expiró (sin bucles)',
      () async {
    final session = _Session(renewTo: 'token-2');
    var calls = 0;

    await expectLater(
      _http(session).send((_) async {
        calls++;
        return http.Response('', 401);
      }),
      throwsA(isA<SessionExpiredException>()),
    );
    expect(calls, 2);
    expect(session.renewCalls, 1);
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
}
