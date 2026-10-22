import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/features/technician/opportunities/domain/opportunity_exceptions.dart';
import 'package:ms_frontend/features/technician/opportunities/infrastructure/http_opportunity_repository.dart';

/// Respuesta como la de ms-services: JSON en UTF-8 sin charset en el header.
http.Response _json(int status, Object? body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json'},
    );

HttpOpportunityRepository _repository(MockClientHandler handler) =>
    HttpOpportunityRepository(
      client: MockClient(handler),
      baseUrl: Uri.parse('http://localhost'),
      authorizedHttp: AuthorizedHttp(
        accessToken: () => 'token-1',
        renewSession: () async => false,
      ),
    );

TypeMatcher<OpportunityFailure> _failure(String message) =>
    isA<OpportunityFailure>().having((f) => f.message, 'message', message);

Map<String, Object?> _item(String id, {String category = 'PLUMBING'}) => {
      'id': id,
      'category': category,
      'description': 'Fuga de agua en el baño',
      'city': 'Bogotá',
      'zone': 'Chapinero',
      'latitude': 4.65,
      'longitude': -74,
      'expectedAt': '2026-10-25T15:00:00Z',
      'publishedAt': '2026-10-22T12:00:00Z',
    };

void main() {
  test('pide la página con límite y cursor, y la convierte', () async {
    late http.Request sent;
    final page = await _repository((request) async {
      sent = request;
      return _json(200, {
        'items': [
          _item('a'),
          _item('b', category: 'GARDENING'),
          {..._item('c'), 'expectedAt': 'mal'},
          {..._item('d'), 'zone': null},
          {..._item(''), 'description': 3},
          'basura',
        ],
        'nextCursor': 'cur-2',
      });
    }).fetchPage(limit: 20, cursor: 'cur 1/=');

    expect(sent.method, 'GET');
    expect(sent.url.path, '/api/services/opportunities');
    expect(sent.url.queryParameters, {'limit': '20', 'cursor': 'cur 1/='});
    expect(sent.headers['Authorization'], 'Bearer token-1');
    expect(page.items.map((o) => o.id), ['a']);
    final first = page.items.single;
    expect(first.category, ServiceCategory.plumbing);
    expect(first.zone, 'Chapinero');
    expect(first.longitude, -74.0);
    expect(first.expectedAt, DateTime.utc(2026, 10, 25, 15));
    expect(first.publishedAt, DateTime.utc(2026, 10, 22, 12));
    expect(page.nextCursor, 'cur-2');
  });

  test('sin cursor no lo envía y un nextCursor nulo o vacío termina', () async {
    for (final next in [null, '']) {
      late http.Request sent;
      final page = await _repository((request) async {
        sent = request;
        return _json(200, {'items': [], 'nextCursor': next});
      }).fetchPage(limit: 5);

      expect(sent.url.queryParameters, {'limit': '5'});
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    }
  });

  test('campos opcionales ausentes no rompen', () async {
    final page = await _repository((_) async => _json(200, {
          'items': [
            {
              'id': 'a',
              'category': 'PAINTING',
              'city': 'Bogotá',
              'zone': 'Suba',
              'expectedAt': '2026-10-25T15:00:00Z',
            },
          ],
          'nextCursor': null,
        })).fetchPage(limit: 5);

    final item = page.items.single;
    expect(item.description, '');
    expect(item.latitude, isNull);
    expect(item.publishedAt, isNull);
  });

  for (final body in [
    null,
    'texto',
    {'items': 'x'},
    []
  ]) {
    test('respuesta inválida ($body) es un error genérico', () async {
      await expectLater(
        _repository((_) async => _json(200, body)).fetchPage(limit: 5),
        throwsA(_failure(HttpOpportunityRepository.unexpectedErrorMessage)),
      );
    });
  }

  test('200 que no es JSON es un error genérico', () async {
    await expectLater(
      _repository((_) async => http.Response('<html>', 200))
          .fetchPage(limit: 5),
      throwsA(_failure(HttpOpportunityRepository.unexpectedErrorMessage)),
    );
  });

  for (final (status, message) in [
    (400, HttpOpportunityRepository.invalidQueryMessage),
    (403, HttpOpportunityRepository.forbiddenMessage),
    (503, HttpOpportunityRepository.eligibilityUnavailableMessage),
    (500, HttpOpportunityRepository.unexpectedErrorMessage),
  ]) {
    test('$status se traduce a un mensaje claro', () async {
      await expectLater(
        _repository((_) async => _json(status, {})).fetchPage(limit: 5),
        throwsA(_failure(message)),
      );
    });
  }

  test('si la sesión no se puede renovar, la sesión expiró', () async {
    await expectLater(
      _repository((_) async => http.Response('', 401)).fetchPage(limit: 5),
      throwsA(_failure(HttpOpportunityRepository.sessionExpiredMessage)
          .having((f) => f.isSessionExpired, 'isSessionExpired', isTrue)),
    );
  });

  test('sin red se pide revisar la conexión', () async {
    await expectLater(
      _repository((_) => throw http.ClientException('sin red'))
          .fetchPage(limit: 5),
      throwsA(_failure(HttpOpportunityRepository.connectionErrorMessage)
          .having((f) => f.isSessionExpired, 'isSessionExpired', isFalse)),
    );
  });
}
