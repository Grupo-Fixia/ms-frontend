import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/technician_registration.dart';
import '../../domain/usecases/register_technician.dart';

class TechnicianRegistrationRemoteDataSource {
  TechnicianRegistrationRemoteDataSource({
    required http.Client client,
    required Uri baseUrl,
  }) : _client = client,
       _registrationUri = baseUrl.resolve('/api/users/technicians');

  final http.Client _client;
  final Uri _registrationUri;

  Future<void> register(TechnicianRegistration registration) async {
    late final http.Response response;
    try {
      response = await _client.post(
        _registrationUri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firstName': registration.firstName.trim(),
          'lastName': registration.lastName.trim(),
          'documentType': registration.documentType.apiValue,
          'documentNumber': registration.documentNumber.trim(),
          'email': registration.email.trim(),
          'phone': registration.phone.trim(),
          'password': registration.password,
          'policyVersion': registration.policyVersion,
          'consentAccepted': registration.consentAccepted,
        }),
      );
    } on Exception {
      throw const TechnicianRegistrationFailure(
        'No fue posible conectar con el servicio. Inténtalo de nuevo.',
      );
    }

    if (response.statusCode == 201) return;
    if (response.statusCode == 409) {
      throw const TechnicianRegistrationFailure(
        'Ya existe una cuenta con ese correo o documento.',
      );
    }
    if (response.statusCode == 400) {
      throw const TechnicianRegistrationFailure(
        'Revisa los datos ingresados y vuelve a intentarlo.',
      );
    }
    throw const TechnicianRegistrationFailure(
      'No fue posible crear la cuenta. Inténtalo más tarde.',
    );
  }
}
