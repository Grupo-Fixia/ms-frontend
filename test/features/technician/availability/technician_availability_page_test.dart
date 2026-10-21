import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/technician/availability/application/availability_use_cases.dart';
import 'package:ms_frontend/features/technician/availability/application/ports/technician_availability_repository.dart';
import 'package:ms_frontend/features/technician/availability/domain/clock_time.dart';
import 'package:ms_frontend/features/technician/availability/domain/technician_availability_exceptions.dart';
import 'package:ms_frontend/features/technician/availability/domain/weekday.dart';
import 'package:ms_frontend/features/technician/availability/domain/weekly_availability.dart';
import 'package:ms_frontend/features/technician/availability/infrastructure/demo_technician_availability_repository.dart';
import 'package:ms_frontend/features/technician/availability/presentation/technician_availability_page.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    TechnicianAvailabilityRepository repository, {
    VoidCallback? onSessionExpired,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: TechnicianAvailabilityPage(
          getAvailability: GetWeeklyAvailability(repository),
          replaceAvailability: ReplaceWeeklyAvailability(repository),
          getCoverageZone: GetCoverageZone(repository),
          updateCoverageZone: UpdateCoverageZone(repository),
          onSessionExpired: onSessionExpired,
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
  }

  Finder scrollable() => find.byType(Scrollable).first;

  testWidgets('muestra la agenda y la zona que entrega el repositorio',
      (tester) async {
    await pumpPage(tester, DemoTechnicianAvailabilityRepository());

    expect(find.text('Disponibilidad y zona'), findsOneWidget);
    expect(find.byKey(const ValueKey('availability-toggle-Lunes')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('availability-toggle-Domingo')),
        findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('17:00'), findsOneWidget);
    expect(find.text('Lunes a viernes'), findsOneWidget);

    final mapLabel = find.text('Bogotá · 15 km');
    await tester.scrollUntilVisible(mapLabel, 180, scrollable: scrollable());
    final note = find.textContaining('Ubicación aproximada');
    await tester.scrollUntilVisible(note, 180, scrollable: scrollable());
    expect(note, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guardar envía las franjas y la ciudad al repositorio',
      (tester) async {
    final repository = DemoTechnicianAvailabilityRepository();
    await pumpPage(tester, repository);

    await tester.tap(find.byKey(const ValueKey('availability-toggle-Sábado')));
    await tester.pumpAndSettle();

    final cityDropdown =
        find.byKey(const ValueKey('availability-city-dropdown'));
    await tester.scrollUntilVisible(cityDropdown, 220,
        scrollable: scrollable());
    await tester.tap(cityDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Medellín').last);
    await tester.pumpAndSettle();

    final saveButton = find.byKey(const ValueKey('availability-save'));
    await tester.scrollUntilVisible(saveButton, 200, scrollable: scrollable());
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    final availability = await repository.fetchAvailability();
    final zone = await repository.fetchCoverageZone();
    expect(availability.slots.length, 6);
    expect(availability.slots.last.day, Weekday.saturday);
    expect(zone?.city, 'Medellín');
    expect(zone?.radiusKm, 15);
    expect(find.text('Disponibilidad y zona guardadas.'), findsOneWidget);
  });

  testWidgets('el radio seleccionado actualiza el mapa ilustrativo',
      (tester) async {
    await pumpPage(tester, DemoTechnicianAvailabilityRepository());

    final slider = find.byKey(const ValueKey('coverage-radius-slider'));
    final radiusCircle = find.byKey(const ValueKey('coverage-zone-radius'));
    await tester.scrollUntilVisible(radiusCircle, 240,
        scrollable: scrollable());
    final initialDiameter = tester.getSize(radiusCircle).width;
    await tester.scrollUntilVisible(slider, 240, scrollable: scrollable());
    await tester.drag(slider, const Offset(100, 0));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(radiusCircle, 240,
        scrollable: scrollable());

    expect(tester.getSize(radiusCircle).width, greaterThan(initialDiameter));
  });

  testWidgets('no permite guardar si se desactivan todos los días',
      (tester) async {
    await pumpPage(tester, DemoTechnicianAvailabilityRepository());

    for (final day in Weekday.values.take(5)) {
      await tester
          .tap(find.byKey(ValueKey('availability-toggle-${day.label}')));
      await tester.pumpAndSettle();
    }

    final daysError = find.byKey(const ValueKey('availability-days-error'));
    await tester.scrollUntilVisible(daysError, 200, scrollable: scrollable());
    expect(daysError, findsOneWidget);
    final saveButton = find.byKey(const ValueKey('availability-save'));
    await tester.scrollUntilVisible(saveButton, 200, scrollable: scrollable());
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
  });

  testWidgets('valida cuando la hora final no supera la inicial',
      (tester) async {
    final repository = DemoTechnicianAvailabilityRepository(
      slots: const [
        AvailabilitySlot(
          day: Weekday.monday,
          start: ClockTime(10, 0),
          end: ClockTime(10, 0),
        ),
      ],
    );
    await pumpPage(tester, repository);

    expect(find.text('La hora final debe ser posterior a la inicial.'),
        findsOneWidget);
    final saveButton = find.byKey(const ValueKey('availability-save'));
    await tester.scrollUntilVisible(saveButton, 200, scrollable: scrollable());
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
  });

  testWidgets('ante un error de carga permite reintentar', (tester) async {
    final repository = _FailingRepository(
      const TechnicianAvailabilityFailure('No pudimos conectar.'),
    );
    await pumpPage(tester, repository);

    expect(find.text('No pudimos conectar.'), findsOneWidget);
    repository.failure = null;
    await tester.tap(find.byKey(const ValueKey('availability-retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('availability-schedule-card')),
        findsOneWidget);
  });

  testWidgets('con sesión vencida avisa para volver a iniciar sesión',
      (tester) async {
    var expired = false;
    final repository = _FailingRepository(
      const TechnicianAvailabilityFailure('Sesión vencida.',
          isSessionExpired: true),
    );
    await pumpPage(
      tester,
      repository,
      onSessionExpired: () => expired = true,
      settle: false,
    );

    expect(expired, isTrue);
  });
}

class _FailingRepository extends DemoTechnicianAvailabilityRepository {
  _FailingRepository(this.failure);

  TechnicianAvailabilityFailure? failure;

  @override
  Future<WeeklyAvailability> fetchAvailability() async {
    final error = failure;
    if (error != null) throw error;
    return super.fetchAvailability();
  }
}
