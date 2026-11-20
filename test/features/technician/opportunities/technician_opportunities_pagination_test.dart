import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/technician/opportunities/domain/service_opportunity.dart';
import 'package:ms_frontend/features/technician/opportunities/presentation/match_setup_summary.dart';
import 'package:ms_frontend/features/technician/opportunities/presentation/technician_opportunities_page.dart';

/// GC-532: la pantalla sigue pidiendo páginas mientras el backend devuelva
/// cursor, y solo dice "no hay solicitudes" cuando ya no queda nada.

const _moreKey = ValueKey('technician-opportunities-more');
const _moreErrorKey = ValueKey('technician-opportunities-more-error');
const _moreRetryKey = ValueKey('technician-opportunities-more-retry');
const _emptyText = 'Por ahora no hay solicitudes compatibles contigo.';

ServiceOpportunity _opportunity(String id,
        {ServiceCategory category = ServiceCategory.plumbing}) =>
    ServiceOpportunity(
      id: id,
      title: 'Solicitud $id',
      category: category,
      postedLabel: 'Hace 1 hora',
      budget: r'$100.000',
      approximateLocation: 'Centro, Cali',
      description: 'Descripción $id',
      expectedMoment: 'Mañana 10:00',
    );

ServiceOpportunityPage _page(List<String> ids, {String? next}) =>
    ServiceOpportunityPage(
      items: [for (final id in ids) _opportunity(id)],
      nextCursor: next,
    );

/// Devuelve las páginas en orden y registra con qué cursor se pidió cada una.
class _Loader {
  _Loader(this.responses);

  final List<Object> responses; // ServiceOpportunityPage o Exception
  final List<String?> cursors = [];

  Future<ServiceOpportunityPage> call(String? cursor) async {
    cursors.add(cursor);
    final response = responses[cursors.length - 1];
    if (response is Exception) throw response;
    return response as ServiceOpportunityPage;
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Loader loader, {
  Future<MatchSetup> Function()? loadMatchSetup,
}) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: FixiaTheme.light,
      home: TechnicianOpportunitiesPage(
        loadOpportunitiesPage: loader.call,
        loadMatchSetup: loadMatchSetup,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _card(String id) => find.byKey(ValueKey('technician-opportunity-$id'));

void main() {
  testWidgets('con cursor ofrece ver más y agrega la página siguiente',
      (tester) async {
    final loader = _Loader([
      _page(['a', 'b'], next: 'c1'),
      _page(['c']),
    ]);
    await _pump(tester, loader);

    expect(_card('a'), findsOneWidget);
    expect(_card('b'), findsOneWidget);
    expect(_card('c'), findsNothing);
    expect(find.text('2+ solicitudes'), findsOneWidget);
    expect(find.byKey(_moreKey), findsOneWidget);

    await _tap(tester, _moreKey);

    expect(_card('a'), findsOneWidget);
    expect(_card('c'), findsOneWidget);
    expect(find.text('3 solicitudes'), findsOneWidget);
    expect(find.byKey(_moreKey), findsNothing, reason: 'ya no queda nada');
    expect(loader.cursors, [null, 'c1']);
  });

  testWidgets('sin cursor no hay botón de ver más', (tester) async {
    await _pump(
        tester,
        _Loader([
          _page(['a'])
        ]));

    expect(find.byKey(_moreKey), findsNothing);
    expect(find.text('1 solicitudes'), findsOneWidget);
  });

  testWidgets('una página vacía con cursor no se presenta como "no hay nada"',
      (tester) async {
    final loader = _Loader([
      _page([], next: 'c1'),
      _page(['a']),
    ]);
    await _pump(tester, loader, loadMatchSetup: () async => const MatchSetup());

    expect(find.text(_emptyText), findsNothing);
    expect(find.byType(MatchSetupSummary), findsNothing);
    expect(find.textContaining('Sigue buscando'), findsOneWidget);
    expect(find.byKey(_moreKey), findsOneWidget);

    await _tap(tester, _moreKey);

    expect(_card('a'), findsOneWidget);
    expect(find.byKey(_moreKey), findsNothing);
  });

  testWidgets('sin items y sin cursor es el vacío de verdad', (tester) async {
    await _pump(tester, _Loader([_page([])]));

    expect(find.text(_emptyText), findsOneWidget);
    expect(find.byKey(_moreKey), findsNothing);
    expect(find.text('0 solicitudes'), findsOneWidget);
  });

  testWidgets('sin items y sin cursor muestra la configuración del técnico',
      (tester) async {
    await _pump(tester, _Loader([_page([])]),
        loadMatchSetup: () async => const MatchSetup(zoneLoaded: true));

    expect(find.byType(MatchSetupSummary), findsOneWidget);
    expect(find.byKey(_moreKey), findsNothing);
  });

  testWidgets('el filtro de categoría no oculta que quedan páginas',
      (tester) async {
    final loader = _Loader([
      _page(['a'], next: 'c1'),
      _page(['b']),
    ]);
    await _pump(tester, loader);

    await tester.tap(find.text(ServiceCategory.electrical.label));
    await tester.pumpAndSettle();

    expect(find.textContaining('entre las cargadas'), findsOneWidget);
    expect(find.byKey(_moreKey), findsOneWidget);
  });

  testWidgets('si falla al cargar más conserva lo cargado y reintenta',
      (tester) async {
    final loader = _Loader([
      _page(['a'], next: 'c1'),
      Exception('sin red'),
      _page(['b']),
    ]);
    await _pump(tester, loader);

    await _tap(tester, _moreKey);

    expect(_card('a'), findsOneWidget, reason: 'lo ya cargado se conserva');
    expect(find.byKey(_moreErrorKey), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    await _tap(tester, _moreRetryKey);

    expect(_card('b'), findsOneWidget);
    expect(find.byKey(_moreErrorKey), findsNothing);
    expect(find.byKey(_moreKey), findsNothing);
    expect(loader.cursors, [null, 'c1', 'c1']);
  });

  testWidgets('un cursor repetido corta y pide actualizar la lista',
      (tester) async {
    final loader = _Loader([
      _page(['a'], next: 'c1'),
      _page(['b'], next: 'c1'),
      _page(['x']),
    ]);
    await _pump(tester, loader);

    await _tap(tester, _moreKey);

    expect(find.text(TechnicianOpportunitiesPage.listChangedMessage),
        findsOneWidget);
    expect(_card('b'), findsNothing, reason: 'no se agrega la página dudosa');
    expect(loader.cursors, [null, 'c1']);

    await _tap(tester, _moreRetryKey);

    expect(find.text('Actualizar'), findsNothing);
    expect(_card('x'), findsOneWidget);
    expect(_card('a'), findsNothing, reason: 'se recargó desde el principio');
    expect(loader.cursors, [null, 'c1', null]);
  });

  testWidgets('solicitudes repetidas en la página siguiente cortan la carga',
      (tester) async {
    final loader = _Loader([
      _page(['a'], next: 'c1'),
      _page(['a', 'b']),
    ]);
    await _pump(tester, loader);

    await _tap(tester, _moreKey);

    expect(find.byKey(_moreErrorKey), findsOneWidget);
    expect(_card('b'), findsNothing);
    expect(_card('a'), findsOneWidget);
  });

  testWidgets('si falla la primera carga se reintenta desde el principio',
      (tester) async {
    final loader = _Loader([
      Exception('sin red'),
      _page(['a'], next: 'c1'),
    ]);
    await _pump(tester, loader);

    expect(find.byKey(const ValueKey('technician-opportunities-error')),
        findsOneWidget);
    expect(find.byKey(_moreKey), findsNothing);

    await _tap(tester, const ValueKey('technician-opportunities-retry'));

    expect(_card('a'), findsOneWidget);
    expect(find.byKey(_moreKey), findsOneWidget);
    expect(loader.cursors, [null, null]);
  });
}
