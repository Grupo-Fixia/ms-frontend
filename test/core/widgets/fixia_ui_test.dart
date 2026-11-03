import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/core/widgets/fixia_ui.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child, double width) async {
    tester.view.physicalSize = Size(width, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: FixiaTheme.light,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ));
  }

  testWidgets('PageHeader pone las acciones a la derecha o debajo',
      (tester) async {
    const header = PageHeader(
      title: 'Hola',
      titleKey: ValueKey('t'),
      subtitle: 'Sub',
      actions: [Text('acción', key: ValueKey('a'))],
    );
    await pump(tester, header, 1000);
    var title = tester.getRect(find.byKey(const ValueKey('t')));
    var action = tester.getRect(find.byKey(const ValueKey('a')));
    expect(action.left, greaterThan(title.right));

    await pump(tester, header, 400);
    title = tester.getRect(find.byKey(const ValueKey('t')));
    action = tester.getRect(find.byKey(const ValueKey('a')));
    expect(action.top, greaterThan(title.bottom));
    expect(find.text('Sub'), findsOneWidget);
  });

  testWidgets('StatGrid se compacta en celular', (tester) async {
    const grid = StatGrid(children: [
      StatCard(label: 'Abiertas', value: '2', caption: 'Con postulantes'),
      StatCard(label: 'En curso', value: '1', emphasis: true),
      StatCard(label: 'Cerradas', value: '–'),
    ]);
    await pump(tester, grid, 1000);
    expect(find.text('Con postulantes'), findsOneWidget);

    await pump(tester, grid, 360);
    expect(find.text('Con postulantes'), findsNothing);
    final a = tester.getRect(find.text('2'));
    final c = tester.getRect(find.text('–'));
    expect(a.center.dy, closeTo(c.center.dy, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ResponsiveGrid y TwoColumns se apilan en angosto',
      (tester) async {
    final widget = TwoColumns(
      main: ResponsiveGrid(
        minItemWidth: 200,
        children: [
          for (var i = 0; i < 3; i++) Text('item $i', key: ValueKey('i$i')),
        ],
      ),
      side: const Text('lateral', key: ValueKey('side')),
    );
    await pump(tester, widget, 1200);
    expect(
      tester.getRect(find.byKey(const ValueKey('side'))).left,
      greaterThan(tester.getRect(find.byKey(const ValueKey('i2'))).left),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('i0'))).top,
      tester.getRect(find.byKey(const ValueKey('i1'))).top,
    );

    await pump(tester, widget, 380);
    expect(
      tester.getRect(find.byKey(const ValueKey('side'))).top,
      greaterThan(tester.getRect(find.byKey(const ValueKey('i2'))).bottom),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('i1'))).top,
      greaterThan(tester.getRect(find.byKey(const ValueKey('i0'))).top),
    );
  });

  testWidgets('piezas de estado se dibujan en todos los tonos', (tester) async {
    var tapped = 0;
    await pump(
      tester,
      Column(children: [
        for (final tone in PillTone.values) ...[
          StatusPill(label: 'pill ${tone.name}', tone: tone),
          NoticeBanner(
            message: 'aviso ${tone.name}',
            tone: tone,
            icon: Icons.info_outline,
          ),
        ],
        SectionTitle(
          title: 'Sección',
          action: TextButton(onPressed: () {}, child: const Text('Ver')),
        ),
        EmptyState(
          message: 'Vacío',
          action: TextButton(
            onPressed: () => tapped++,
            child: const Text('Reintentar'),
          ),
        ),
        const FixiaPanel(highlight: Colors.blue, child: Text('panel')),
        const SectionLoading(),
      ]),
      800,
    );
    expect(find.text('pill warning'), findsOneWidget);
    expect(find.text('aviso neutral'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    expect(tapped, 1);
  });

  testWidgets('FilterPills marca el filtro y avisa el elegido', (tester) async {
    String? chosen;
    await pump(
      tester,
      FilterPills<String>(
        keyPrefix: 'f',
        options: const [('a', 'Todas'), ('b', 'Abiertas')],
        selected: 'a',
        onSelected: (v) => chosen = v,
      ),
      600,
    );
    final all =
        tester.widget<ChoiceChip>(find.byKey(const ValueKey('f-Todas')));
    expect(all.selected, isTrue);
    await tester.tap(find.byKey(const ValueKey('f-Abiertas')));
    expect(chosen, 'b');
  });

  testWidgets('ActionBar alinea a la derecha o apila en celular',
      (tester) async {
    const bar = ActionBar(actions: [
      Text('uno', key: ValueKey('a1')),
      Text('dos', key: ValueKey('a2')),
    ]);
    await pump(tester, bar, 900);
    var a1 = tester.getRect(find.byKey(const ValueKey('a1')));
    var a2 = tester.getRect(find.byKey(const ValueKey('a2')));
    expect(a1.top, a2.top);
    expect(a2.right, greaterThan(800));

    await pump(tester, bar, 360);
    a1 = tester.getRect(find.byKey(const ValueKey('a1')));
    a2 = tester.getRect(find.byKey(const ValueKey('a2')));
    expect(a2.top, greaterThan(a1.bottom));
  });

  testWidgets('BackLink vuelve atrás o usa su callback', (tester) async {
    var taps = 0;
    await pump(
      tester,
      Column(children: [
        BackLink(onPressed: () => taps++),
        const InfoRow(label: 'Ciudad', value: 'Bogotá'),
      ]),
      600,
    );
    expect(find.text('Bogotá'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('page-back')));
    expect(taps, 1);

    await tester.pumpWidget(MaterialApp(
      theme: FixiaTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: BackLink()))),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('page-back')));
    await tester.pumpAndSettle();
    expect(find.text('abrir'), findsOneWidget);
  });
}
