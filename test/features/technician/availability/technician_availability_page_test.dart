import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/technician/availability/application/get_technician_service_settings.dart';
import 'package:ms_frontend/features/technician/availability/application/ports/technician_availability_repository.dart';
import 'package:ms_frontend/features/technician/availability/application/save_technician_service_settings.dart';
import 'package:ms_frontend/features/technician/availability/domain/availability_day.dart';
import 'package:ms_frontend/features/technician/availability/domain/availability_hours.dart';
import 'package:ms_frontend/features/technician/availability/domain/coverage_zone.dart';
import 'package:ms_frontend/features/technician/availability/domain/technician_availability.dart';
import 'package:ms_frontend/features/technician/availability/domain/technician_service_settings.dart';
import 'package:ms_frontend/features/technician/availability/infrastructure/mock_technician_availability_repository.dart';
import 'package:ms_frontend/features/technician/availability/presentation/technician_availability_page.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    TechnicianAvailabilityRepository repository,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: TechnicianAvailabilityPage(
          getSettings: GetTechnicianServiceSettings(repository),
          saveSettings: SaveTechnicianServiceSettings(repository),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('muestra la agenda semanal y cobertura desde el mock local',
      (tester) async {
    final repository = MockTechnicianAvailabilityRepository();
    await pumpPage(tester, repository);

    expect(find.text('Disponibilidad y zona'), findsOneWidget);
    expect(find.byKey(const ValueKey('availability-toggle-Lunes')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('availability-toggle-Domingo')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('availability-start-time')),
        findsOneWidget);

    final cityDropdown =
        find.byKey(const ValueKey('availability-city-dropdown'));
    await tester.scrollUntilVisible(cityDropdown, 220,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Ciudad o municipio base'), findsOneWidget);
    final mapLabel = find.text('Bogotá · 15 km');
    await tester.scrollUntilVisible(mapLabel, 180,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Vista ilustrativa'), findsOneWidget);
    expect(find.byKey(const ValueKey('availability-save')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guardar persiste la ciudad elegida en el repositorio de demo',
      (tester) async {
    final repository = MockTechnicianAvailabilityRepository();
    await pumpPage(tester, repository);

    final cityDropdown =
        find.byKey(const ValueKey('availability-city-dropdown'));
    await tester.scrollUntilVisible(cityDropdown, 220,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(cityDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Medellín').last);
    await tester.pumpAndSettle();

    final saveButton = find.byKey(const ValueKey('availability-save'));
    await tester.scrollUntilVisible(saveButton, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    final saved = await repository.fetchSettings();
    expect(saved.coverageZone.city, 'Medellín');
    expect(find.text('Disponibilidad y zona guardadas en esta demostración.'),
        findsOneWidget);
  });

  testWidgets('el radio seleccionado actualiza el mapa ilustrativo',
      (tester) async {
    await pumpPage(tester, MockTechnicianAvailabilityRepository());

    final slider = find.byKey(const ValueKey('coverage-radius-slider'));
    final radiusCircle = find.byKey(const ValueKey('coverage-zone-radius'));
    await tester.scrollUntilVisible(radiusCircle, 240,
        scrollable: find.byType(Scrollable).first);
    final initialDiameter = tester.getSize(radiusCircle).width;
    await tester.scrollUntilVisible(slider, 240,
        scrollable: find.byType(Scrollable).first);
    await tester.drag(slider, const Offset(100, 0));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(radiusCircle, 240,
        scrollable: find.byType(Scrollable).first);

    expect(tester.getSize(radiusCircle).width, greaterThan(initialDiameter));
  });
  testWidgets('no permite guardar si se desactivan todos los días',
      (tester) async {
    final repository = MockTechnicianAvailabilityRepository();
    await pumpPage(tester, repository);

    // Lunes a sábado están activos en el mock; Domingo no.
    for (final day in AvailabilityDay.values.take(6)) {
      await tester.tap(find.byKey(ValueKey('availability-toggle-${day.label}')));
      await tester.pumpAndSettle();
    }

    final daysError = find.byKey(const ValueKey('availability-days-error'));
    await tester.scrollUntilVisible(daysError, 200,
        scrollable: find.byType(Scrollable).first);
    expect(daysError, findsOneWidget);
    final saveButton = find.byKey(const ValueKey('availability-save'));
    await tester.scrollUntilVisible(saveButton, 200,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
  });

  testWidgets('muestra validación cuando la hora final no supera la inicial',
      (tester) async {
    final repository = _SettingsRepository(
      TechnicianServiceSettings(
        availability: TechnicianAvailability(
          days: const {
            AvailabilityDay.monday:
                AvailabilityHours(startMinutes: 600, endMinutes: 600),
          },
        ),
        coverageZone: const CoverageZone(city: 'Bogotá', radiusKm: 10),
      ),
    );
    await pumpPage(tester, repository);

    expect(find.text('La hora final debe ser posterior a la inicial.'),
        findsOneWidget);
    final saveButton = find.byKey(const ValueKey('availability-save'));
    await tester.scrollUntilVisible(saveButton, 200,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
  });
}

class _SettingsRepository implements TechnicianAvailabilityRepository {
  _SettingsRepository(this.settings);

  final TechnicianServiceSettings settings;

  @override
  Future<TechnicianServiceSettings> fetchSettings() async => settings;

  @override
  Future<void> saveSettings(TechnicianServiceSettings settings) async {}
}
