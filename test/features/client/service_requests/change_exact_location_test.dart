import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/core/domain/service_budget.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/features/client/service_requests/application/ports/service_request_repository.dart';
import 'package:ms_frontend/features/client/service_requests/application/service_request_use_cases.dart';
import 'package:ms_frontend/features/client/service_requests/domain/applicant.dart';
import 'package:ms_frontend/features/client/service_requests/domain/service_request.dart';
import 'package:ms_frontend/features/client/service_requests/domain/service_request_exceptions.dart';
import 'package:ms_frontend/features/client/service_requests/infrastructure/http_service_request_repository.dart';
import 'package:ms_frontend/features/client/service_requests/presentation/service_request_detail_page.dart';

/// GC-514: el cliente cambia la dirección exacta antes de contratar.

http.Response _json(int status, Object? body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json'},
    );

HttpServiceRequestRepository _repository(MockClientHandler handler) =>
    HttpServiceRequestRepository(
      client: MockClient(handler),
      baseUrl: Uri.parse('http://localhost'),
      authorizedHttp: AuthorizedHttp(
        accessToken: () => 'token-1',
        renewSession: () async => false,
      ),
    );

const _requestJson = {
  'id': 'req-1',
  'category': 'PLUMBING',
  'description': 'Fuga de agua en el baño',
  'status': 'PUBLISHED',
  'approximateLocation': {'city': 'Bogotá', 'zone': 'Chapinero'},
  'expectedAt': '2027-01-15T15:00:00Z',
  'budgetAmount': 150000,
  'budgetCurrency': 'COP',
  'photoKeys': [],
};

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

/// Solo registra la llamada; el resto de la interfaz no se usa aquí.
class _RecordingRepository implements ServiceRequestRepository {
  (String, ExactLocation)? changed;

  @override
  Future<ServiceRequest> changeExactLocation(
      String requestId, ExactLocation location) async {
    changed = (requestId, location);
    return _request(ServiceRequestStatus.published);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Backend {
  _Backend(this.status);

  final ServiceRequestStatus status;
  String? savedAddress;
  Object? failure;

  Future<ServiceRequest> get(String id) async => _request(status);

  Future<List<Applicant>> list(String id) async => const [];

  Future<ServiceRequest> select(String id, String applicationId) async =>
      _request(status);

  Future<ServiceRequest> change(String id, String address) async {
    if (failure != null) throw failure!;
    savedAddress = address;
    return _request(status);
  }
}

Future<void> _pump(WidgetTester tester, _Backend backend) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: ServiceRequestDetailPage(
      requestId: 'req-1',
      get: backend.get,
      listApplicants: backend.list,
      selectProvider: backend.select,
      changeExactLocation: backend.change,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('HttpServiceRequestRepository.changeExactLocation', () {
    test('hace PATCH a /exact-location con la dirección', () async {
      late http.Request sent;
      await _repository((r) async {
        sent = r;
        return _json(200, _requestJson);
      }).changeExactLocation(
        'req-1',
        const ExactLocation(address: 'Carrera 7 # 45-10', latitude: 4.63),
      );

      expect(sent.method, 'PATCH');
      expect(sent.url.toString(),
          'http://localhost/api/services/requests/req-1/exact-location');
      expect(jsonDecode(sent.body),
          {'address': 'Carrera 7 # 45-10', 'latitude': 4.63});
    });

    test('409 muestra el motivo del servidor', () async {
      await expectLater(
        _repository((_) async => _json(409, {
              'detail':
                  'Solo se puede cambiar la dirección exacta antes de contratar'
            })).changeExactLocation(
            'req-1', const ExactLocation(address: 'Carrera 7')),
        throwsA(isA<ServiceRequestFailure>().having(
            (f) => f.message,
            'message',
            'Solo se puede cambiar la dirección exacta antes de contratar')),
      );
    });
  });

  group('ChangeExactLocation', () {
    test('limpia espacios y envía la dirección', () async {
      final repository = _RecordingRepository();

      await ChangeExactLocation(repository)(' req-1 ', '  Carrera 7 # 45-10  ');

      expect(repository.changed?.$1, 'req-1');
      expect(repository.changed?.$2.address, 'Carrera 7 # 45-10');
    });

    test('vacía o demasiado larga no llega al backend', () async {
      final repository = _RecordingRepository();

      await expectLater(ChangeExactLocation(repository)('req-1', '   '),
          throwsA(isA<ServiceRequestFailure>()));
      await expectLater(ChangeExactLocation(repository)('req-1', 'x' * 256),
          throwsA(isA<ServiceRequestFailure>()));
      expect(repository.changed, isNull);
    });
  });

  group('Detalle de la solicitud', () {
    testWidgets('ofrece cambiar la dirección antes de contratar',
        (tester) async {
      await _pump(tester, _Backend(ServiceRequestStatus.providerSelected));

      expect(
          find.byKey(const ValueKey('request-change-address')), findsOneWidget);
    });

    testWidgets('no la ofrece después de contratar', (tester) async {
      await _pump(tester, _Backend(ServiceRequestStatus.contracted));

      expect(find.byKey(const ValueKey('request-change-address')), findsNothing);
    });

    testWidgets('guarda la nueva dirección y lo confirma', (tester) async {
      final backend = _Backend(ServiceRequestStatus.published);
      await _pump(tester, backend);

      await tester.tap(find.byKey(const ValueKey('request-change-address')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('request-address-save')));
      await tester.pump();
      expect(find.text('Ingresa la dirección.'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('request-address-field')),
          'Carrera 7 # 45-10');
      await tester.tap(find.byKey(const ValueKey('request-address-save')));
      await tester.pumpAndSettle();

      expect(backend.savedAddress, 'Carrera 7 # 45-10');
      expect(find.textContaining('Actualizamos la dirección exacta'),
          findsOneWidget);
    });

    testWidgets('si el servidor lo rechaza muestra su mensaje', (tester) async {
      final backend = _Backend(ServiceRequestStatus.published)
        ..failure = const ServiceRequestFailure(
            'Solo se puede cambiar la dirección exacta antes de contratar');
      await _pump(tester, backend);

      await tester.tap(find.byKey(const ValueKey('request-change-address')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('request-address-field')), 'Carrera 7');
      await tester.tap(find.byKey(const ValueKey('request-address-save')));
      await tester.pumpAndSettle();

      expect(
          find.text(
              'Solo se puede cambiar la dirección exacta antes de contratar'),
          findsOneWidget);
    });
  });
}
