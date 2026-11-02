import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/backend_integrations.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/features/auth/login/application/session_store.dart';
import 'package:ms_frontend/features/auth/login/domain/user_profile.dart';
import 'package:ms_frontend/features/service_evidence/presentation/service_evidence_page.dart';
import 'package:ms_frontend/main.dart';
import '../auth/login/fake_auth_repository.dart';
import '../auth/registration/fake_repository.dart';
import '../technician/profile/fake_repository.dart';
import '../technician/profile/fixtures.dart';

void main() {
  for (final role in [UserRole.professional, UserRole.client]) {
    testWidgets(
        'navegación real de $role abre evidencias con el identificador correcto',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final paths = <String>[];
      final request = {
        'id': 'r1',
        'category': 'PLUMBING',
        'description': 'Servicio de prueba',
        'status': 'IN_PROGRESS',
        'approximateLocation': {'city': 'Bogotá', 'zone': 'Centro'},
        'expectedAt': '2026-11-10T15:00:00Z'
      };
      final contract = {
        'id': 'c1',
        'serviceRequestId': 'r1',
        'quotationId': 'q1',
        'clientId': 'client',
        'providerId': 'tech',
        'amount': 150000,
        'currency': 'COP',
        'scope': 'Reparación',
        'conditions': 'Condiciones',
        'agreedAt': '2026-11-10T15:00:00Z',
        'contractedAt': '2026-11-02T05:00:00Z',
        'serviceStatus': 'IN_PROGRESS',
        'serviceRequest': request,
        'timeline': []
      };
      final client = MockClient((req) async {
        paths.add(req.url.path);
        final p = req.url.path;
        Object body = [];
        if (p == '/api/services/contracts') body = [contract];
        if (p == '/api/services/contracts/c1' ||
            p == '/api/services/requests/r1/contract') body = contract;
        if (p == '/api/services/requests') body = [request];
        if (p == '/api/services/requests/r1') body = request;
        return http.Response(jsonEncode(body), 200,
            headers: {'content-type': 'application/json'});
      });
      final profile = UserProfile(
          id: role == UserRole.client ? 'client' : 'tech',
          email: 'test@example.invalid',
          firstName: 'Test',
          lastName: 'User',
          role: role);
      final backend = BackendIntegrations.http(
          client: client,
          usersBaseUrl: Uri.parse('http://localhost'),
          servicesBaseUrl: Uri.parse('http://localhost'),
          authorizedHttp: AuthorizedHttp(
              accessToken: () => 'token', renewSession: () async => false));
      await tester.pumpWidget(FixiaApp(
          backend: backend,
          clientRegistrationRepository: FakeAccountRegistrationRepository(),
          technicianRegistrationRepository: FakeAccountRegistrationRepository(),
          technicianProfileRepository:
              FakeTechnicianProfileRepository(profile: emptyProfile),
          authRepository: FakeAuthRepository(profile: profile),
          sessionStorage: FakeSessionStorage(),
          sessionStore: SessionStore()..start(fixtureSession, profile)));
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator).first).pushNamed(
          role == UserRole.professional
              ? AppRoutes.technicianJobs
              : '/cliente/solicitudes');
      await tester.pumpAndSettle();
      final tile = find.byType(ListTile).first;
      await tester.tap(tile);
      await tester.pumpAndSettle();
      await tester
          .ensureVisible(find.byKey(const ValueKey('open-service-evidence')));
      await tester.tap(find.byKey(const ValueKey('open-service-evidence')));
      await tester.pumpAndSettle();
      expect(find.byType(ServiceEvidencePage), findsOneWidget);
      expect(
          paths,
          contains(role == UserRole.professional
              ? '/api/services/contracts/c1/evidences'
              : '/api/services/requests/r1/evidences'));
      expect(find.byKey(const ValueKey('evidence-pick')),
          role == UserRole.professional ? findsOneWidget : findsNothing);
    });
  }
}
