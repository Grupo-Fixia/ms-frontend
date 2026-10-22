import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/features/technician/availability/domain/clock_time.dart';
import 'package:ms_frontend/features/technician/availability/domain/coverage_zone.dart';
import 'package:ms_frontend/features/technician/availability/domain/technician_availability_exceptions.dart';
import 'package:ms_frontend/features/technician/availability/domain/weekday.dart';
import 'package:ms_frontend/features/technician/availability/domain/weekly_availability.dart';
import 'package:ms_frontend/features/technician/availability/infrastructure/http_technician_availability_repository.dart';

const _availability = 'http://localhost/api/users/technicians/me/availability';
const _zone = 'http://localhost/api/users/technicians/me/coverage-zone';

/// Respuesta como la de ms-users: JSON en UTF-8 sin charset en el header.
http.Response _json(int status, Object? body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json'},
    );

HttpTechnicianAvailabilityRepository _repository(MockClientHandler handler) =>
    HttpTechnicianAvailabilityRepository(
      client: MockClient(handler),
      baseUrl: Uri.parse('http://localhost'),
      authorizedHttp: AuthorizedHttp(
        accessToken: () => 'token-1',
        renewSession: () async => false,
      ),
    );

Matcher _failure({
  String? message,
  Map<String, String>? fieldErrors,
  bool isSessionExpired = false,
}) {
  var matcher = isA<TechnicianAvailabilityFailure>().having(
    (f) => f.isSessionExpired,
    'isSessionExpired',
    isSessionExpired,
  );
  if (message != null) {
    matcher = matcher.having((f) => f.message, 'message', message);
  }
  if (fieldErrors != null) {
    matcher = matcher.having((f) => f.fieldErrors, 'fieldErrors', fieldErrors);
  }
  return matcher;
}

AvailabilitySlot _slot(Weekday day, String start, String end) =>
    AvailabilitySlot(
      day: day,
      start: ClockTime.tryParse(start)!,
      end: ClockTime.tryParse(end)!,
    );

void main() {
  group('disponibilidad', () {
    test('consulta y ordena las franjas por día y hora', () async {
      late http.Request sent;
      final availability = await _repository((request) async {
        sent = request;
        return _json(200, {
          'slots': [
            {'dayOfWeek': 'TUESDAY', 'startTime': '08:00', 'endTime': '12:00'},
            {'dayOfWeek': 'MONDAY', 'startTime': '14:00', 'endTime': '18:00'},
            {'dayOfWeek': 'MONDAY', 'startTime': '08:00', 'endTime': '12:00'},
            {'dayOfWeek': 'OTRO', 'startTime': '08:00', 'endTime': '12:00'},
            {'dayOfWeek': 'MONDAY', 'startTime': 8, 'endTime': '12:00'},
            'basura',
          ],
          'timeZone': 'America/Bogota',
          'updatedAt': '2026-10-19T15:00:00Z',
        });
      }).fetchAvailability();

      expect(sent.method, 'GET');
      expect(sent.url.toString(), _availability);
      expect(sent.headers['Authorization'], 'Bearer token-1');
      expect(availability.slots, [
        _slot(Weekday.monday, '08:00', '12:00'),
        _slot(Weekday.monday, '14:00', '18:00'),
        _slot(Weekday.tuesday, '08:00', '12:00'),
      ]);
      expect(availability.timeZone, 'America/Bogota');
      expect(availability.updatedAt, DateTime.utc(2026, 10, 19, 15));
    });

    test('sin franjas ni zona horaria usa los valores por defecto', () async {
      final availability = await _repository(
        (_) async => _json(200, {'slots': []}),
      ).fetchAvailability();

      expect(availability.slots, isEmpty);
      expect(availability.timeZone, 'America/Bogota');
      expect(availability.updatedAt, isNull);
    });

    test('reemplaza las franjas con horas "HH:mm"', () async {
      late http.Request sent;
      await _repository((request) async {
        sent = request;
        return _json(200, {'slots': []});
      }).replaceAvailability([_slot(Weekday.friday, '07:30', '11:00')]);

      expect(sent.method, 'PUT');
      expect(sent.url.toString(), _availability);
      expect(sent.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(sent.body), {
        'slots': [
          {'dayOfWeek': 'FRIDAY', 'startTime': '07:30', 'endTime': '11:00'},
        ],
      });
    });

    test('regla de negocio del backend: muestra el detail', () async {
      await expectLater(
        _repository((_) async => _json(400, {
              'detail': 'Las franjas de disponibilidad no pueden cruzarse',
            })).replaceAvailability([]),
        throwsA(_failure(
          message: 'Las franjas de disponibilidad no pueden cruzarse',
          fieldErrors: {},
        )),
      );
    });

    test('400 por campo agrupa slots[n].campo en slots', () async {
      await expectLater(
        _repository((_) async => _json(400, {
              'detail': 'Hay datos que debe corregir',
              'errors': [
                {'field': 'slots[0].startTime', 'message': 'Obligatoria'},
                {'field': 'slots[1].endTime', 'message': 'Otra'},
                {'field': 'x', 'message': ''},
                'basura',
              ],
            })).replaceAvailability([]),
        throwsA(_failure(
          message: HttpTechnicianAvailabilityRepository.invalidDataMessage,
          fieldErrors: {'slots': 'Obligatoria'},
        )),
      );
    });

    test('400 sin cuerpo usa el mensaje genérico', () async {
      await expectLater(
        _repository((_) async => http.Response('', 400))
            .replaceAvailability([]),
        throwsA(_failure(
          message: HttpTechnicianAvailabilityRepository.invalidDataMessage,
        )),
      );
    });

    for (final body in [
      null,
      'texto',
      {'slots': 'x'}
    ]) {
      test('respuesta inválida ($body) es un error genérico', () async {
        await expectLater(
          _repository((_) async => _json(200, body)).fetchAvailability(),
          throwsA(_failure(
            message:
                HttpTechnicianAvailabilityRepository.unexpectedErrorMessage,
          )),
        );
      });
    }
  });

  group('zona de atención', () {
    test('consulta la zona con círculo', () async {
      late http.Request sent;
      final zone = await _repository((request) async {
        sent = request;
        return _json(200, {
          'city': 'Bogotá',
          'latitude': 4.65,
          'longitude': -74,
          'radiusKm': 15,
          'updatedAt': '2026-10-19T15:00:00Z',
        });
      }).fetchCoverageZone();

      expect(sent.url.toString(), _zone);
      expect(zone!.city, 'Bogotá');
      expect(zone.longitude, -74.0);
      expect(zone.radiusKm, 15);
      expect(zone.hasCircle, isTrue);
    });

    test('sin zona declarada devuelve null', () async {
      final zone = await _repository((_) async => _json(200, {
            'city': null,
            'latitude': null,
            'longitude': null,
            'radiusKm': null,
          })).fetchCoverageZone();

      expect(zone, isNull);
    });

    test('declara la zona y devuelve la guardada', () async {
      late http.Request sent;
      final saved = await _repository((request) async {
        sent = request;
        return _json(200, {'city': 'Bogotá', 'latitude': null});
      }).updateCoverageZone(const CoverageZoneUpdate(city: 'Bogotá'));

      expect(sent.method, 'PUT');
      expect(jsonDecode(sent.body), {
        'city': 'Bogotá',
        'latitude': null,
        'longitude': null,
        'radiusKm': null,
      });
      expect(saved.city, 'Bogotá');
      expect(saved.hasCircle, isFalse);
    });

    test('si al guardar no vuelve la ciudad, es un error genérico', () async {
      await expectLater(
        _repository((_) async => _json(200, {'city': null}))
            .updateCoverageZone(const CoverageZoneUpdate(city: 'Bogotá')),
        throwsA(_failure(
          message: HttpTechnicianAvailabilityRepository.unexpectedErrorMessage,
        )),
      );
    });

    test('retira la zona (204)', () async {
      late http.Request sent;
      await _repository((request) async {
        sent = request;
        return http.Response('', 204);
      }).clearCoverageZone();

      expect(sent.method, 'DELETE');
      expect(sent.url.toString(), _zone);
    });

    test('si retirar falla, se informa', () async {
      await expectLater(
        _repository((_) async => _json(404, {})).clearCoverageZone(),
        throwsA(_failure(
          message: HttpTechnicianAvailabilityRepository.notFoundMessage,
        )),
      );
    });

    test('respuesta que no es objeto es un error genérico', () async {
      await expectLater(
        _repository((_) async => _json(200, [])).fetchCoverageZone(),
        throwsA(_failure(
          message: HttpTechnicianAvailabilityRepository.unexpectedErrorMessage,
        )),
      );
    });
  });

  group('errores comunes', () {
    for (final (status, message) in [
      (403, HttpTechnicianAvailabilityRepository.forbiddenMessage),
      (404, HttpTechnicianAvailabilityRepository.notFoundMessage),
      (409, HttpTechnicianAvailabilityRepository.conflictMessage),
      (500, HttpTechnicianAvailabilityRepository.unexpectedErrorMessage),
    ]) {
      test('$status se traduce a un mensaje claro', () async {
        await expectLater(
          _repository((_) async => _json(status, {})).fetchCoverageZone(),
          throwsA(_failure(message: message)),
        );
      });
    }

    test('si la sesión no se puede renovar, la sesión expiró', () async {
      await expectLater(
        _repository((_) async => http.Response('', 401)).fetchAvailability(),
        throwsA(_failure(
          message: HttpTechnicianAvailabilityRepository.sessionExpiredMessage,
          isSessionExpired: true,
        )),
      );
    });

    test('sin red se pide revisar la conexión', () async {
      await expectLater(
        _repository((_) => throw http.ClientException('sin red'))
            .clearCoverageZone(),
        throwsA(_failure(
          message: HttpTechnicianAvailabilityRepository.connectionErrorMessage,
        )),
      );
    });
  });
}
