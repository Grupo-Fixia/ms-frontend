import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/dev_sandbox/presentation/flow_sandbox_page.dart';

Finder _keyStartsWith(String prefix) => find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> && key.value.startsWith(prefix);
    });

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator)).pop();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('recorre postulación, selección, cotización y aceptación',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: const FlowSandboxPage(latency: Duration.zero),
      ),
    );

    // Los pasos posteriores están bloqueados hasta completar los previos.
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('step-applicants')))
          .onPressed,
      isNull,
    );

    // 1. Técnico se postula (GC-344).
    await _tapKey(tester, 'step-apply');
    await _tapKey(tester, 'technician-opportunity-detail-fuga-lavaplatos');
    await _tapKey(tester, 'technician-apply-fuga-lavaplatos');
    await _tapKey(tester, 'apply-confirm-button');
    await _back(tester);

    // 2. Cliente revisa postulantes y selecciona (GC-349/350).
    await _tapKey(tester, 'step-applicants');
    expect(find.text('Carlos Ramírez'), findsOneWidget);
    await tester.tap(_keyStartsWith('applicant-select-').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('select-provider-confirm')));
    await tester.pumpAndSettle();
    await _back(tester);

    // 3. Técnico envía la cotización (GC-355).
    await _tapKey(tester, 'step-quotation');
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
    await _back(tester);

    // 4. Cliente acepta (GC-360).
    await _tapKey(tester, 'step-decision');
    await _tapKey(tester, 'quotation-accept');
    await _tapKey(tester, 'accept-confirm');
    expect(find.text('ACEPTADA'), findsOneWidget);
    await _back(tester);

    expect(find.text('Estado actual: Aceptada.'), findsOneWidget);

    await _tapKey(tester, 'sandbox-reset');
    expect(find.text('Estado actual: Aceptada.'), findsNothing);
  });
}
