import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/features/technician/profile/domain/professional_profile_update.dart';
import 'package:ms_frontend/features/technician/profile/domain/technician_profile_exceptions.dart';
import 'package:ms_frontend/features/technician/profile/domain/verification_status.dart';
import 'package:ms_frontend/features/technician/profile/infrastructure/http_technician_profile_repository.dart';

const _endpoint = 'http://localhost/api/users/technicians/me/profile';

/// Respuesta como la de ms-users: JSON en UTF-8 sin charset en el header.
http.Response _json(int status, Object body, {String type = 'json'}) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/$type'},
    );

Map<String, Object?> _profileJson({
  String status = 'PENDING',
  String? description,
  int? years,
  List<String> categories = const [],
}) =>
    {
      'technicianId': 'tec-1',
      'verificationStatus': status,
      'professionalDescription': description,
      'yearsOfExperience': years,
      'categories': categories,
      'updatedAt': '2026-10-08T15:30:00Z',
    };

const _update = ProfessionalProfileUpdate(
  professionalDescription: '  Plomero con experiencia  ',
  yearsOfExperience: 8,
  categories: {ServiceCategory.electrical, ServiceCategory.plumbing},
);

class _Session {
  _Session({this.token = 'token-1', this.renewTo, this.canRenew = true});

  String? token;
  final String? renewTo;
  final bool canRenew;
  int renewCalls = 0;

  Future<bool> renew() async {
    renewCalls++;
    if (!canRenew) return false;
    token = renewTo;
    return true;
  }
}

HttpTechnicianProfileRepository _repository(
  MockClientHandler handler,
  _Session session, {
  Duration timeout = const Duration(seconds: 15),
}) =>
    HttpTechnicianProfileRepository(
      client: MockClient(handler),
      baseUrl: Uri.parse('http://localhost'),
      accessToken: () => session.token,
      renewSession: session.renew,
      timeout: timeout,
    );

Matcher _failure({
  String? message,
  Map<String, String>? fieldErrors,
  bool? isSessionExpired,
}) {
  var matcher = isA<TechnicianProfileFailure>();
  if (message != null) {
    matcher = matcher.having((f) => f.message, 'message', message);
  }
  if (fieldErrors != null) {
    matcher = matcher.having((f) => f.fieldErrors, 'fieldErrors', fieldErrors);
  }
  if (isSessionExpired != null) {
    matcher = matcher.having(
      (f) => f.isSessionExpired,
      'isSessionExpired',
      isSessionExpired,
    );
  }
  return matcher;
}

void main() {
  group('consultar (GET)', () {
    test('envía el token y convierte el perfil vacío de un técnico nuevo',
        () async {
      late http.Request sent;
      final repository = _repository((request) async {
        sent = request;
        return _json(200, _profileJson());
      }, _Session());

      final profile = await repository.fetchProfile();

      expect(sent.method, 'GET');
      expect(sent.url.toString(), _endpoint);
      expect(sent.headers['Authorization'], 'Bearer token-1');
      expect(profile.technicianId, 'tec-1');
      expect(profile.verificationStatus, VerificationStatus.pending);
      expect(profile.isComplete, isFalse);
      expect(profile.categories, isEmpty);
    });

    test('convierte un perfil completo, con tildes en UTF-8', () async {
      final repository = _repository(
        (_) async => _json(
          200,
          _profileJson(
            status: 'VALID',
            description: 'Electricista con certificación',
            years: 12,
            categories: ['ELECTRICAL', 'MAINTENANCE', 'DESCONOCIDA'],
          ),
        ),
        _Session(),
      );

      final profile = await repository.fetchProfile();

      expect(profile.isComplete, isTrue);
      expect(profile.verificationStatus, VerificationStatus.valid);
      expect(profile.professionalDescription, 'Electricista con certificación');
      expect(profile.yearsOfExperience, 12);
      // Las categorías que el frontend no conoce se ignoran.
      expect(profile.categories, {
        ServiceCategory.electrical,
        ServiceCategory.maintenance,
      });
      expect(profile.updatedAt, DateTime.utc(2026, 10, 8, 15, 30));
    });

    test('una respuesta sin id de técnico es un error', () async {
      final repository = _repository(
        (_) async => _json(200, {'verificationStatus': 'PENDING'}),
        _Session(),
      );

      await expectLater(
        repository.fetchProfile(),
        throwsA(
          _failure(
            message: HttpTechnicianProfileRepository.unexpectedErrorMessage,
          ),
        ),
      );
    });

    test('una respuesta que no es JSON es un error', () async {
      final repository = _repository(
        (_) async => http.Response('<html>', 200),
        _Session(),
      );

      await expectLater(
        repository.fetchProfile(),
        throwsA(
          _failure(
            message: HttpTechnicianProfileRepository.unexpectedErrorMessage,
          ),
        ),
      );
    });

    test('403: la cuenta no es de técnico', () async {
      final repository = _repository(
        (_) async => _json(403, {'status': 403}, type: 'problem+json'),
        _Session(),
      );

      await expectLater(
        repository.fetchProfile(),
        throwsA(
          _failure(message: HttpTechnicianProfileRepository.forbiddenMessage),
        ),
      );
    });

    test('404: la cuenta no tiene perfil de técnico', () async {
      final repository = _repository(
        (_) async => _json(404, {'status': 404}, type: 'problem+json'),
        _Session(),
      );

      await expectLater(
        repository.fetchProfile(),
        throwsA(
          _failure(message: HttpTechnicianProfileRepository.notFoundMessage),
        ),
      );
    });

    test('otro código es un error inesperado', () async {
      final repository = _repository(
        (_) async => http.Response('', 500),
        _Session(),
      );

      await expectLater(
        repository.fetchProfile(),
        throwsA(
          _failure(
            message: HttpTechnicianProfileRepository.unexpectedErrorMessage,
          ),
        ),
      );
    });
  });

  group('guardar (PUT)', () {
    test('envía el contrato de ms-users y devuelve el perfil guardado',
        () async {
      late http.Request sent;
      final repository = _repository((request) async {
        sent = request;
        return _json(
          200,
          _profileJson(
            description: 'Plomero con experiencia',
            years: 8,
            categories: ['PLUMBING', 'ELECTRICAL'],
          ),
        );
      }, _Session());

      final saved = await repository.updateProfile(_update);

      expect(sent.method, 'PUT');
      expect(sent.url.toString(), _endpoint);
      expect(sent.headers['Authorization'], 'Bearer token-1');
      expect(sent.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(sent.body), {
        'professionalDescription': 'Plomero con experiencia',
        'yearsOfExperience': 8,
        'categories': ['PLUMBING', 'ELECTRICAL'],
      });
      expect(saved.isComplete, isTrue);
    });

    test('400: errores por campo (categories[0] se muestra en categorías)',
        () async {
      final repository = _repository(
        (_) async => _json(
          400,
          {
            'status': 400,
            'errors': [
              {
                'field': 'yearsOfExperience',
                'message': 'Los años de experiencia no pueden superar 80',
              },
              {
                'field': 'categories[0]',
                'message': 'La categoría no es válida',
              },
              {'field': 'yearsOfExperience', 'message': 'Otro error'},
            ],
          },
          type: 'problem+json',
        ),
        _Session(),
      );

      await expectLater(
        repository.updateProfile(_update),
        throwsA(
          _failure(
            message: HttpTechnicianProfileRepository.invalidDataMessage,
            fieldErrors: {
              'yearsOfExperience':
                  'Los años de experiencia no pueden superar 80',
              'categories': 'La categoría no es válida',
            },
          ),
        ),
      );
    });
  });

  group('sesión', () {
    test('con el token vencido renueva la sesión y reintenta', () async {
      final tokens = <String?>[];
      final session = _Session(renewTo: 'token-2');
      final repository = _repository((request) async {
        tokens.add(request.headers['Authorization']);
        return tokens.length == 1
            ? _json(401, {'status': 401}, type: 'problem+json')
            : _json(200, _profileJson());
      }, session);

      await repository.fetchProfile();

      expect(session.renewCalls, 1);
      expect(tokens, ['Bearer token-1', 'Bearer token-2']);
    });

    test('si no se puede renovar, la sesión expiró', () async {
      final session = _Session(canRenew: false);
      final repository = _repository(
        (_) async => _json(401, {'status': 401}, type: 'problem+json'),
        session,
      );

      await expectLater(
        repository.fetchProfile(),
        throwsA(
          _failure(
            message: HttpTechnicianProfileRepository.sessionExpiredMessage,
            isSessionExpired: true,
          ),
        ),
      );
    });

    test('si tras renovar sigue en 401, la sesión expiró (sin bucles)',
        () async {
      var calls = 0;
      final session = _Session(renewTo: 'token-2');
      final repository = _repository((_) async {
        calls++;
        return _json(401, {'status': 401}, type: 'problem+json');
      }, session);

      await expectLater(
        repository.updateProfile(_update),
        throwsA(_failure(isSessionExpired: true)),
      );
      expect(calls, 2);
      expect(session.renewCalls, 1);
    });

    test('sin sesión no llama al backend', () async {
      var calls = 0;
      final repository = _repository((_) async {
        calls++;
        return _json(200, _profileJson());
      }, _Session(token: null));

      await expectLater(
        repository.fetchProfile(),
        throwsA(_failure(isSessionExpired: true)),
      );
      expect(calls, 0);
    });
  });

  group('red', () {
    test('sin conexión', () async {
      final repository = _repository(
        (_) async => throw http.ClientException('sin red'),
        _Session(),
      );

      await expectLater(
        repository.fetchProfile(),
        throwsA(
          _failure(
            message: HttpTechnicianProfileRepository.connectionErrorMessage,
          ),
        ),
      );
    });

    test('el backend no responde a tiempo', () async {
      final repository = _repository(
        (_) => Completer<http.Response>().future,
        _Session(),
        timeout: const Duration(milliseconds: 10),
      );

      await expectLater(
        repository.updateProfile(_update),
        throwsA(
          _failure(
            message: HttpTechnicianProfileRepository.connectionErrorMessage,
          ),
        ),
      );
    });
  });

  test('ServiceCategory.fromApi convierte los valores de ms-users', () {
    for (final category in ServiceCategory.values) {
      expect(ServiceCategory.fromApi(category.apiValue), category);
    }
    expect(ServiceCategory.fromApi('OTRA'), isNull);
    expect(ServiceCategory.fromApi(null), isNull);
  });
}
