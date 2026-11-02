import 'application_controller_fixture.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/features/company/technicians/domain/associated_technician.dart';
import 'package:ms_frontend/features/company/applications/infrastructure/http_company_application_repository.dart';
import 'package:ms_frontend/features/company/applications/infrastructure/http_company_opportunities_repository.dart';
import 'package:ms_frontend/features/company/applications/presentation/company_opportunities_panel.dart';
import 'package:ms_frontend/features/technician/applications/domain/application_exceptions.dart';

Map<String, Object?> opportunity(String id,
        {List<Object?> eligible = const ['user-1']}) =>
    {
      'id': id,
      'category': 'PLUMBING',
      'description': 'Reparar fuga $id',
      'city': 'Bogotá',
      'zone': 'Chapinero',
      'expectedAt': '2026-11-10T15:00:00Z',
      'budgetAmount': 200000,
      'budgetCurrency': 'COP',
      'eligibleTechnicianIds': eligible,
    };
http.Response response(int status, Object body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);
AuthorizedHttp auth() => AuthorizedHttp(
    accessToken: () => 'company-token', renewSession: () async => false);
HttpCompanyOpportunitiesRepository opportunities(MockClientHandler handler) =>
    HttpCompanyOpportunitiesRepository(
        client: MockClient(handler),
        baseUrl: Uri.parse('http://localhost'),
        authorizedHttp: auth());

void main() {
  test('contrato empresarial, cursor opaco e identidad del token', () async {
    final repo = opportunities((request) async {
      expect(request.url.path, '/api/services/opportunities');
      expect(
          request.url.queryParameters, {'limit': '20', 'cursor': 'a+/=cursor'});
      expect(request.headers['Authorization'], 'Bearer company-token');
      return response(200, {
        'items': [opportunity('r1')],
        'nextCursor': 'next'
      });
    });
    final page = await repo.fetchPage(limit: 20, cursor: 'a+/=cursor');
    expect(page.items.single.request.id, 'r1');
    expect(page.items.single.eligibleTechnicianIds, {'user-1'});
    expect(page.nextCursor, 'next');
  });
  test('página vacía con cursor no significa fin', () async {
    final page = await opportunities(
            (_) async => response(200, {'items': [], 'nextCursor': 'more'}))
        .fetchPage(limit: 20);
    expect(page.items, isEmpty);
    expect(page.nextCursor, 'more');
  });
  test('presupuesto histórico null', () async {
    final item = opportunity('r1')
      ..['budgetAmount'] = null
      ..['budgetCurrency'] = null;
    final page = await opportunities((_) async => response(200, {
          'items': [item],
          'nextCursor': null
        })).fetchPage(limit: 20);
    expect(page.items.single.budgetAmount, isNull);
  });
  for (final invalid in <Object?>[
    null,
    [],
    [''],
    ['user-1', 'user-1'],
    [42]
  ]) {
    test('rechaza elegibilidad inconsistente $invalid', () async {
      final item = opportunity('r1')..['eligibleTechnicianIds'] = invalid;
      await expectLater(
          opportunities((_) async => response(200, {
                'items': [item]
              })).fetchPage(limit: 20),
          throwsA(isA<ApplicationFailure>()));
    });
  }
  test('rechaza solicitudes incompletas, duplicadas y cursor inválido',
      () async {
    for (final body in [
      {
        'items': [
          {
            'id': 'r1',
            'eligibleTechnicianIds': ['user-1']
          }
        ]
      },
      {
        'items': [opportunity('r1'), opportunity('r1')]
      },
      {'items': [], 'nextCursor': 5},
      {'items': [], 'nextCursor': ''},
    ]) {
      await expectLater(
          opportunities((_) async => response(200, body)).fetchPage(limit: 20),
          throwsA(isA<ApplicationFailure>()));
    }
  });
  for (final code in [400, 403, 503, 500]) {
    test('maneja consulta $code sin inventar oportunidades', () async {
      await expectLater(
          opportunities((_) async => response(code, {})).fetchPage(limit: 20),
          throwsA(isA<ApplicationFailure>()));
    });
  }
  test('expiración y fallo de red', () async {
    await expectLater(
        opportunities((_) async => response(401, {})).fetchPage(limit: 20),
        throwsA(isA<ApplicationFailure>()
            .having((e) => e.isSessionExpired, 'sesión', true)));
    await expectLater(
        opportunities((_) async => throw http.ClientException('offline'))
            .fetchPage(limit: 20),
        throwsA(isA<ApplicationFailure>()));
  });

  Future<void> show(WidgetTester tester, MockClientHandler handler,
      {String session = 'company',
      Future<List<AssociatedTechnician>> Function()? load,
      VoidCallback? expired}) async {
    final client = MockClient(handler);
    final authorized = auth();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: CompanyOpportunitiesPanel(
      sessionKey: session,
      opportunities: HttpCompanyOpportunitiesRepository(
          client: client,
          baseUrl: Uri.parse('http://localhost'),
          authorizedHttp: authorized),
      applications: HttpCompanyApplicationRepository(
          client: client,
          baseUrl: Uri.parse('http://localhost'),
          authorizedHttp: authorized),
      techniciansController: controllerFor(load ??
          () async => const [
                AssociatedTechnician(userId: 'user-1', displayName: 'Carlos'),
                AssociatedTechnician(userId: 'user-2', displayName: 'Luisa')
              ]),
      onSessionExpired: expired ?? () {},
    )))));
  }

  Future<void> select(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('company-opportunity-r1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
        find.byKey(const ValueKey('company-technician-selector')));
    await tester.tap(find.byKey(const ValueKey('company-technician-selector')));
    await tester.pumpAndSettle();
  }

  testWidgets('selecciona solicitud y userId elegible; POST y GET confirmados',
      (tester) async {
    Map<String, dynamic>? submitted;
    var posts = 0;
    final saved = {
      'id': 'a1',
      'status': 'APPLIED',
      'providerType': 'COMPANY',
      'technicianId': 'user-1',
      'proposedAmount': 180000.25,
      'currency': 'COP',
      'serviceRequest': {
        'id': 'r1',
        'category': 'PLUMBING',
        'city': 'Bogotá',
        'zone': 'Chapinero'
      }
    };
    await show(tester, (request) async {
      if (request.url.path.endsWith('opportunities')) {
        return response(200, {
          'items': [opportunity('r1')],
          'nextCursor': null
        });
      }
      if (request.method == 'POST') {
        posts++;
        submitted = jsonDecode(request.body);
        return response(201, saved);
      }
      return response(200, request.url.path.endsWith('a1') ? saved : [saved]);
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('company-technician-selector')),
        findsNothing);
    await select(tester);
    expect(find.text('Luisa'), findsNothing);
    await tester.tap(find.text('Carlos').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('application-price')), '180000,25');
    await tester
        .ensureVisible(find.byKey(const ValueKey('application-price-submit')));
    await tester.tap(find.byKey(const ValueKey('application-price-submit')));
    await tester.pumpAndSettle();
    expect(submitted, {
      'serviceRequestId': 'r1',
      'technicianId': 'user-1',
      'proposedAmount': 180000.25,
      'currency': 'COP'
    });
    expect(posts, 1);
    expect(find.text('Precio confirmado: 180.000,25 COP'), findsOneWidget);
  });
  testWidgets('no cambia oportunidad ni actualiza durante un envío',
      (tester) async {
    final pending = Completer<http.Response>();
    var posts = 0;
    await show(tester, (request) async {
      if (request.method == 'POST') {
        posts++;
        return pending.future;
      }
      return response(200, {
        'items': [
          opportunity('r1'),
          opportunity('r2', eligible: ['user-2'])
        ]
      });
    });
    await tester.pumpAndSettle();
    await select(tester);
    await tester.tap(find.text('Carlos').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('application-price')), '150000');
    await tester
        .ensureVisible(find.byKey(const ValueKey('application-price-submit')));
    await tester.tap(find.byKey(const ValueKey('application-price-submit')));
    await tester.pump();
    expect(
        tester
            .widget<ListTile>(
                find.byKey(const ValueKey('company-opportunity-r2')))
            .onTap,
        isNull);
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Actualizar oportunidades'))
            .onPressed,
        isNull);
    expect(posts, 1);
    pending.complete(response(409, {}));
    await tester.pumpAndSettle();
    expect(posts, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('cambiar solicitud limpia selección y precio anteriores',
      (tester) async {
    await show(
        tester,
        (_) async => response(200, {
              'items': [
                opportunity('r1'),
                opportunity('r2', eligible: ['user-2'])
              ]
            }));
    await tester.pumpAndSettle();
    await select(tester);
    await tester.tap(find.text('Carlos').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('application-price')), '150000');
    await tester
        .ensureVisible(find.byKey(const ValueKey('company-opportunity-r2')));
    await tester.tap(find.byKey(const ValueKey('company-opportunity-r2')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(
                find.byKey(const ValueKey('application-price')))
            .controller!
            .text,
        isEmpty);
    await tester.ensureVisible(
        find.byKey(const ValueKey('company-technician-selector')));
    await tester.tap(find.byKey(const ValueKey('company-technician-selector')));
    await tester.pumpAndSettle();
    expect(find.text('Carlos'), findsNothing);
    expect(find.text('Luisa'), findsWidgets);
  });
  testWidgets('paginación conserva páginas vacías y cursor', (tester) async {
    final cursors = <String?>[];
    await show(tester, (request) async {
      cursors.add(request.url.queryParameters['cursor']);
      return response(
          200,
          cursors.length == 1
              ? {'items': [], 'nextCursor': 'next'}
              : {
                  'items': [opportunity('r1')],
                  'nextCursor': null
                });
    });
    await tester.pumpAndSettle();
    expect(find.text('Ver más oportunidades'), findsOneWidget);
    await tester.tap(find.text('Ver más oportunidades'));
    await tester.pumpAndSettle();
    expect(cursors, [null, 'next']);
    expect(find.text('Reparar fuga r1'), findsOneWidget);
  });
  testWidgets('ID de perfil ajeno no se confunde con userId asociado',
      (tester) async {
    await show(
        tester,
        (_) async => response(200, {
              'items': [
                opportunity('r1', eligible: ['profile-1'])
              ]
            }));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('company-opportunity-r1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('no coinciden'), findsOneWidget);
    expect(find.byKey(const ValueKey('company-technician-selector')),
        findsNothing);
  });
  testWidgets('respuesta tardía de otra cuenta se descarta', (tester) async {
    final pending = Completer<http.Response>();
    await show(tester, (_) => pending.future, session: 'old');
    await tester.pump();
    await show(tester, (_) async => response(200, {'items': []}),
        session: 'new');
    await tester.pumpAndSettle();
    pending.complete(response(200, {
      'items': [opportunity('r1')]
    }));
    await tester.pumpAndSettle();
    expect(find.text('Reparar fuga r1'), findsNothing);
    expect(find.text('No hay oportunidades disponibles para tu empresa.'),
        findsOneWidget);
  });
  testWidgets('cursor repetido produce error y permite actualizar',
      (tester) async {
    await show(tester,
        (_) async => response(200, {'items': [], 'nextCursor': 'same'}));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver más oportunidades'));
    await tester.pumpAndSettle();
    expect(find.text('La lista de oportunidades cambió. Actualiza la lista.'),
        findsOneWidget);
  });
  testWidgets('sesión expirada se delega sin crear autenticación paralela',
      (tester) async {
    var expired = 0;
    await show(tester, (_) async => response(401, {}), expired: () {
      expired++;
    });
    await tester.pumpAndSettle();
    expect(expired, 1);
    expect(find.textContaining('Tu sesión expiró'), findsOneWidget);
  });
}
