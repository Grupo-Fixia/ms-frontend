import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/features/chat/domain/service_chat.dart';
import 'package:ms_frontend/features/chat/infrastructure/http_service_chat_repository.dart';

http.Response _json(int status, Object? body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status,
        headers: {'content-type': 'application/json'});

HttpServiceChatRepository _repo(MockClientHandler handler,
        {Duration timeout = const Duration(seconds: 15)}) =>
    HttpServiceChatRepository(
      client: MockClient(handler),
      baseUrl: Uri.parse('http://services.local'),
      authorizedHttp: AuthorizedHttp(
        accessToken: () => 't',
        renewSession: () async => false,
        timeout: timeout,
      ),
    );

const _client = ChatConversation(
  participant: ChatParticipant.client,
  contractId: 'c1',
  serviceRequestId: 'r1',
);
const _technician = ChatConversation(
  participant: ChatParticipant.technician,
  contractId: 'c1',
  serviceRequestId: 'r1',
);

Map<String, Object?> _message(String id, {bool mine = false}) => {
      'id': id,
      'contractId': 'c1',
      'serviceRequestId': 'r1',
      'senderId': 'u1',
      'senderRole': 'CLIENT',
      'recipientId': 'u2',
      'body': 'Hola $id',
      'clientMessageId': 'cm-$id',
      'createdAt': '2026-11-10T14:05:12.123456Z',
      'mine': mine,
    };

void main() {
  test('cliente lee por su solicitud con after y wait', () async {
    late http.Request asked;
    final repo = _repo((r) async {
      asked = r;
      return _json(200, {
        'items': [
          _message('a', mine: true),
          {'id': 'roto'}
        ],
        'nextCursor': 'n1',
        'hasMore': true,
        'open': true,
      });
    });

    final page = await repo.messages(_client, after: 'c0', wait: 25);

    expect(asked.method, 'GET');
    expect(asked.url.path, '/api/services/requests/r1/messages');
    expect(asked.url.queryParameters, {'after': 'c0', 'wait': '25'});
    expect(asked.headers['Authorization'], 'Bearer t');
    expect(page.items.single.mine, isTrue);
    expect(page.items.single.clientMessageId, 'cm-a');
    expect(page.nextCursor, 'n1');
    expect(page.hasMore, isTrue);
    expect(page.open, isTrue);
  });

  test('técnico lee por el contrato; sin cursor nuevo conserva el anterior',
      () async {
    late Uri url;
    final repo = _repo((r) async {
      url = r.url;
      return _json(200, {'items': [], 'open': false});
    });
    final page = await repo.messages(_technician, after: 'c9');
    expect(url.path, '/api/services/contracts/c1/messages');
    expect(url.queryParameters, {'after': 'c9'});
    expect(page.nextCursor, 'c9');
    expect(page.open, isFalse);
  });

  test('el long polling usa un plazo mayor que el general', () async {
    final repo = _repo(
      (_) => Future.delayed(
          const Duration(milliseconds: 50), () => _json(200, {'items': []})),
      timeout: const Duration(milliseconds: 10),
    );
    // Sin wait, el plazo general corta la petición.
    await expectLater(repo.messages(_client),
        throwsA(isA<ChatFailure>().having((f) => f.isConnection, 'red', true)));
    // Con wait, espera lo del long polling.
    final page = await repo.messages(_client, wait: 25);
    expect(page.items, isEmpty);
  });

  test('envía el texto limpio con clientMessageId', () async {
    late http.Request asked;
    final repo = _repo((r) async {
      asked = r;
      return _json(201, _message('m1', mine: true));
    });

    final message = await repo.send(_technician,
        body: '  Voy en camino  ', clientMessageId: 'cm-1');

    expect(asked.method, 'POST');
    expect(asked.url.path, '/api/services/contracts/c1/messages');
    expect(jsonDecode(asked.body),
        {'body': 'Voy en camino', 'clientMessageId': 'cm-1'});
    expect(message.id, 'm1');
  });

  test('un reintento que ya existía (200) devuelve el mismo mensaje', () async {
    final repo = _repo((_) async => _json(200, _message('m1', mine: true)));
    final message =
        await repo.send(_client, body: 'Hola', clientMessageId: 'cm-m1');
    expect(message.id, 'm1');
  });

  test('vacío o muy largo no llega al backend', () async {
    var calls = 0;
    final repo = _repo((_) async {
      calls++;
      return _json(201, _message('m1'));
    });
    for (final body in ['   ', 'x' * 2001]) {
      await expectLater(repo.send(_client, body: body, clientMessageId: 'k'),
          throwsA(isA<ChatFailure>()));
    }
    expect(calls, 0);
  });

  test('409: conversación cerrada', () async {
    final repo =
        _repo((_) async => _json(409, {'title': 'Conversación cerrada'}));
    expect(
      () => repo.send(_client, body: 'Hola', clientMessageId: 'k'),
      throwsA(isA<ChatFailure>()
          .having((f) => f.isClosed, 'cerrada', isTrue)
          .having((f) => f.message, 'message', 'Conversación cerrada')),
    );
  });

  test('403 y 404: sin acceso, sin reintentar', () async {
    for (final status in [403, 404]) {
      final repo = _repo((_) async => _json(status, {}));
      await expectLater(
        repo.messages(_client),
        throwsA(isA<ChatFailure>()
            .having((f) => f.message, 'message',
                HttpServiceChatRepository.notFoundMessage)
            .having((f) => f.isConnection, 'red', isFalse)),
      );
    }
  });

  test('5xx se trata como caída temporal', () {
    final repo = _repo((_) async => _json(503, {}));
    expect(() => repo.messages(_client),
        throwsA(isA<ChatFailure>().having((f) => f.isConnection, 'red', true)));
  });

  test('sin red y sesión vencida', () async {
    await expectLater(
      _repo((_) async => throw http.ClientException('caído')).messages(_client),
      throwsA(isA<ChatFailure>().having((f) => f.isConnection, 'red', true)),
    );
    final expired = HttpServiceChatRepository(
      client: MockClient((_) async => _json(401, {})),
      baseUrl: Uri.parse('http://services.local'),
      authorizedHttp: AuthorizedHttp(
          accessToken: () => 't', renewSession: () async => false),
    );
    await expectLater(
      expired.messages(_client),
      throwsA(isA<ChatFailure>()
          .having((f) => f.isSessionExpired, 'expired', isTrue)),
    );
  });

  test('respuesta inválida', () {
    final repo = _repo((_) async => _json(200, {'sin': 'items'}));
    expect(() => repo.messages(_client), throwsA(isA<ChatFailure>()));
    final bad = _repo((_) async => _json(201, {'id': 'x'}));
    expect(() => bad.send(_client, body: 'Hola', clientMessageId: 'k'),
        throwsA(isA<ChatFailure>()));
  });
}
