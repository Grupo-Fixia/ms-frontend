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
import 'package:ms_frontend/features/company/applications/presentation/company_application_panel.dart';
import 'package:ms_frontend/features/company/technicians/domain/company_exceptions.dart';

const tech =
    AssociatedTechnician(userId: 'user-1', displayName: 'Técnico propio');
Map<String, Object?> saved() => {
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
http.Response json(int status, Object body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);
HttpCompanyApplicationRepository repo(MockClientHandler handler) =>
    HttpCompanyApplicationRepository(
        client: MockClient(handler),
        baseUrl: Uri.parse('http://localhost'),
        authorizedHttp: AuthorizedHttp(
            accessToken: () => 'test', renewSession: () async => false));

void main() {
  testWidgets(
      'una fuente inyectada, enviar y consultar lista y detalle reales del adaptador',
      (tester) async {
    var loads = 0;
    var posts = 0;
    final repository = repo((request) async {
      if (request.method == 'POST') {
        posts++;
        return json(201, saved());
      }
      return json(200, request.url.path.endsWith('a1') ? saved() : [saved()]);
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: CompanyApplicationPanel(
      sessionKey: 'company-1',
      serviceRequestId: 'r1',
      applications: repository,
      techniciansController: controllerFor(() async {
        loads++;
        return [tech];
      }),
      onSessionExpired: () {},
    )))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('company-technician-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Técnico propio').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('application-price')), '180000,25');
    await tester
        .ensureVisible(find.byKey(const ValueKey('application-price-submit')));
    await tester.tap(find.byKey(const ValueKey('application-price-submit')));
    await tester.pumpAndSettle();
    expect(posts, 1);
    expect(loads, 1);
    expect(find.text('Precio confirmado: 180.000,25 COP'), findsOneWidget);
    expect(find.text('180.000,25 COP'), findsOneWidget);
    await tester.ensureVisible(find.text('180.000,25 COP'));
    await tester.tap(find.text('180.000,25 COP'));
    await tester.pumpAndSettle();
    expect(find.text('Postulación empresarial guardada'), findsOneWidget);
    expect(find.textContaining('Técnico propuesto: user-1'), findsWidgets);
  });

  testWidgets('lista tardía de otra sesión no entra en el selector actual',
      (tester) async {
    final old = Completer<List<AssociatedTechnician>>();
    final repository = repo((_) async => json(200, []));
    Future<void> show(String session,
            Future<List<AssociatedTechnician>> Function() load) =>
        tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: CompanyApplicationPanel(
          sessionKey: session,
          serviceRequestId: 'r1',
          applications: repository,
          techniciansController: controllerFor(load),
          onSessionExpired: () {},
        ))));
    await show('old', () => old.future);
    await tester.pump();
    await show('new', () async => []);
    await tester.pumpAndSettle();
    old.complete([tech]);
    await tester.pumpAndSettle();
    expect(find.text('Tu empresa todavía no tiene técnicos asociados.'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('company-technician-selector')),
        findsNothing);
  });

  testWidgets('expiración de sesión se delega al flujo anfitrión',
      (tester) async {
    var expired = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CompanyApplicationPanel(
      sessionKey: 'company',
      serviceRequestId: 'r1',
      applications: repo((_) async => json(200, [])),
      techniciansController: controllerFor(() async =>
          throw const CompanyFailure('Sesión expirada',
              isSessionExpired: true)),
      onSessionExpired: () {
        expired++;
      },
    ))));
    await tester.pumpAndSettle();
    expect(expired, 1);
    expect(find.text('Sesión expirada'), findsOneWidget);
    expect(find.byKey(const ValueKey('company-technician-selector')),
        findsNothing);
  });
}
