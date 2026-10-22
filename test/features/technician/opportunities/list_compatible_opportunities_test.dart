import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/features/technician/opportunities/application/list_compatible_opportunities.dart';
import 'package:ms_frontend/features/technician/opportunities/application/ports/opportunity_repository.dart';
import 'package:ms_frontend/features/technician/opportunities/domain/opportunity.dart';
import 'package:ms_frontend/features/technician/opportunities/domain/opportunity_exceptions.dart';

Opportunity _opportunity(String id) => Opportunity(
      id: id,
      category: ServiceCategory.plumbing,
      description: 'Fuga',
      city: 'Bogotá',
      zone: 'Chapinero',
      expectedAt: DateTime.utc(2026, 10, 25),
    );

/// Repositorio con páginas fijas, en orden.
class _Pages implements OpportunityRepository {
  _Pages(this.pages);

  final List<OpportunityPage> pages;
  final List<({int limit, String? cursor})> calls = [];

  @override
  Future<OpportunityPage> fetchPage(
      {required int limit, String? cursor}) async {
    calls.add((limit: limit, cursor: cursor));
    return pages[calls.length - 1];
  }
}

void main() {
  test('devuelve la primera página tal cual', () async {
    final repository = _Pages([
      OpportunityPage(items: [_opportunity('a')], nextCursor: 'c1'),
    ]);

    final page = await ListCompatibleOpportunities(repository)();

    expect(page.items.map((o) => o.id), ['a']);
    expect(page.nextCursor, 'c1');
    expect(page.hasMore, isTrue);
    expect(repository.calls.single, (limit: 20, cursor: null));
  });

  test('pide la siguiente página con el cursor recibido', () async {
    final repository = _Pages([
      const OpportunityPage(items: [], nextCursor: null),
    ]);

    final page =
        await ListCompatibleOpportunities(repository)(cursor: 'c1', limit: 5);

    expect(repository.calls.single, (limit: 5, cursor: 'c1'));
    expect(page.items, isEmpty);
    expect(page.hasMore, isFalse);
  });

  test('si una página llega vacía pero hay más, sigue hasta encontrar alguna',
      () async {
    final repository = _Pages([
      const OpportunityPage(items: [], nextCursor: 'c1'),
      const OpportunityPage(items: [], nextCursor: 'c2'),
      OpportunityPage(items: [_opportunity('b')], nextCursor: 'c3'),
    ]);

    final page = await ListCompatibleOpportunities(repository)();

    expect(page.items.map((o) => o.id), ['b']);
    expect(page.nextCursor, 'c3');
    expect(repository.calls.map((c) => c.cursor), [null, 'c1', 'c2']);
  });

  test('no pide más de maxPagesPerCall páginas vacías seguidas', () async {
    final repository = _Pages(List.generate(
      10,
      (i) => OpportunityPage(items: const [], nextCursor: 'c$i'),
    ));

    final page = await ListCompatibleOpportunities(
      repository,
      maxPagesPerCall: 3,
    )();

    expect(repository.calls, hasLength(3));
    expect(page.items, isEmpty);
    expect(page.nextCursor, 'c2', reason: 'se puede seguir después');
  });

  test('ajusta el límite al rango que acepta el backend', () async {
    for (final (asked, sent) in [(0, 1), (-3, 1), (80, 50), (50, 50)]) {
      final repository =
          _Pages([const OpportunityPage(items: [], nextCursor: null)]);

      await ListCompatibleOpportunities(repository)(limit: asked);

      expect(repository.calls.single.limit, sent, reason: '$asked');
    }
  });

  test('la lista devuelta no se puede modificar', () async {
    final repository = _Pages([
      OpportunityPage(items: [_opportunity('a')], nextCursor: null),
    ]);

    final page = await ListCompatibleOpportunities(repository)();

    expect(() => page.items.add(_opportunity('x')), throwsUnsupportedError);
  });

  test('la falla se muestra con su mensaje', () {
    expect(const OpportunityFailure('Mensaje').toString(), 'Mensaje');
  });
}
