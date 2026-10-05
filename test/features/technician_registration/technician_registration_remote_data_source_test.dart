import 'dart:convert';

import 'package:ms_frontend/features/technician_registration/data/datasources/technician_registration_remote_data_source.dart';
import 'package:ms_frontend/features/technician_registration/domain/entities/technician_registration.dart';
import 'package:ms_frontend/features/technician_registration/domain/usecases/register_technician.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'envía datos requeridos, consentimiento y versión a la ruta de técnicos',
    () async {
      late Map<String, dynamic> requestBody;
      final client = MockClient((request) async {
        expect(request.url.path, '/api/users/technicians');
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('', 201);
      });
      final dataSource = TechnicianRegistrationRemoteDataSource(
        client: client,
        baseUrl: Uri.parse('https://api.fixia.test'),
      );

      await dataSource.register(
        TechnicianRegistration(
          firstName: ' Ana ',
          lastName: 'Pérez',
          documentType: TechnicianDocumentType.cc,
          documentNumber: '1020304050',
          email: 'ana@example.com',
          phone: '+573001112233',
          password: 'Clave1234',
          policyVersion: 'v1.0',
          consentAccepted: true,
          consentAcceptedAt: DateTime.utc(2026, 10, 5),
        ),
      );

      expect(requestBody['firstName'], 'Ana');
      expect(requestBody['role'], isNull);
      expect(requestBody['policyVersion'], 'v1.0');
      expect(requestBody['consentAccepted'], isTrue);
      expect(requestBody.containsKey('consentAcceptedAt'), isFalse);
    },
  );

  test('informa si la cuenta ya existe', () async {
    final client = MockClient((_) async => http.Response('', 409));
    final dataSource = TechnicianRegistrationRemoteDataSource(
      client: client,
      baseUrl: Uri.parse('https://api.fixia.test'),
    );

    await expectLater(
      dataSource.register(
        TechnicianRegistration(
          firstName: 'Ana',
          lastName: 'Pérez',
          documentType: TechnicianDocumentType.cc,
          documentNumber: '1020304050',
          email: 'ana@example.com',
          phone: '+573001112233',
          password: 'Clave1234',
          policyVersion: 'v1.0',
          consentAccepted: true,
          consentAcceptedAt: DateTime.utc(2026, 10, 5),
        ),
      ),
      throwsA(
        isA<TechnicianRegistrationFailure>().having(
          (failure) => failure.message,
          'message',
          'Ya existe una cuenta con ese correo o documento.',
        ),
      ),
    );
  });
}
