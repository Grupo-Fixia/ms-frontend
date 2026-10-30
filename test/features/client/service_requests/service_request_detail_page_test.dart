import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/core/domain/service_budget.dart';
import 'package:ms_frontend/features/client/service_requests/domain/applicant.dart';
import 'package:ms_frontend/features/client/service_requests/domain/service_request.dart';
import 'package:ms_frontend/features/client/service_requests/domain/service_request_exceptions.dart';
import 'package:ms_frontend/features/client/service_requests/presentation/my_service_requests_page.dart';
import 'package:ms_frontend/features/client/service_requests/presentation/service_request_detail_page.dart';

ServiceRequest _request(ServiceRequestStatus status) => ServiceRequest(
      id: 'req-1',
      category: ServiceCategory.plumbing,
      description: 'Fuga en la cocina',
      status: status,
      approximateLocation:
          const ApproximateLocation(city: 'Bogotá', zone: 'Chapinero'),
      expectedAt: DateTime.utc(2027, 1, 15, 15),
      budget: ServiceBudget.tryParse('150000'),
    );

Applicant _applicant(
  String id, {
  ApplicationStatus status = ApplicationStatus.applied,
  String? price,
  ProviderPublicProfile? provider,
  ProviderType type = ProviderType.independent,
  ProviderPublicProfile? executor,
}) =>
    Applicant(
      id: id,
      providerId: 'prov-$id',
      status: status,
      providerType: type,
      proposedPrice: price == null ? null : ServiceBudget.tryParse(price),
      provider: provider,
      executor: executor,
    );

/// Backend en memoria: la selección cambia el estado como lo haría
/// ms-services y la página lo vuelve a consultar.
class _FakeBackend {
  var status = ServiceRequestStatus.published;
  var applicants = <Applicant>[
    _applicant(
      'a1',
      price: '140000',
      provider: const ProviderPublicProfile(
        displayName: 'Carlos G.',
        verificationStatus: VerificationStatus.pending,
        categories: [ServiceCategory.plumbing],
        professionalDescription: 'Plomero con experiencia',
        yearsOfExperience: 8,
        city: 'Bogotá',
      ),
    ),
    _applicant(
      'a2',
      price: '180000',
      type: ProviderType.company,
      provider: const ProviderPublicProfile(displayName: 'Arreglos SAS'),
      executor: const ProviderPublicProfile(displayName: 'Laura M.'),
    ),
    _applicant('a3'),
  ];
  Object? selectError;
  Object? applicantsError;
  final selections = <String>[];
  var gets = 0;

  Future<ServiceRequest> get(String id) async {
    gets++;
    return _request(status);
  }

  Future<List<Applicant>> list(String id) async {
    final error = applicantsError;
    if (error != null) throw error;
    return applicants;
  }

  Future<ServiceRequest> select(String id, String applicationId) async {
    selections.add(applicationId);
    final error = selectError;
    if (error != null) throw error;
    status = ServiceRequestStatus.providerSelected;
    applicants = [
      for (final a in applicants)
        _applicant(
          a.id,
          status: a.id == applicationId
              ? ApplicationStatus.selected
              : ApplicationStatus.rejected,
          price: a.proposedPrice?.amount,
          provider: a.provider,
          type: a.providerType,
          executor: a.executor,
        ),
    ];
    return _request(status);
  }
}

Future<void> _pump(WidgetTester tester, _FakeBackend backend) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: ServiceRequestDetailPage(
      requestId: 'req-1',
      get: backend.get,
      listApplicants: backend.list,
      selectProvider: backend.select,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('compara propuestas reales con precio y perfil público',
      (tester) async {
    await _pump(tester, _FakeBackend());

    expect(find.text('Compara las propuestas'), findsOneWidget);
    expect(find.text('3 propuestas · de 140.000 COP a 180.000 COP'),
        findsOneWidget);
    expect(find.text('Carlos G.'), findsOneWidget);
    expect(find.text('140.000 COP'), findsOneWidget);
    expect(find.text('8 años de experiencia'), findsOneWidget);
    expect(find.text('Pendiente de verificación'), findsOneWidget);
    expect(find.text('Arreglos SAS'), findsOneWidget);
    expect(find.text('Técnico propuesto: Laura M.'), findsOneWidget);
    // Sin perfil ni precio: no se inventan datos.
    expect(find.text('Prestador no disponible'), findsOneWidget);
    expect(find.text('Este prestador ya no está activo en Fixia.'),
        findsOneWidget);
    expect(find.text('Sin precio propuesto'), findsOneWidget);
    expect(find.text('Seleccionar'), findsNWidgets(3));
  });

  testWidgets('selecciona y muestra el estado que devuelve el servidor',
      (tester) async {
    final backend = _FakeBackend();
    await _pump(tester, backend);

    await tester.tap(find.descendant(
      of: find.byKey(const ValueKey('applicant-a2')),
      matching: find.text('Seleccionar'),
    ));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('¿Quieres elegir a Arreglos SAS por 180.000 COP?'),
        findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Seleccionar').last);
    await tester.pumpAndSettle();

    expect(backend.selections, ['a2']);
    expect(find.text('Seleccionaste a Arreglos SAS.'), findsOneWidget);
    expect(find.text('Prestador seleccionado'), findsOneWidget);
    expect(find.text('Seleccionado'), findsOneWidget);
    expect(find.text('No seleccionado'), findsNWidgets(2));
    expect(find.text('Seleccionar'), findsNothing);
    expect(find.text('Postulantes'), findsOneWidget);
  });

  testWidgets('cancelar la confirmación no selecciona', (tester) async {
    final backend = _FakeBackend();
    await _pump(tester, backend);
    await tester.tap(find.text('Seleccionar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(backend.selections, isEmpty);
  });

  testWidgets('un conflicto muestra el error y recarga desde el servidor',
      (tester) async {
    final backend = _FakeBackend()
      ..selectError = const ServiceRequestFailure(
          'Esta solicitud ya no admite seleccionar prestador.');
    await _pump(tester, backend);
    final getsBefore = backend.gets;

    await tester.tap(find.text('Seleccionar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Seleccionar').last);
    await tester.pumpAndSettle();

    expect(find.text('Esta solicitud ya no admite seleccionar prestador.'),
        findsOneWidget);
    expect(backend.gets, greaterThan(getsBefore));
    expect(find.text('Seleccionado'), findsNothing);
  });

  testWidgets('sin postulantes lo dice sin mostrar datos de ejemplo',
      (tester) async {
    await _pump(tester, _FakeBackend()..applicants = []);
    expect(
      find.text(
          'Todavía no hay prestadores postulados. Te mostraremos sus propuestas aquí.'),
      findsOneWidget,
    );
  });

  testWidgets('perfiles no disponibles: mensaje y reintento', (tester) async {
    final backend = _FakeBackend()
      ..applicantsError =
          const ServiceRequestFailure('Perfiles no disponibles');
    await _pump(tester, backend);
    expect(find.text('Perfiles no disponibles'), findsOneWidget);

    backend.applicantsError = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Carlos G.'), findsOneWidget);
  });

  testWidgets('desde Mis solicitudes abre el detalle y al volver actualiza',
      (tester) async {
    var loads = 0;
    ServiceRequest? opened;
    await tester.pumpWidget(MaterialApp(
      home: MyServiceRequestsPage(
        load: () async {
          loads++;
          return [_request(ServiceRequestStatus.closed)];
        },
        get: (_) async => _request(ServiceRequestStatus.closed),
        onOpen: (request) async => opened = request,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cerrada'), findsOneWidget);

    await tester.tap(find.text('Fuga en la cocina'));
    await tester.pumpAndSettle();
    expect(opened?.id, 'req-1');
    expect(loads, 2);
  });
}
