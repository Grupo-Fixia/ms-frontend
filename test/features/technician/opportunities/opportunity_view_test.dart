import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/domain/service_budget.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/features/technician/opportunities/domain/opportunity.dart';
import 'package:ms_frontend/features/technician/opportunities/presentation/opportunity_view.dart';

void main() {
  test('distingue presupuesto orientativo de importe ausente sin inventarlo',
      () {
    final view = opportunityView(Opportunity(
      id: 'budget-request',
      category: ServiceCategory.plumbing,
      description: 'Reparar fuga',
      city: 'Bogotá',
      zone: 'Chapinero',
      expectedAt: DateTime(2026, 11, 1),
      budget: ServiceBudget.tryParse('150000,25'),
    ));
    expect(view.budget, '150.000,25 COP');
  });

  final now = DateTime(2026, 10, 22, 15);

  Opportunity at(DateTime? publishedAt) => Opportunity(
        id: 'sr-1',
        category: ServiceCategory.electrical,
        description: 'Cambiar un tomacorriente',
        city: 'Bogotá',
        zone: 'Usaquén',
        expectedAt: DateTime(2026, 10, 24, 8, 5),
        publishedAt: publishedAt,
      );

  test('muestra la solicitud del backend en la tarjeta', () {
    final view = opportunityView(at(now), now: now);

    expect(view.id, 'sr-1');
    expect(view.title, 'Cambiar un tomacorriente');
    expect(view.category, ServiceCategory.electrical);
    expect(view.approximateLocation, 'Usaquén, Bogotá');
    expect(view.description, 'Cambiar un tomacorriente');
    expect(view.expectedMoment, '24/10/2026 · 08:05');
    expect(view.budget, 'Presupuesto no informado');
  });

  test('un título largo se acorta y une las líneas', () {
    final long = Opportunity(
      id: 'sr-2',
      category: ServiceCategory.plumbing,
      description: 'Se rompió el tubo\n del lavamanos y gotea sin parar desde '
          'anoche, necesito a alguien que lo cambie hoy mismo',
      city: 'Bogotá',
      zone: 'Suba',
      expectedAt: DateTime(2026, 10, 24),
    );

    final title = opportunityView(long, now: now).title;

    expect(title.length, lessThanOrEqualTo(60));
    expect(title, startsWith('Se rompió el tubo del lavamanos'));
    expect(title, endsWith('…'));
  });

  test('dice hace cuánto se publicó', () {
    String posted(Duration ago) =>
        opportunityView(at(now.subtract(ago)), now: now).postedLabel;

    expect(opportunityView(at(null), now: now).postedLabel, 'Recientemente');
    expect(posted(const Duration(seconds: 20)), 'Hace un momento');
    expect(posted(const Duration(minutes: 12)), 'Hace 12 min');
    expect(posted(const Duration(hours: 1)), 'Hace 1 hora');
    expect(posted(const Duration(hours: 5)), 'Hace 5 horas');
    expect(posted(const Duration(days: 1)), 'Hace 1 día');
    expect(posted(const Duration(days: 3)), 'Hace 3 días');
  });
}
