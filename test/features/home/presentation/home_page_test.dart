import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/home/presentation/home_page.dart';

const _wide = Size(1280, 900);
const _phone = Size(375, 812);

Future<void> _pumpHome(
  WidgetTester tester, {
  Size size = _wide,
  VoidCallback? onRegisterClient,
  VoidCallback? onLogin,
  VoidCallback? onRegisterTechnician,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: FixiaTheme.light,
      home: HomePage(
        onRegisterClient: onRegisterClient ?? () {},
        onLogin: onLogin ?? () {},
        onRegisterTechnician: onRegisterTechnician,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Lleva el widget a la vista antes de tocarlo (la página tiene scroll).
Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

bool _isOnScreen(WidgetTester tester, String key, Size screen) {
  final rect = tester.getRect(find.byKey(ValueKey(key)));
  return rect.top >= 0 && rect.top < screen.height;
}

void main() {
  testWidgets('presenta Fixia con sus secciones', (tester) async {
    await _pumpHome(tester);

    expect(find.byKey(const ValueKey('home-title')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-why-fixia')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-services')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-how-it-works')), findsOneWidget);
    expect(find.text('Necesito un técnico'), findsOneWidget);
    expect(find.text('Soy técnico'), findsOneWidget);
  });

  testWidgets('arriba a la derecha están "Iniciar sesión" y "Registrarse"',
      (tester) async {
    await _pumpHome(tester);

    expect(find.byKey(const ValueKey('home-login')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-register')), findsOneWidget);
    expect(find.text('¿Ya tienes cuenta?'), findsNothing);
    expect(
      tester.getCenter(find.byKey(const ValueKey('home-register'))).dx,
      greaterThan(_wide.width / 2),
    );
  });

  testWidgets('"Iniciar sesión" lleva al login', (tester) async {
    var calls = 0;
    await _pumpHome(tester, onLogin: () => calls++);

    await _tapKey(tester, 'home-login');

    expect(calls, 1);
  });

  testWidgets('"Registrarse" baja hasta la elección de perfil',
      (tester) async {
    await _pumpHome(tester, size: _phone);
    expect(_isOnScreen(tester, 'home-role-client', _phone), isFalse);

    await tester.tap(find.byKey(const ValueKey('home-register')));
    await tester.pumpAndSettle();

    expect(_isOnScreen(tester, 'home-role-client', _phone), isTrue);
  });

  testWidgets('"Encontrar un técnico" y la tarjeta de cliente llevan al '
      'registro de cliente', (tester) async {
    var calls = 0;
    await _pumpHome(tester, onRegisterClient: () => calls++);

    await _tapKey(tester, 'home-hero-cta');
    await _tapKey(tester, 'home-register-client');

    expect(calls, 2);
  });

  testWidgets('sin registro de técnico la opción aparece como "Próximamente"',
      (tester) async {
    await _pumpHome(tester);

    final button = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('home-register-technician')),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Próximamente'), findsOneWidget);
  });

  testWidgets('con registro de técnico la opción queda habilitada',
      (tester) async {
    var calls = 0;
    await _pumpHome(tester, onRegisterTechnician: () => calls++);

    await _tapKey(tester, 'home-register-technician');

    expect(calls, 1);
    expect(find.text('Próximamente'), findsNothing);
  });

  for (final size in const [Size(320, 640), _phone]) {
    testWidgets('en celular de ${size.width.toInt()} px no hay desbordes y '
        'las tarjetas van en una columna', (tester) async {
      await _pumpHome(tester, size: size);

      expect(tester.takeException(), isNull);
      final client =
          tester.getTopLeft(find.byKey(const ValueKey('home-role-client')));
      final technician = tester
          .getTopLeft(find.byKey(const ValueKey('home-role-technician')));
      expect(technician.dy, greaterThan(client.dy));
      expect(technician.dx, client.dx);
    });
  }

  testWidgets('en pantalla ancha las tarjetas van lado a lado', (tester) async {
    await _pumpHome(tester);

    expect(tester.takeException(), isNull);
    final client =
        tester.getTopLeft(find.byKey(const ValueKey('home-role-client')));
    final technician =
        tester.getTopLeft(find.byKey(const ValueKey('home-role-technician')));
    expect(technician.dy, client.dy);
    expect(technician.dx, greaterThan(client.dx));
  });

  testWidgets('muestra las 6 categorías de servicio del backend',
      (tester) async {
    await _pumpHome(tester);

    for (final category in ServiceCategory.values) {
      expect(
        find.byKey(ValueKey('home-service-${category.apiValue}')),
        findsOneWidget,
        reason: category.apiValue,
      );
      expect(find.text(category.label), findsOneWidget);
    }
  });
}
