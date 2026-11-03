import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/technician/availability/domain/clock_time.dart';
import 'package:ms_frontend/features/technician/availability/domain/weekday.dart';
import 'package:ms_frontend/features/technician/availability/domain/weekly_availability.dart';
import 'package:ms_frontend/features/technician/dashboard/presentation/technician_dashboard_page.dart';
import 'package:ms_frontend/features/technician/opportunities/presentation/match_setup_summary.dart';
import 'package:ms_frontend/features/technician/opportunities/presentation/technician_opportunities_page.dart';

AvailabilitySlot _slot(Weekday day, int from, int to) => AvailabilitySlot(
    day: day, start: ClockTime(from, 0), end: ClockTime(to, 0));

Future<void> _pump(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(1280, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: FixiaTheme.light, home: page));
  await tester.pumpAndSettle();
}

void main() {
  test('describeWeeklySlots junta días seguidos con las mismas franjas', () {
    expect(
      describeWeeklySlots([
        for (final d in [
          Weekday.monday,
          Weekday.tuesday,
          Weekday.wednesday,
          Weekday.thursday,
          Weekday.friday,
        ])
          _slot(d, 8, 17),
        _slot(Weekday.saturday, 9, 12),
      ]),
      'Lunes a Viernes 08:00–17:00 · Sábado 09:00–12:00',
    );
    expect(
      describeWeeklySlots([
        _slot(Weekday.monday, 8, 12),
        _slot(Weekday.monday, 14, 18),
        _slot(Weekday.tuesday, 8, 12),
        _slot(Weekday.tuesday, 14, 18),
        _slot(Weekday.thursday, 8, 12),
      ]),
      'Lunes y Martes 08:00–12:00, 14:00–18:00 · Jueves 08:00–12:00',
    );
  });

  testWidgets('sin oportunidades muestra ciudad, horario y especialidades',
      (tester) async {
    var availability = 0, specialties = 0;
    await _pump(
      tester,
      TechnicianOpportunitiesPage(
        loadOpportunities: () async => [],
        loadMatchSetup: () async => MatchSetup(
          zoneLoaded: true,
          city: 'Bogotá',
          slots: [_slot(Weekday.monday, 8, 17)],
          categories: {ServiceCategory.plumbing, ServiceCategory.electrical},
        ),
        onOpenAvailability: () => availability++,
        onOpenSpecialties: () => specialties++,
      ),
    );

    expect(find.byKey(const ValueKey('match-setup-summary')), findsOneWidget);
    expect(find.text('Bogotá'), findsOneWidget);
    expect(find.text('Lunes 08:00–17:00'), findsOneWidget);
    expect(find.text('Electricidad, Plomería'), findsOneWidget);
    expect(find.byKey(const ValueKey('match-setup-warning')), findsNothing);

    await tester
        .tap(find.byKey(const ValueKey('match-setup-open-availability')));
    await tester
        .tap(find.byKey(const ValueKey('match-setup-open-specialties')));
    expect(availability, 1);
    expect(specialties, 1);
  });

  testWidgets('avisa lo que falta y la ciudad que no coincide', (tester) async {
    await _pump(
      tester,
      TechnicianOpportunitiesPage(
        loadOpportunities: () async => [],
        loadMatchSetup: () async => const MatchSetup(
          zoneLoaded: true,
          city: 'dsa',
          slots: [],
          categories: {},
        ),
      ),
    );
    expect(find.text('dsa'), findsOneWidget);
    expect(find.text('Sin configurar'), findsOneWidget);
    expect(find.text('Sin especialidades'), findsOneWidget);
    final warning = find.byKey(const ValueKey('match-setup-warning'));
    expect(warning, findsOneWidget);
    expect(find.descendant(of: warning, matching: find.textContaining('«dsa»')),
        findsOneWidget);
    expect(
        find.descendant(
            of: warning, matching: find.textContaining('franja de horario')),
        findsOneWidget);
  });

  testWidgets('sin zona lo dice y lo que no cargó se ve como guion',
      (tester) async {
    await _pump(
      tester,
      TechnicianOpportunitiesPage(
        loadOpportunities: () async => [],
        loadMatchSetup: () async => const MatchSetup(zoneLoaded: true),
      ),
    );
    expect(find.text('Sin configurar'), findsOneWidget);
    expect(find.text('–'), findsNWidgets(2));
    expect(find.textContaining('Configura la ciudad'), findsOneWidget);
  });

  testWidgets('si la carga falla no inventa datos', (tester) async {
    await _pump(
      tester,
      TechnicianOpportunitiesPage(
        loadOpportunities: () async => [],
        loadMatchSetup: () async => throw Exception('caído'),
      ),
    );
    expect(find.text('–'), findsNWidgets(3));
    expect(find.byKey(const ValueKey('match-setup-warning')), findsNothing);
  });

  testWidgets('el inicio del técnico también lo muestra y recarga al volver',
      (tester) async {
    var loads = 0, opened = 0;
    await _pump(
      tester,
      TechnicianDashboardPage(
        loadOpportunities: () async {
          loads++;
          return [];
        },
        loadMatchSetup: () async => MatchSetup(
          zoneLoaded: true,
          city: 'Cali',
          slots: [_slot(Weekday.friday, 7, 15)],
          categories: {ServiceCategory.plumbing},
        ),
        onOpenAvailability: () async => opened++,
      ),
    );
    expect(find.text('Cali'), findsOneWidget);
    expect(find.text('Viernes 07:00–15:00'), findsOneWidget);
    final button = find.byKey(const ValueKey('match-setup-open-availability'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(loads, 2);
  });
}
