import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/core/widgets/fixia_date_time_picker.dart';

Finder _key(String k) => find.byKey(ValueKey(k));

void main() {
  final first = DateTime(2030, 3, 10, 15, 10);
  final last = DateTime(2030, 5, 20);

  Future<Future<DateTime?>> open(WidgetTester tester,
      {DateTime? initial, bool pickTime = true, Size? size}) async {
    tester.view.physicalSize = size ?? const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late Future<DateTime?> result;
    await tester.pumpWidget(MaterialApp(
      theme: FixiaTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => result = showFixiaDateTimePicker(
              context,
              first: first,
              last: last,
              initial: initial,
              pickTime: pickTime,
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('elige día y hora; lo anterior al mínimo no se puede elegir',
      (tester) async {
    final result = await open(tester);

    expect(find.text('Marzo 2030'), findsOneWidget);
    expect(find.text('Elige el día y la hora'), findsOneWidget);
    // Sin día elegido no se puede confirmar.
    expect(tester.widget<FilledButton>(_key('fixia-picker-confirm')).onPressed,
        isNull);
    // Días anteriores deshabilitados.
    await tester.tap(_key('fixia-picker-day-2030-03-09'));
    await tester.pump();
    expect(find.text('Elige el día y la hora'), findsOneWidget);
    // El mismo día del mínimo: solo horas posteriores a las 3:10 p. m.
    await tester.tap(_key('fixia-picker-day-2030-03-10'));
    await tester.pump();
    await tester.tap(_key('fixia-picker-slot-15:00'));
    await tester.pump();
    expect(find.textContaining('elige la hora'), findsOneWidget);
    await tester.tap(_key('fixia-picker-slot-15:30'));
    await tester.pump();
    expect(find.text('Domingo 10 de marzo · 3:30 p. m.'), findsOneWidget);

    await tester.tap(_key('fixia-picker-confirm'));
    await tester.pumpAndSettle();
    expect(await result, DateTime(2030, 3, 10, 15, 30));
  });

  testWidgets('navega por los meses dentro del rango y conserva la hora',
      (tester) async {
    final result = await open(tester, initial: DateTime(2030, 3, 12, 9));

    expect(find.text('Martes 12 de marzo · 9:00 a. m.'), findsOneWidget);
    // No se puede ir antes del primer mes.
    expect(
        tester
            .widget<InkWell>(find.descendant(
                of: _key('fixia-picker-prev'), matching: find.byType(InkWell)))
            .onTap,
        isNull);
    await tester.tap(_key('fixia-picker-next'));
    await tester.tap(_key('fixia-picker-next'));
    await tester.pump();
    expect(find.text('Mayo 2030'), findsOneWidget);
    // Después del último día no se puede elegir.
    await tester.tap(_key('fixia-picker-day-2030-05-25'));
    await tester.pump();
    expect(find.text('Martes 12 de marzo · 9:00 a. m.'), findsOneWidget);
    await tester.tap(_key('fixia-picker-day-2030-05-20'));
    await tester.pump();
    await tester.tap(_key('fixia-picker-prev'));
    await tester.pump();
    expect(find.text('Abril 2030'), findsOneWidget);

    await tester.tap(_key('fixia-picker-confirm'));
    await tester.pumpAndSettle();
    expect(await result, DateTime(2030, 5, 20, 9));
  });

  testWidgets('solo fecha y cancelar devuelve null', (tester) async {
    var result = await open(tester, pickTime: false);
    expect(find.text('Hora'), findsNothing);
    await tester.tap(_key('fixia-picker-next'));
    await tester.pump();
    await tester.tap(_key('fixia-picker-day-2030-04-01'));
    await tester.pump();
    expect(find.text('Lunes 1 de abril'), findsOneWidget);
    await tester.tap(_key('fixia-picker-confirm'));
    await tester.pumpAndSettle();
    expect(await result, DateTime(2030, 4, 1));

    result = await open(tester);
    await tester.tap(_key('fixia-picker-cancel'));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  testWidgets('en celular se abre como hoja inferior sin desbordar',
      (tester) async {
    final result = await open(tester, size: const Size(360, 740));
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(_key('fixia-picker-day-2030-03-11'));
    await tester.pump();
    final slot = _key('fixia-picker-slot-20:00');
    await tester.ensureVisible(slot);
    await tester.tap(slot);
    await tester.pump();
    await tester.tap(_key('fixia-picker-confirm'));
    await tester.pumpAndSettle();
    expect(await result, DateTime(2030, 3, 11, 20));
    expect(tester.takeException(), isNull);
  });

  test('textos de fecha y hora en español', () {
    expect(fixiaLongDate(DateTime(2030, 1, 1)), 'martes 1 de enero');
    expect(fixiaTime(0, 0), '12:00 a. m.');
    expect(fixiaTime(12, 30), '12:30 p. m.');
  });
}
