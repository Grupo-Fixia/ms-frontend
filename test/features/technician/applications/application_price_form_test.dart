import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/technician/applications/presentation/application_price_form.dart';
import 'package:ms_frontend/features/technician/applications/domain/proposed_price.dart';

// Política exclusiva de las pruebas. No constituye una decisión de producto.
String? testPolicy(String? value) =>
    value == '150000' ? null : 'Precio inválido de prueba';

void main() {
  Future<void> show(
    WidgetTester tester,
    Future<void> Function(String) submit, {
    String request = 'r1',
  }) =>
      tester.pumpWidget(MaterialApp(
          home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ApplicationPriceForm(
            serviceRequestId: request,
            currencyLabel: 'COP',
            validatePrice: testPolicy,
            submit: (input) async {
              await submit(input);
              return ProposedPrice.tryParse(input)!;
            },
          ),
        ),
      )));
  Future<void> send(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('application-price-submit')));
    await tester.pump();
  }

  testWidgets('exige precio y aplica política proporcionada', (tester) async {
    var calls = 0;
    await show(tester, (_) async => calls++);
    await send(tester);
    expect(find.text('Ingresa el precio que propones.'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('application-price')), 'mal');
    await send(tester);
    expect(find.text('Precio inválido de prueba'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('conserva entrada y espera confirmación sin duplicar envío',
      (tester) async {
    var calls = 0;
    String? received;
    final pending = Completer<void>();
    await show(tester, (value) {
      calls++;
      received = value;
      return pending.future;
    });
    await tester.enterText(
        find.byKey(const ValueKey('application-price')), '150000');
    await send(tester);
    expect(received, '150000');
    expect(calls, 1);
    expect(find.byKey(const ValueKey('application-price-confirmed')),
        findsNothing);
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('application-price-submit')))
            .onPressed,
        isNull);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Postulación enviada.'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('application-price-submit')), findsNothing);
  });

  testWidgets('rechazo mantiene precio y no confirma éxito', (tester) async {
    await show(
        tester,
        (_) async => throw const ApplicationPriceFormFailure(
            'Ya existe una postulación'));
    await tester.enterText(
        find.byKey(const ValueKey('application-price')), '150000');
    await send(tester);
    await tester.pumpAndSettle();
    expect(find.text('Ya existe una postulación'), findsOneWidget);
    expect(find.text('150000'), findsOneWidget);
    expect(find.byKey(const ValueKey('application-price-confirmed')),
        findsNothing);
  });

  testWidgets('no filtra error interno ni confirma fallo de red',
      (tester) async {
    await show(tester, (_) async => throw StateError('detalle interno'));
    await tester.enterText(
        find.byKey(const ValueKey('application-price')), '150000');
    await send(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('detalle interno'), findsNothing);
    expect(
        find.byKey(const ValueKey('application-price-error')), findsOneWidget);
  });

  testWidgets('requiere solicitud y prerrequisitos completos', (tester) async {
    await show(tester, (_) async {}, request: '');
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('application-price-submit')))
            .onPressed,
        isNull);
  });

  testWidgets('respuesta tardía de otra solicitud no confirma la actual',
      (tester) async {
    final pending = Completer<void>();
    await show(tester, (_) => pending.future);
    await tester.enterText(
        find.byKey(const ValueKey('application-price')), '150000');
    await send(tester);
    await show(tester, (_) async {}, request: 'r2');
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('application-price-confirmed')),
        findsNothing);
    expect(find.text('150000'), findsNothing);
  });

  testWidgets('formulario compacto no desborda', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await show(tester, (_) async {});
    expect(tester.takeException(), isNull);
  });
}
