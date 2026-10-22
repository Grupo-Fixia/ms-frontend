import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/auth/login/application/session_store.dart';
import 'package:ms_frontend/features/auth/login/domain/user_profile.dart';
import 'package:ms_frontend/features/dev_sandbox/demo_flow.dart';
import 'package:ms_frontend/main.dart';

import 'features/auth/login/fake_auth_repository.dart';
import 'features/auth/registration/fake_repository.dart';
import 'features/technician/profile/fake_repository.dart';
import 'features/technician/profile/fixtures.dart';

/// Flujo entre pantallas de la app real (sin el sandbox): postulación,
/// postulantes, perfil, selección, cotización y decisión.

const _technician = UserProfile(
  id: 'usr-tec',
  email: 'tecnico@fixia.com',
  firstName: 'Tomás',
  lastName: 'Rojas',
  role: UserRole.professional,
);

Future<void> _pump(
  WidgetTester tester,
  DemoFlow demo,
  UserProfile profile,
) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = SessionStore()..start(fixtureSession, profile);
  await tester.pumpWidget(
    FixiaApp(
      key: UniqueKey(),
      clientRegistrationRepository: FakeAccountRegistrationRepository(),
      technicianRegistrationRepository: FakeAccountRegistrationRepository(),
      technicianProfileRepository:
          FakeTechnicianProfileRepository(profile: emptyProfile),
      authRepository: FakeAuthRepository(),
      sessionStorage: FakeSessionStorage(),
      sessionStore: store,
      demoFlow: demo,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _keyStartsWith(String prefix) => find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> && key.value.startsWith(prefix);
    });

void _pop(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator)).pop();

void main() {
  testWidgets('el flujo completo se recorre desde las pantallas de la app',
      (tester) async {
    final demo = DemoFlow(latency: Duration.zero);

    // Técnico: se postula desde sus solicitudes.
    await _pump(tester, demo, _technician);
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.technicianOpportunities);
    await tester.pumpAndSettle();
    await _tapKey(tester, 'technician-opportunity-detail-fuga-lavaplatos');
    await _tapKey(tester, 'technician-apply-fuga-lavaplatos');
    await _tapKey(tester, 'apply-confirm-button');
    expect(find.text('Postulada'), findsOneWidget);

    // Cliente: abre postulantes desde su inicio, ve el perfil y selecciona.
    await _pump(tester, demo, _clientProfile);
    await _tapKey(tester, 'client-view-applicants');
    expect(find.text('Carlos Ramírez'), findsOneWidget);
    await tester.tap(_keyStartsWith('applicant-select-').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('select-provider-confirm')));
    await tester.pumpAndSettle();

    // Técnico: el botón cambia a cotizar y abre el formulario.
    await _pump(tester, demo, _technician);
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.technicianOpportunities);
    await tester.pumpAndSettle();
    expect(find.text('Cotizar'), findsOneWidget);
    await _tapKey(tester, 'technician-opportunity-detail-fuga-lavaplatos');
    await _tapKey(tester, 'technician-quote-fuga-lavaplatos');
    expect(find.byKey(const ValueKey('quotation-labor')), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('quotation-labor')), '90000');
    await tester.enterText(
        find.byKey(const ValueKey('quotation-scope')), 'Cambio de sifón');
    await tester.enterText(
        find.byKey(const ValueKey('quotation-conditions')), 'Garantía');
    for (final key in ['quotation-valid-until', 'quotation-agreed-at']) {
      await tester.ensureVisible(find.byKey(ValueKey(key)));
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }
    await _tapKey(tester, 'quotation-submit');
    expect(find.byKey(const ValueKey('quotation-sent')), findsOneWidget);

    // Cliente: revisa y acepta la cotización.
    await _pump(tester, demo, _clientProfile);
    final review = find.byTooltip('Revisar cotización');
    await tester.ensureVisible(review);
    await tester.tap(review);
    await tester.pumpAndSettle();
    await _tapKey(tester, 'quotation-accept');
    await _tapKey(tester, 'accept-confirm');
    expect(find.text('ACEPTADA'), findsOneWidget);
    _pop(tester);
  });
  testWidgets('el cliente abre el perfil de un técnico recomendado',
      (tester) async {
    await _pump(tester, DemoFlow(latency: Duration.zero), _clientProfile);

    await _tapKey(tester, 'client-technician-profile-ana-garcia');

    expect(find.byKey(const ValueKey('provider-profile-body')), findsOneWidget);
    expect(find.text('Ana García'), findsWidgets);
    expect(find.text('Seleccionar prestador'), findsNothing);
  });

  testWidgets('el cliente envía una contraoferta al rechazar', (tester) async {
    await _pump(tester, DemoFlow(latency: Duration.zero), _clientProfile);

    await _tapKey(tester, 'client-quote-lamparas-sala');
    await _tapKey(tester, 'quotation-reject');
    expect(
      tester
          .widget<FilledButton>(
              find.byKey(const ValueKey('counter-offer-confirm')))
          .onPressed,
      isNull,
    );
    await tester.enterText(
        find.byKey(const ValueKey('counter-offer-amount')), '250000');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('counter-offer-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('RECHAZADA'), findsOneWidget);
    expect(find.text('Contraoferta enviada'), findsOneWidget);
    expect(find.textContaining('250.000'), findsWidgets);
  });
  testWidgets('el cliente rechaza y acepta cotizaciones de ejemplo',
      (tester) async {
    await _pump(tester, DemoFlow(latency: Duration.zero), _clientProfile);

    await _tapKey(tester, 'client-quote-lamparas-sala');
    await _tapKey(tester, 'quotation-reject');
    await tester.enterText(
        find.byKey(const ValueKey('reject-reason')), 'Muy costosa');
    await _tapKey(tester, 'reject-confirm');
    expect(find.text('RECHAZADA'), findsOneWidget);
    _pop(tester);
    await tester.pumpAndSettle();

    await _tapKey(tester, 'client-quote-pintura-habitacion');
    expect(find.text('Cotización de Sofía Méndez'), findsOneWidget);
    await _tapKey(tester, 'quotation-accept');
    await _tapKey(tester, 'accept-confirm');
    expect(find.text('ACEPTADA'), findsOneWidget);
    _pop(tester);
    await tester.pumpAndSettle();

    await _tapKey(tester, 'client-quote-cerradura-puerta');
    expect(find.text('VENCIDA'), findsOneWidget);
    expect(find.byKey(const ValueKey('quotation-accept')), findsNothing);
  });
}

const _clientProfile = UserProfile(
  id: 'usr-cli',
  email: 'cliente@fixia.com',
  firstName: 'Clara',
  lastName: 'Gómez',
  role: UserRole.client,
);
