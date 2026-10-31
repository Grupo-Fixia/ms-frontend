import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/chat_prototype/domain/simulated_replies.dart';
import 'package:ms_frontend/features/chat_prototype/presentation/chat_prototype_page.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(theme: FixiaTheme.light, home: const ChatPrototypePage()),
  );
}

Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(_key('chat-prototype-input'), text);
  await tester.tap(_key('chat-prototype-send'));
  await tester.pump();
}

void main() {
  testWidgets('se identifica como simulación y explica qué pasa al salir',
      (tester) async {
    await _pump(tester);

    expect(_key('chat-prototype-banner'), findsOneWidget);
    expect(find.textContaining('SIMULACIÓN'), findsOneWidget);
    expect(find.textContaining('no se envía a ninguna cuenta'), findsOneWidget);
    expect(find.textContaining('al salir de esta pantalla o recargar'),
        findsOneWidget);
    expect(find.textContaining('No cambia precios'), findsOneWidget);
    expect(_key('chat-prototype-empty'), findsOneWidget);
  });

  testWidgets('escribir y enviar muestra el mensaje y la respuesta simulada',
      (tester) async {
    await _pump(tester);

    await _send(tester, 'Hola, ¿cómo estás?');

    expect(find.text('Hola, ¿cómo estás?'), findsOneWidget);
    expect(find.text(SimulatedReplies.at(0)), findsOneWidget);
    expect(find.text('Tú'), findsOneWidget);
    expect(find.text('Respuesta simulada'), findsOneWidget);
    expect(_key('chat-prototype-empty'), findsNothing);
    // El campo se limpia tras enviar.
    final field = tester.widget<TextField>(_key('chat-prototype-input'));
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('enviar con Enter también funciona', (tester) async {
    await _pump(tester);

    await tester.enterText(_key('chat-prototype-input'), 'por teclado');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    expect(find.text('por teclado'), findsOneWidget);
    expect(find.text(SimulatedReplies.at(0)), findsOneWidget);
  });

  testWidgets('un mensaje vacío no se envía', (tester) async {
    await _pump(tester);

    await _send(tester, '   ');

    expect(_key('chat-prototype-empty'), findsOneWidget);
    expect(find.text('Respuesta simulada'), findsNothing);
  });

  testWidgets('varios envíos avanzan por las respuestas', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester);

    await _send(tester, 'uno');
    await _send(tester, 'dos');

    expect(find.text(SimulatedReplies.at(0)), findsOneWidget);
    expect(find.text(SimulatedReplies.at(1)), findsOneWidget);
  });

  testWidgets('reiniciar deja la conversación vacía', (tester) async {
    await _pump(tester);
    await _send(tester, 'algo');

    await tester.tap(_key('chat-prototype-reset'));
    await tester.pump();

    expect(find.text('algo'), findsNothing);
    expect(_key('chat-prototype-empty'), findsOneWidget);
  });

  testWidgets('salir y volver a entrar empieza de cero (sin persistencia)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const ValueKey('open'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const ChatPrototypePage()),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(_key('open'));
    await tester.pumpAndSettle();
    await _send(tester, 'mensaje temporal');
    expect(find.text('mensaje temporal'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(_key('open'));
    await tester.pumpAndSettle();

    expect(find.text('mensaje temporal'), findsNothing);
    expect(_key('chat-prototype-empty'), findsOneWidget);
  });

  testWidgets('no promete entrega, lectura ni guardado', (tester) async {
    await _pump(tester);
    await _send(tester, 'prueba');

    for (final misleading in ['Entregado', 'Leído', 'Visto', 'Guardado']) {
      expect(find.text(misleading), findsNothing, reason: misleading);
    }
  });

  test('aislamiento: la capa del chat no importa HTTP, sesión ni negocio', () {
    final files = Directory('lib/features/chat_prototype')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    expect(files, isNotEmpty);
    const forbidden = [
      'package:http',
      'authorized_http',
      'api_config',
      'backend_integrations',
      'session_store',
      'features/quotations',
      'features/contracts',
      'features/client/service_request',
      'features/technician/applications',
      'dart:html',
      'package:web',
    ];
    for (final file in files) {
      final imports = file
          .readAsLinesSync()
          .where((l) => l.startsWith('import ') || l.startsWith('export '))
          .join('\n');
      for (final bad in forbidden) {
        expect(imports.contains(bad), isFalse,
            reason: '${file.path} importa $bad');
      }
    }
  });
}
