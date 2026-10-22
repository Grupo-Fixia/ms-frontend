import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/features/client/service_requests/domain/applicant.dart';
import 'package:ms_frontend/features/client/service_requests/domain/service_request.dart';
import 'package:ms_frontend/features/client/service_requests/domain/service_request_exceptions.dart';
import 'package:ms_frontend/features/client/service_requests/infrastructure/http_service_request_repository.dart';

const _requests = 'http://localhost/api/services/requests';

/// Respuesta como la de ms-services: JSON en UTF-8 sin charset en el header.
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

TypeMatcher<ServiceRequestFailure> _failure(String message) =>
    isA<ServiceRequestFailure>().having((f) => f.message, 'message', message);

Map<String, Object?> _selectedRequest() => {
      'id': 'req-1',
      'category': 'PLUMBING',
      'description': 'Fuga',
      'status': 'PROVIDER_SELECTED',
      'approximateLocation': {'city': 'Bogotá', 'zone': 'Chapinero'},
      'expectedAt': '2026-10-21T15:00:00Z',
      'selectedProviderId': 'tec-2',
    };

void main() {
  group('listApplicants', () {
    test('consulta los postulantes en orden de llegada', () async {
      late http.Request sent;
      final applicants = await _repository((request) async {
        sent = request;
        return _json(200, [
          {
            'id': 'app-1',
            'providerId': 'tec-1',
            'status': 'APPLIED',
            'createdAt': '2026-10-20T15:00:00Z',
            'updatedAt': '2026-10-20T15:00:00Z',
          },
          {'id': 'app-2', 'providerId': 'tec-2', 'status': 'SELECTED'},
          {'id': 'app-3', 'providerId': 'tec-3', 'status': 'NUEVO'},
          {'id': 'app-4', 'providerId': '', 'status': 'APPLIED'},
          {'id': '', 'providerId': 'tec-5', 'status': 'APPLIED'},
          'basura',
        ]);
      }).listApplicants('req-1');

      expect(sent.method, 'GET');
      expect(sent.url.toString(), '$_requests/req-1/applications');
      expect(sent.headers['Authorization'], 'Bearer token-1');
      expect(applicants.map((a) => a.id), ['app-1', 'app-2']);
      expect(applicants.first.status, ApplicationStatus.applied);
      expect(applicants.first.createdAt, DateTime.utc(2026, 10, 20, 15));
      expect(applicants.last.status, ApplicationStatus.selected);
      expect(applicants.last.updatedAt, isNull);
      expect(() => (applicants as List).add(applicants.first),
          throwsUnsupportedError);
    });

    test('sin postulantes devuelve una lista vacía', () async {
      expect(
        await _repository((_) async => _json(200, [])).listApplicants('req-1'),
        isEmpty,
      );
    });

    test('si la respuesta no es una lista, es un error', () async {
      await expectLater(
        _repository((_) async => _json(200, {})).listApplicants('req-1'),
        throwsA(_failure(HttpServiceRequestRepository.unexpectedErrorMessage)),
      );
    });

    test('404: la solicitud no existe o es de otro cliente', () async {
      await expectLater(
        _repository((_) async => _json(404, {
              'title': 'Solicitud no encontrada',
            })).listApplicants('req-1'),
        throwsA(_failure(HttpServiceRequestRepository.notFoundMessage)),
      );
    });
  });

  group('selectProvider', () {
    test('selecciona y devuelve la solicitud con el prestador', () async {
      late http.Request sent;
      final request = await _repository((r) async {
        sent = r;
        return _json(200, _selectedRequest());
      }).selectProvider('req-1', 'app-2');

      expect(sent.method, 'POST');
      expect(
        sent.url.toString(),
        '$_requests/req-1/applications/app-2/selection',
      );
      expect(request.status, ServiceRequestStatus.providerSelected);
      expect(request.selectedProviderId, 'tec-2');
    });

    test('409: la solicitud ya no admite seleccionar prestador', () async {
      await expectLater(
        _repository(
                (_) async => _json(409, {'title': 'Solicitud no disponible'}))
            .selectProvider('req-1', 'app-2'),
        throwsA(_failure(HttpServiceRequestRepository.notSelectableMessage)),
      );
    });

    test('404 de postulación: no está entre los postulantes', () async {
      await expectLater(
        _repository((_) async => _json(404, {
              'title': 'Postulación no encontrada',
            })).selectProvider('req-1', 'app-9'),
        throwsA(
          _failure(HttpServiceRequestRepository.applicationNotFoundMessage),
        ),
      );
    });

    test('404 sin cuerpo: la solicitud no existe', () async {
      await expectLater(
        _repository((_) async => http.Response('', 404))
            .selectProvider('req-1', 'app-2'),
        throwsA(_failure(HttpServiceRequestRepository.notFoundMessage)),
      );
    });

    test('si la respuesta no trae una solicitud válida, es un error', () async {
      await expectLater(
        _repository((_) async => _json(200, {'id': 'req-1'}))
            .selectProvider('req-1', 'app-2'),
        throwsA(_failure(HttpServiceRequestRepository.unexpectedErrorMessage)),
      );
    });

    test('sin red se pide revisar la conexión', () async {
      await expectLater(
        _repository((_) => throw http.ClientException('sin red'))
            .selectProvider('req-1', 'app-2'),
        throwsA(_failure(HttpServiceRequestRepository.connectionErrorMessage)),
      );
    });
  });
}
