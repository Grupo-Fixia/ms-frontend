import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/client/service_requests/application/provider_profile_use_cases.dart';
import 'package:ms_frontend/features/client/service_requests/application/service_request_use_cases.dart';
import 'package:ms_frontend/features/client/service_requests/domain/service_request.dart';
import 'package:ms_frontend/features/client/service_requests/infrastructure/mock_provider_profile_repository.dart';
import 'package:ms_frontend/features/client/service_requests/infrastructure/mock_service_request_repository.dart';
import 'package:ms_frontend/features/client/service_requests/presentation/applicants_page.dart';

Widget _page(
  MockServiceRequestRepository repository, {
  ValueChanged<ServiceRequest>? onSelected,
}) =>
    MaterialApp(
      theme: FixiaTheme.light,
      home: ApplicantsPage(
        requestId: MockServiceRequestRepository.demoRequestId,
        listApplicants: ListApplicants(repository),
        selectProvider: SelectProvider(repository),
        getProfile: GetProviderPublicProfile(MockProviderProfileRepository()),
        onProviderSelected: onSelected,
      ),
    );

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('GC-349: lista postulantes con nombre, reputación y estado',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(_page(MockServiceRequestRepository.demo()));
    await tester.pumpAndSettle();

    expect(find.text('HidroSur Servicios'), findsOneWidget);
    expect(find.text('Julián Torres'), findsOneWidget);
    expect(find.text('4.5 (112)'), findsOneWidget);
    expect(find.text('Sin calificaciones aún'), findsOneWidget);
    expect(find.text('Pendiente'), findsNWidgets(2));
    expect(find.text('Seleccionar Prestador'), findsNWidgets(2));
  });

  testWidgets('GC-349: sin postulantes muestra un estado vacío',
      (tester) async {
    phone(tester);
    final repository = MockServiceRequestRepository.demo();
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: ApplicantsPage(
          requestId: MockServiceRequestRepository.demoRequestId,
          listApplicants: ListApplicants(MockServiceRequestRepository(
            requests: await repository.listMine(),
          )),
          selectProvider: SelectProvider(repository),
          getProfile: GetProviderPublicProfile(MockProviderProfileRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('applicants-empty')), findsOneWidget);
  });

  testWidgets('GC-350: abre el perfil público sin ubicación exacta',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(_page(MockServiceRequestRepository.demo()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('applicant-profile-postulacion-hidrosur')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Perfil del prestador'), findsOneWidget);
    expect(find.text('Verificado'), findsOneWidget);
    expect(find.text('Zona aproximada: Teusaquillo, Bogotá'), findsOneWidget);
    expect(find.textContaining('ubicación exacta'), findsOneWidget);
    expect(find.text('Plomería'), findsOneWidget);
    expect(find.text('Camilo T.'), findsOneWidget);
  });

  testWidgets('GC-349: selecciona al prestador y desestima a los demás',
      (tester) async {
    phone(tester);
    final repository = MockServiceRequestRepository.demo();
    ServiceRequest? selected;
    await tester.pumpWidget(_page(repository, onSelected: (r) => selected = r));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('applicant-select-postulacion-hidrosur')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('select-provider-confirm')));
    await tester.pumpAndSettle();

    expect(selected?.status, ServiceRequestStatus.providerSelected);
    expect(selected?.selectedProviderId, 'prestador-hidrosur');
    expect(find.text('Seleccionado'), findsOneWidget);
    expect(find.text('Desestimado'), findsOneWidget);
    expect(find.text('Prestador seleccionado'), findsOneWidget);
  });
}
