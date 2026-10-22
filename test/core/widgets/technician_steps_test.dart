import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/core/widgets/technician_steps.dart';

Future<void> _pump(WidgetTester tester, int currentStep) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: FixiaTheme.light,
      home: Scaffold(body: TechnicianSteps(currentStep: currentStep)),
    ),
  );
}

void main() {
  testWidgets('muestra los 3 pasos', (tester) async {
    await _pump(tester, 1);

    for (final label in TechnicianSteps.labels) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('en el paso 1 ningún paso está completado', (tester) async {
    await _pump(tester, 1);

    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(find.text('1'), findsOneWidget);
    expect(find.bySemanticsLabel('Paso 1: Crea tu cuenta (actual)'),
        findsOneWidget);
  });

  testWidgets('los pasos anteriores al actual aparecen completados',
      (tester) async {
    await _pump(tester, 3);

    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    expect(find.text('3'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Paso 2: Completa tu perfil profesional '
          '(completado)'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Paso 3: Verificación de Fixia (actual)'),
      findsOneWidget,
    );
  });
}
