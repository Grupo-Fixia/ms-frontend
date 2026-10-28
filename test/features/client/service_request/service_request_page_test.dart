import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/client/service_request/domain/service_request_draft.dart';
import 'package:ms_frontend/features/client/service_request/presentation/service_request_page.dart';

void main() {
  testWidgets('presupuesto requerido, positivo y conservado al corregirlo',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ServiceRequestPage()));
    final budget = find.byKey(const ValueKey('client-request-budget'));
    await tester.ensureVisible(budget);
    for (final input in ['0', '-10', 'texto', '', '1.001', '10000000000']) {
      await tester.enterText(budget, input);
      await tester.pump();
      expect(
        tester.widget<TextFormField>(budget).validator!(input),
        isNotNull,
      );
    }
    await tester.enterText(budget, '150000');
    await tester.pump();
    expect(tester.widget<TextFormField>(budget).validator!('150000'), isNull);
    expect(find.textContaining('El técnico podrá proponer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra formulario, privacidad y envío deshabilitado',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: const ServiceRequestPage(),
      ),
    );

    expect(find.text('Publicar un problema'), findsOneWidget);
    expect(find.text('Descripción del problema'), findsOneWidget);
    final description = find.byKey(
      const ValueKey('client-request-description'),
    );
    await tester.enterText(description, ' ');
    await tester.pump();
    await tester.enterText(description, '');
    await tester.pump();
    expect(find.text('La descripción es obligatoria.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Ubicación aproximada'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Ubicación aproximada'), findsOneWidget);
    expect(find.textContaining('dirección exacta se protege'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Fotografías (opcional)'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Fotografías (opcional)'), findsOneWidget);
    final submit = find.byKey(const ValueKey('client-request-submit'));
    await tester.scrollUntilVisible(
      submit,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('valida campos, deja agregar fotos y simula el envío',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ServiceRequestDraft? submittedDraft;
    var homeOpens = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: ServiceRequestPage(
          onSubmitted: (draft) => submittedDraft = draft,
          onOpenHome: () => homeOpens++,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('client-request-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plomería').last);
    await tester.enterText(
      find.byKey(const ValueKey('client-request-description')),
      'Hay una fuga en el lavaplatos.',
    );
    final budget = find.byKey(const ValueKey('client-request-budget'));
    await tester.ensureVisible(budget);
    await tester.enterText(budget, '150000,25');
    final expectedMoment =
        find.byKey(const ValueKey('client-request-expected-at'));
    await tester.scrollUntilVisible(
      expectedMoment,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(expectedMoment);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();
    final addPhoto = find.byKey(const ValueKey('client-request-add-photo'));
    await tester.scrollUntilVisible(
      addPhoto,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(addPhoto);
    await tester.pump();
    expect(
        find.byKey(const ValueKey('client-request-photo-0')), findsOneWidget);

    final submit = find.byKey(const ValueKey('client-request-submit'));
    await tester.scrollUntilVisible(
      submit,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    await tester.ensureVisible(budget);
    await tester.enterText(budget, '0');
    await tester.pump();
    await tester.scrollUntilVisible(
      submit,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await tester.ensureVisible(budget);
    await tester.enterText(budget, '150000,25');
    await tester.pump();
    await tester.scrollUntilVisible(
      submit,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(submittedDraft, isNotNull);
    expect(submittedDraft!.category.label, 'Plomería');
    expect(submittedDraft!.description, 'Hay una fuga en el lavaplatos.');
    expect(submittedDraft!.photoCount, 1);
    expect(submittedDraft!.budget!.amount, '150000.25');
    expect(find.byKey(const ValueKey('client-request-confirmation')),
        findsOneWidget);
    expect(
      find.textContaining('No se envió información a ningún servidor'),
      findsOneWidget,
    );

    await tester
        .tap(find.byKey(const ValueKey('client-request-confirmation-close')));
    await tester.pumpAndSettle();
    expect(homeOpens, 1);
  });

  testWidgets('no desborda en ancho móvil compacto', (tester) async {
    tester.view.physicalSize = const Size(320, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: ServiceRequestPage()),
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('client-request-budget')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra navegación móvil de cliente y permite volver a inicio',
      (tester) async {
    var homeOpens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ServiceRequestPage(onOpenHome: () => homeOpens++),
      ),
    );

    expect(find.byKey(const ValueKey('mobile-nav-publicar')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mobile-nav-inicio')));
    expect(homeOpens, 1);
  });
}
