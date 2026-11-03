import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/layout/app_shell.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';

void main() {
  Future<void> pumpShell(
    WidgetTester tester, {
    required Size size,
    ShellDestination destination = ShellDestination.clientHome,
    ValueChanged<ShellDestination>? onNavigate,
    VoidCallback? onLogout,
    VoidCallback? onPrimaryAction,
    bool viaScope = false,
    String? userName = 'Ana María García',
    String? mobileTitle,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final shell = AppShell(
      destination: destination,
      userName: viaScope ? null : userName,
      onNavigate: viaScope ? null : onNavigate,
      onLogout: viaScope ? null : onLogout,
      onPrimaryAction: viaScope ? null : onPrimaryAction,
      mobileTitle: mobileTitle,
      child: const Text('contenido', key: ValueKey('content')),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: viaScope
            ? FixiaShellScope(
                userName: userName,
                onNavigate: onNavigate,
                onLogout: onLogout,
                onPrimaryAction: onPrimaryAction,
                child: shell,
              )
            : shell,
      ),
    );
  }

  test('cada rol tiene su menú', () {
    expect(ShellDestination.of(ShellRole.client), [
      ShellDestination.clientHome,
      ShellDestination.clientRequests,
      ShellDestination.clientServices,
      ShellDestination.clientProfile,
    ]);
    expect(ShellDestination.of(ShellRole.technician), hasLength(5));
    expect(ShellDestination.of(ShellRole.company), hasLength(3));
  });

  test('initialsOf no inventa nombres', () {
    expect(initialsOf('Ana María García'), 'AM');
    expect(initialsOf('  luis  '), 'L');
    expect(initialsOf(''), '·');
  });

  testWidgets('escritorio: barra lateral con nombres y navegación',
      (tester) async {
    final visited = <ShellDestination>[];
    var logout = 0;
    await pumpShell(
      tester,
      size: const Size(1440, 900),
      onNavigate: visited.add,
      onLogout: () => logout++,
    );

    expect(find.text('Mis solicitudes'), findsOneWidget);
    expect(find.text('Ana María García'), findsOneWidget);
    expect(find.text('AM'), findsOneWidget);
    final item =
        tester.getRect(find.byKey(const ValueKey('client-nav-historial')));
    expect(item.right, lessThanOrEqualTo(248));
    expect(item.width, greaterThan(150));
    final content = tester.getRect(find.byKey(const ValueKey('content')));
    expect(content.left, greaterThanOrEqualTo(248));

    await tester.tap(find.byKey(const ValueKey('client-nav-historial')));
    await tester.tap(find.byKey(const ValueKey('client-nav-inicio')));
    await tester.tap(find.byKey(const ValueKey('client-dashboard-logout')));
    expect(visited, [ShellDestination.clientRequests]);
    expect(logout, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet: riel de íconos', (tester) async {
    final visited = <ShellDestination>[];
    await pumpShell(
      tester,
      size: const Size(834, 1112),
      destination: ShellDestination.technicianHome,
      onNavigate: visited.add,
      onLogout: () {},
    );

    final item =
        tester.getRect(find.byKey(const ValueKey('technician-nav-trabajos')));
    expect(item.right, lessThanOrEqualTo(84));
    final content = tester.getRect(find.byKey(const ValueKey('content')));
    expect(content.left, greaterThanOrEqualTo(84));
    await tester.tap(find.byKey(const ValueKey('technician-nav-trabajos')));
    expect(visited, [ShellDestination.technicianJobs]);
    expect(find.byKey(const ValueKey('technician-dashboard-logout')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('celular: barra inferior con Publicar en el centro',
      (tester) async {
    final visited = <ShellDestination>[];
    var publish = 0;
    await pumpShell(
      tester,
      size: const Size(390, 844),
      onNavigate: visited.add,
      onPrimaryAction: () => publish++,
      onLogout: () {},
    );

    final bottom = tester.getRect(
      find.byKey(const ValueKey('client-nav-perfil')),
    );
    expect(bottom.bottom, greaterThan(760));
    await tester.tap(find.byKey(const ValueKey('client-publish-problem')));
    await tester.tap(find.byKey(const ValueKey('client-nav-perfil')));
    expect(publish, 1);
    expect(visited, [ShellDestination.clientProfile]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('celular: muestra el título de la pantalla si lo hay',
      (tester) async {
    await pumpShell(
      tester,
      size: const Size(390, 844),
      destination: ShellDestination.companyTechnicians,
      mobileTitle: 'Técnicos',
    );
    expect(find.text('Técnicos'), findsWidgets);
    expect(find.byKey(const ValueKey('company-logout')), findsNothing);
  });

  testWidgets('toma la sesión y la navegación del FixiaShellScope',
      (tester) async {
    final visited = <ShellDestination>[];
    var logout = 0;
    await pumpShell(
      tester,
      size: const Size(1440, 900),
      destination: ShellDestination.companyHome,
      viaScope: true,
      userName: 'Grupo Norte',
      onNavigate: visited.add,
      onLogout: () => logout++,
    );

    expect(find.text('Grupo Norte'), findsOneWidget);
    expect(find.text('Empresa'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('company-nav-tecnicos')));
    await tester.tap(find.byKey(const ValueKey('company-logout')));
    expect(visited, [ShellDestination.companyTechnicians]);
    expect(logout, 1);
  });

  for (final size in const [Size(320, 640), Size(700, 900), Size(1024, 768)]) {
    testWidgets('no desborda en ${size.width.toInt()} px', (tester) async {
      for (final d in [
        ShellDestination.clientHome,
        ShellDestination.technicianHome,
        ShellDestination.companyHome,
      ]) {
        await pumpShell(
          tester,
          size: size,
          destination: d,
          onLogout: () {},
          onPrimaryAction: () {},
        );
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('en una pantalla secundaria la sección marcada también navega',
      (tester) async {
    final visited = <ShellDestination>[];
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: AppShell(
        destination: ShellDestination.clientRequests,
        subpage: true,
        onNavigate: visited.add,
        child: const Text('detalle'),
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('client-nav-historial')));
    expect(visited, [ShellDestination.clientRequests]);
  });

  testWidgets('sin desplazamiento el contenido ocupa el alto disponible',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: AppShell(
        destination: ShellDestination.technicianHome,
        scrollable: false,
        child: SizedBox.expand(key: ValueKey('fill')),
      ),
    ));
    expect(tester.getRect(find.byKey(const ValueKey('fill'))).height,
        greaterThan(780));
  });
}
