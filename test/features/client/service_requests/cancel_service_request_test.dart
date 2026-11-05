import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/core/domain/service_budget.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/features/client/service_requests/domain/applicant.dart';
import 'package:ms_frontend/features/client/service_requests/domain/service_request.dart';
import 'package:ms_frontend/features/client/service_requests/domain/service_request_exceptions.dart';
import 'package:ms_frontend/features/client/service_requests/infrastructure/http_service_request_repository.dart';
import 'package:ms_frontend/features/client/service_requests/presentation/service_request_detail_page.dart';

/// GC-515: el cliente cancela su solicitud antes de contratar.

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

Map<String, Object?> _requestJson(String status) => {
      'id': 'req-1',
      'category': 'PLUMBING',
      'description': 'Fuga de agua en el baño',
      'status': status,
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

class _Backend {
  _Backend(this.status);

  ServiceRequestStatus status;
  var cancelCalls = 0;
  Object? failure;

  Future<ServiceRequest> get(String id) async => _request(status);

  Future<List<Applicant>> list(String id) async => const [];

  Future<ServiceRequest> select(String id, String applicationId) async =>
      _request(status);

  Future<ServiceRequest> cancel(String id) async {
    cancelCalls++;
    if (failure != null) throw failure!;
    status = ServiceRequestStatus.cancelled;
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
      cancel: backend.cancel,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('HttpServiceRequestRepository.cancel', () {
    test('hace POST a /cancellation y devuelve la solicitud cancelada',
        () async {
      late http.Request sent;
      final cancelled = await _repository((r) async {
        sent = r;
        return _json(200, _requestJson('CANCELLED'));
      }).cancel('req-1');

      expect(sent.method, 'POST');
      expect(sent.url.toString(),
          'http://localhost/api/services/requests/req-1/cancellation');
      expect(sent.headers['Authorization'], 'Bearer token-1');
      expect(cancelled.status, ServiceRequestStatus.cancelled);
    });

    test('409 muestra el motivo del servidor', () async {
      await expectLater(
        _repository((_) async => _json(409, {
              'detail': 'Solo se puede cancelar una solicitud antes de contratar'
            })).cancel('req-1'),
        throwsA(isA<ServiceRequestFailure>().having((f) => f.message,
            'message', 'Solo se puede cancelar una solicitud antes de contratar')),
      );
    });
  });

  group('Detalle de la solicitud', () {
    for (final status in [
      ServiceRequestStatus.published,
      ServiceRequestStatus.providerSelected,
    ]) {
      testWidgets('ofrece cancelar mientras está ${status.label}',
          (tester) async {
        await _pump(tester, _Backend(status));

        expect(find.byKey(const ValueKey('request-cancel')), findsOneWidget);
      });
    }

    for (final status in [
      ServiceRequestStatus.contracted,
      ServiceRequestStatus.inProgress,
      ServiceRequestStatus.closed,
      ServiceRequestStatus.cancelled,
    ]) {
      testWidgets('no ofrece cancelar cuando está ${status.label}',
          (tester) async {
        await _pump(tester, _Backend(status));

        expect(find.byKey(const ValueKey('request-cancel')), findsNothing);
      });
    }

    testWidgets('confirma, cancela y muestra el estado que devuelve el servidor',
        (tester) async {
      final backend = _Backend(ServiceRequestStatus.published);
      await _pump(tester, backend);

      await tester.tap(find.byKey(const ValueKey('request-cancel')));
      await tester.pumpAndSettle();
      expect(find.text('Cancelar solicitud'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('request-cancel-confirm')));
      await tester.pumpAndSettle();

      expect(backend.cancelCalls, 1);
      expect(find.text('Cancelaste la solicitud.'), findsOneWidget);
      expect(find.text('Cancelada'), findsOneWidget);
      expect(find.byKey(const ValueKey('request-cancel')), findsNothing);
    });

    testWidgets('si el usuario vuelve atrás no cancela nada', (tester) async {
      final backend = _Backend(ServiceRequestStatus.published);
      await _pump(tester, backend);

      await tester.tap(find.byKey(const ValueKey('request-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();

      expect(backend.cancelCalls, 0);
      expect(find.text('Publicada'), findsOneWidget);
    });

    testWidgets('si el servidor lo rechaza muestra su mensaje', (tester) async {
      final backend = _Backend(ServiceRequestStatus.providerSelected)
        ..failure = const ServiceRequestFailure(
            'Solo se puede cancelar una solicitud antes de contratar');
      await _pump(tester, backend);

      await tester.tap(find.byKey(const ValueKey('request-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('request-cancel-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Solo se puede cancelar una solicitud antes de contratar'),
          findsOneWidget);
    });
  });
}
