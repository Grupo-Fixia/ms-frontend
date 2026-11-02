import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/company/applications/presentation/company_technician_selector.dart';

const own =
    CompanyTechnicianOption(id: 't1', name: 'Técnico propio', eligible: true);
const other =
    CompanyTechnicianOption(id: 't2', name: 'No elegible', eligible: false);
const unknown =
    CompanyTechnicianOption(id: 't3', name: 'Sin verificar', eligible: null);

void main() {
  testWidgets('lista vacía también impide validar el formulario padre',
      (tester) async {
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Form(
      key: form,
      child: CompanyTechnicianSelector(
        technicians: const [],
        loading: false,
        onChanged: (_) {},
        onRetry: () {},
      ),
    ))));
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Selecciona un técnico asociado.'), findsOneWidget);
  });

  Future<void> show(
    WidgetTester tester, {
    List<CompanyTechnicianOption> items = const [own, other, unknown],
    bool loading = false,
    String? error,
    bool enabled = true,
    ValueChanged<String?>? changed,
    VoidCallback? retry,
    GlobalKey<FormState>? form,
  }) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Form(
      key: form,
      child: CompanyTechnicianSelector(
        technicians: items,
        loading: loading,
        error: error,
        enabled: enabled,
        onChanged: changed ?? (_) {},
        onRetry: retry ?? () {},
      ),
    ))));
    await tester.pumpAndSettle();
  }

  testWidgets('solo ofrece elegibles confirmados y comunica un único id',
      (tester) async {
    String? selected;
    await show(tester, changed: (id) => selected = id);
    await tester.tap(find.byKey(const ValueKey('company-technician-selector')));
    await tester.pumpAndSettle();
    expect(find.text('No elegible'), findsNothing);
    expect(find.text('Sin verificar'), findsOneWidget);
    await tester.tap(find.text('Técnico propio').last);
    await tester.pumpAndSettle();
    expect(selected, 't1');
  });

  testWidgets('exige elección explícita y no selecciona por defecto',
      (tester) async {
    final form = GlobalKey<FormState>();
    await show(tester, form: form);
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Selecciona un técnico asociado.'), findsOneWidget);
  });

  testWidgets('recarga descarta técnico anterior si deja de ser elegible',
      (tester) async {
    String? selected;
    void changed(String? id) => selected = id;
    await show(tester, changed: changed);
    await tester.tap(find.byKey(const ValueKey('company-technician-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Técnico propio').last);
    await tester.pumpAndSettle();
    expect(selected, 't1');
    await show(tester, items: const [other], changed: changed);
    expect(selected, isNull);
    expect(
        find.text('No hay técnicos asociados elegibles para esta solicitud.'),
        findsOneWidget);
  });

  testWidgets('distingue lista vacía de elegibilidad desconocida',
      (tester) async {
    await show(tester, items: []);
    expect(find.text('Tu empresa todavía no tiene técnicos asociados.'),
        findsOneWidget);
    await show(tester, items: const [unknown]);
    expect(find.byKey(const ValueKey('company-technician-selector')),
        findsOneWidget);
  });

  testWidgets('error muestra reintento sin mostrar selección anterior',
      (tester) async {
    var retries = 0;
    await show(tester, error: 'Sesión expirada', retry: () => retries++);
    expect(find.byKey(const ValueKey('company-technician-selector')),
        findsNothing);
    await tester.tap(find.byKey(const ValueKey('company-technicians-retry')));
    expect(retries, 1);
  });

  testWidgets('datos ambiguos se rechazan sin fallo de Dropdown',
      (tester) async {
    await show(tester, items: const [own, own]);
    expect(find.text('No pudimos verificar el listado de técnicos.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('durante envío no permite cambiar técnico', (tester) async {
    await show(tester, enabled: false);
    expect(
        tester
            .widget<DropdownButtonFormField<String>>(
                find.byKey(const ValueKey('company-technician-selector')))
            .onChanged,
        isNull);
  });

  testWidgets('ancho pequeño y nombre largo no desbordan', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await show(tester, items: const [
      CompanyTechnicianOption(
          id: '1',
          name:
              'Nombre y apellidos muy extensos del técnico asociado a la empresa',
          eligible: true)
    ]);
    expect(tester.takeException(), isNull);
  });
}
