import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/technician/availability/application/ports/technician_availability_repository.dart';
import 'package:ms_frontend/features/technician/availability/domain/clock_time.dart';
import 'package:ms_frontend/features/technician/availability/domain/coverage_zone.dart';
import 'package:ms_frontend/features/technician/availability/domain/technician_availability_exceptions.dart';
import 'package:ms_frontend/features/technician/availability/domain/weekday.dart';
import 'package:ms_frontend/features/technician/availability/domain/weekly_availability.dart';
import 'package:ms_frontend/features/technician/availability/presentation/technician_availability_page.dart';

class _Repo implements TechnicianAvailabilityRepository {
  _Repo({this.slots = const [], this.zone});

  List<AvailabilitySlot> slots;
  CoverageZone? zone;
  Object? loadError;
  Object? saveError;
  var replaces = 0;

  @override
  Future<WeeklyAvailability> fetchAvailability() async {
    if (loadError != null) throw loadError!;
    return WeeklyAvailability(slots: slots);
  }

  @override
  Future<CoverageZone?> fetchCoverageZone() async {
    if (loadError != null) throw loadError!;
    return zone;
  }

  @override
  Future<WeeklyAvailability> replaceAvailability(
      List<AvailabilitySlot> slots) async {
    if (saveError != null) throw saveError!;
    replaces++;
    this.slots = slots;
    return WeeklyAvailability(slots: slots);
  }

  @override
  Future<CoverageZone> updateCoverageZone(CoverageZoneUpdate update) async {
    if (saveError != null) throw saveError!;
    return zone = CoverageZone(
      city: update.city,
      latitude: update.latitude,
      longitude: update.longitude,
      radiusKm: update.radiusKm,
    );
  }

  @override
  Future<void> clearCoverageZone() async => zone = null;
}

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _pump(WidgetTester tester, _Repo repo,
    {Size size = const Size(1440, 1400), VoidCallback? onSaved}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: FixiaTheme.light,
    home: TechnicianAvailabilityPage(repository: repo, onSaved: onSaved),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key));
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sin configurar: exige ciudad y al menos un día', (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);

    expect(find.text('Horario y zona de atención'), findsOneWidget);
    expect(find.text('No atiendes'), findsNWidgets(7));
    await _tap(tester, 'availability-save');
    expect(find.text('Ingresa la ciudad donde atiendes.'), findsOneWidget);
    expect(find.text('Activa al menos un día con su horario.'), findsOneWidget);
    expect(repo.replaces, 0);
  });

  testWidgets('usa una plantilla y guarda zona y franjas', (tester) async {
    final repo = _Repo();
    var saved = 0;
    await _pump(tester, repo, onSaved: () => saved++);

    await _tap(tester, 'availability-city-Bogotá');
    await _tap(tester, 'availability-preset-weekdays');
    expect(find.text('No atiendes'), findsNWidgets(2));
    await _tap(tester, 'availability-save');

    expect(repo.zone?.city, 'Bogotá');
    expect(repo.slots, hasLength(5));
    expect(
        repo.slots.first,
        const AvailabilitySlot(
            day: Weekday.monday,
            start: ClockTime(8, 0),
            end: ClockTime(17, 0)));
    expect(_key('availability-saved'), findsOneWidget);
    expect(saved, 1);
  });

  testWidgets('carga lo guardado, edita franjas y detecta cruces',
      (tester) async {
    final repo = _Repo(
      zone: const CoverageZone(
          city: 'Medellín', latitude: 6.2, longitude: -75.5, radiusKm: 10),
      slots: const [
        AvailabilitySlot(
            day: Weekday.monday, start: ClockTime(8, 0), end: ClockTime(12, 0)),
      ],
    );
    await _pump(tester, repo);

    expect(find.text('Medellín'), findsWidgets);
    expect(find.textContaining('radio de 10 km'), findsOneWidget);
    await _tap(tester, 'availability-add-MONDAY');
    // La segunda franja empieza una hora después de la primera.
    expect(_key('availability-start-MONDAY-1'), findsOneWidget);

    // Cruzar las franjas: la segunda empieza a las 9:00.
    await tester.tap(_key('availability-start-MONDAY-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('09:00').last);
    await tester.pumpAndSettle();
    expect(_key('availability-slots-error'), findsOneWidget);

    await _tap(tester, 'availability-remove-MONDAY-1');
    expect(_key('availability-slots-error'), findsNothing);
    await _tap(tester, 'availability-copy-monday');
    await _tap(tester, 'availability-toggle-SUNDAY');
    await _tap(tester, 'availability-save');
    expect(repo.slots, hasLength(6));
    // Conserva el radio que ya tenía.
    expect(repo.zone?.radiusKm, 10);
  });

  testWidgets('error al cargar permite reintentar', (tester) async {
    final repo = _Repo()
      ..loadError = const TechnicianAvailabilityFailure('Sin conexión');
    await _pump(tester, repo);
    expect(find.text('Sin conexión'), findsOneWidget);
    repo.loadError = null;
    await _tap(tester, 'availability-retry');
    expect(find.text('Horario semanal'), findsOneWidget);
  });

  testWidgets('error al guardar se muestra y la sesión vencida avisa',
      (tester) async {
    final repo = _Repo()
      ..saveError = const TechnicianAvailabilityFailure('Ciudad inválida',
          fieldErrors: {'city': 'Ciudad no reconocida.'});
    await _pump(tester, repo);
    await _tap(tester, 'availability-city-Cali');
    await _tap(tester, 'availability-toggle-MONDAY');
    await _tap(tester, 'availability-save');
    expect(find.text('Ciudad no reconocida.'), findsOneWidget);
    expect(_key('availability-save-error'), findsOneWidget);

    var expired = 0;
    final expiredRepo = _Repo()
      ..loadError =
          const TechnicianAvailabilityFailure('x', isSessionExpired: true);
    tester.view.physicalSize = const Size(1440, 1400);
    await tester.pumpWidget(MaterialApp(
      theme: FixiaTheme.light,
      home: TechnicianAvailabilityPage(
          key: const ValueKey('otra'),
          repository: expiredRepo, onSessionExpired: () => expired++),
    ));
    // La app navega al login; aquí la pantalla sigue cargando.
    await tester.pump();
    await tester.pump();
    expect(expired, 1);
  });

  testWidgets('en celular no desborda', (tester) async {
    final repo = _Repo();
    await _pump(tester, repo, size: const Size(360, 1800));
    await _tap(tester, 'availability-preset-all');
    expect(find.text('No atiendes'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
