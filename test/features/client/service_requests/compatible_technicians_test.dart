import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/client/service_requests/domain/compatible_technician.dart';
import 'package:ms_frontend/features/client/service_requests/domain/service_request_exceptions.dart';
import 'package:ms_frontend/features/client/service_requests/infrastructure/http_compatible_technicians_repository.dart';
import 'package:ms_frontend/features/client/service_requests/presentation/service_request_detail_page.dart';

http.Response _json(int status, Object? body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status,
        headers: {'content-type': 'application/json'});

HttpCompatibleTechniciansRepository _repo(MockClientHandler handler,
        {bool renew = false}) =>
    HttpCompatibleTechniciansRepository(
      client: MockClient(handler),
      baseUrl: Uri.parse('http://localhost'),
      authorizedHttp: AuthorizedHttp(
          accessToken: () => 't', renewSession: () async => renew),
    );

CompatibleTechnician _tech(String id, String name) => CompatibleTechnician(
      userId: id,
      displayName: name,
      categories: const [ServiceCategory.plumbing],
      city: 'Cali',
    );

void main() {
  group('HttpCompatibleTechniciansRepository', () {
    test('pide la página con límite y cursor y lee los técnicos', () async {
      late Uri asked;
      final repo = _repo((request) async {
        asked = request.url;
        return _json(200, {
          'items': [
            {
              'userId': 'u1',
              'displayName': 'Carlos G.',
              'categories': ['PLUMBING', 'DESCONOCIDA'],
              'city': 'Cali'
            },
            {'userId': '', 'displayName': 'sin id'},
            'basura',
          ],
          'nextCursor': 'abc',
        });
      });
      final page = await repo.list('r1', cursor: 'x');
      expect(asked.path, '/api/services/requests/r1/compatible-technicians');
      expect(asked.queryParameters, {'limit': '20', 'cursor': 'x'});
      expect(page.items.single.displayName, 'Carlos G.');
      expect(page.items.single.categories, [ServiceCategory.plumbing]);
      expect(page.nextCursor, 'abc');
      expect(page.hasMore, isTrue);
    });

    test('mapea los errores sin devolver una lista vacía', () async {
      Future<Object?> fail(int status, [Object? body]) async {
        try {
          await _repo((_) async => body is String
              ? http.Response(body, status)
              : _json(status, body)).list('r1');
          return null;
        } catch (e) {
          return e;
        }
      }

      expect('${await fail(503, {})}',
          HttpCompatibleTechniciansRepository.unavailableMessage);
      expect('${await fail(409, {})}',
          HttpCompatibleTechniciansRepository.closedMessage);
      expect('${await fail(404, {})}',
          HttpCompatibleTechniciansRepository.notFoundMessage);
      expect('${await fail(200, 'no es json')}',
          HttpCompatibleTechniciansRepository.unavailableMessage);
      expect('${await fail(200, {'items': 'x'})}',
          HttpCompatibleTechniciansRepository.unavailableMessage);
      final expired = await fail(401, {});
      expect(expired, isA<ServiceRequestFailure>());
      expect((expired! as ServiceRequestFailure).isSessionExpired, isTrue);
    });

    test('sin conexión lo dice', () async {
      final repo = _repo((_) async => throw http.ClientException('caído'));
      await expectLater(
          repo.list('r1'),
          throwsA(isA<ServiceRequestFailure>().having(
              (e) => e.message,
              'message',
              HttpCompatibleTechniciansRepository.connectionErrorMessage)));
    });
  });

  group('CompatibleTechniciansPanel', () {
    Future<void> pump(WidgetTester tester,
        Future<CompatibleTechniciansPage> Function(String?) load) async {
      await tester.pumpWidget(MaterialApp(
        theme: FixiaTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: CompatibleTechniciansPanel(load: load),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('muestra páginas, salta las vacías y carga más',
        (tester) async {
      final cursors = <String?>[];
      await pump(tester, (cursor) async {
        cursors.add(cursor);
        return switch (cursor) {
          null => const CompatibleTechniciansPage(items: [], nextCursor: 'c1'),
          'c1' => CompatibleTechniciansPage(
              items: [_tech('u1', 'Carlos Gómez')], nextCursor: 'c2'),
          _ => CompatibleTechniciansPage(items: [_tech('u2', 'Diana T.')]),
        };
      });
      expect(cursors, [null, 'c1']);
      expect(find.text('Carlos Gómez'), findsOneWidget);
      expect(find.text('CG'), findsOneWidget);
      expect(find.text('Plomería · Cali'), findsOneWidget);

      await tester
          .tap(find.byKey(const ValueKey('compatible-technicians-more')));
      await tester.pumpAndSettle();
      expect(find.text('Diana T.'), findsOneWidget);
      expect(find.byKey(const ValueKey('compatible-technicians-more')),
          findsNothing);
    });

    testWidgets('sin técnicos lo dice; si falla permite reintentar',
        (tester) async {
      var fail = true;
      await pump(tester, (_) async {
        if (fail) throw const ServiceRequestFailure('Matching caído');
        return const CompatibleTechniciansPage(items: []);
      });
      expect(find.text('Matching caído'), findsOneWidget);
      fail = false;
      await tester
          .tap(find.byKey(const ValueKey('compatible-technicians-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('compatible-technicians-empty')),
          findsOneWidget);
    });
  });
}
