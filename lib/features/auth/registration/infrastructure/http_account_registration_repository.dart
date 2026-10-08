import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../application/ports/account_registration_repository.dart';
import '../domain/account_registration.dart';
import '../domain/registration_exceptions.dart';

/// Registra cuentas de cliente contra `POST /api/users/clients` de ms-users
/// (GC-253).
///
/// Contrato (ms-users `ClientRegistrationController`):
/// - `201 Created`: cuenta creada.
/// - `400`: ProblemDetail (RFC 7807) con `errors: [{field, message}]`.
/// - `409`: ya existe una cuenta con ese correo o documento.
class HttpAccountRegistrationRepository implements AccountRegistrationRepository {
  HttpAccountRegistrationRepository({
    required http.Client client,
    required Uri baseUrl,
    this.timeout = const Duration(seconds: 15),
  })  : _client = client,
        _endpoint = baseUrl.resolve('/api/users/clients');

  static const connectionErrorMessage =
      'No pudimos conectar con Fixia. Revisa tu conexión e inténtalo de nuevo.';
  static const conflictMessage =
      'Ya existe una cuenta con ese correo o número de documento. '
      'Si ya te registraste, inicia sesión.';
  static const conflictFieldMessage =
      'Ya existe una cuenta con este correo o documento.';
  static const invalidDataMessage = 'Revisa los datos marcados en el formulario.';
  static const unexpectedErrorMessage =
      'No pudimos crear tu cuenta en este momento. Inténtalo más tarde.';

  final http.Client _client;
  final Uri _endpoint;
  final Duration timeout;

  @override
  Future<void> register(AccountRegistration registration) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            _endpoint,
            headers: const {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json, application/problem+json',
            },
            body: jsonEncode(_toJson(registration)),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const RegistrationFailure(connectionErrorMessage);
    } on http.ClientException {
      throw const RegistrationFailure(connectionErrorMessage);
    }

    switch (response.statusCode) {
      case 200:
      case 201:
        return;
      case 400:
        throw _validationFailure(response);
      case 409:
        throw _conflictFailure(response);
      default:
        throw const RegistrationFailure(unexpectedErrorMessage);
    }
  }

  /// Cuerpo exacto que espera `ClientRegistrationRequest` en ms-users.
  /// La fecha del consentimiento la registra el backend al crear la cuenta.
  Map<String, Object> _toJson(AccountRegistration registration) => {
        'firstName': registration.firstName.trim(),
        'lastName': registration.lastName.trim(),
        'documentType': registration.documentType.apiValue,
        'documentNumber': registration.documentNumber.trim(),
        'email': registration.email.trim(),
        'phone': registration.phone.trim(),
        'password': registration.password,
        'policyVersion': registration.policyVersion,
        'consentAccepted': registration.consentAccepted,
      };

  /// Cuenta existente (409). Hoy ms-users no dice si se repite el correo o el
  /// documento, así que el aviso va en los dos campos. Si el backend llega a
  /// enviar `errors[{field, message}]`, se muestra solo en el campo indicado.
  RegistrationFailure _conflictFailure(http.Response response) {
    final fieldErrors = _fieldErrors(_decodeJson(response));
    return RegistrationFailure(
      conflictMessage,
      fieldErrors: fieldErrors.isNotEmpty
          ? fieldErrors
          : const {
              'email': conflictFieldMessage,
              'documentNumber': conflictFieldMessage,
            },
      isAccountConflict: true,
    );
  }

  /// Convierte el ProblemDetail del backend en errores por campo.
  RegistrationFailure _validationFailure(http.Response response) {
    final body = _decodeJson(response);
    final fieldErrors = _fieldErrors(body);
    final detail = body?['detail'];
    final message = fieldErrors.isNotEmpty
        ? invalidDataMessage
        : (detail is String && detail.trim().isNotEmpty
            ? detail.trim()
            : invalidDataMessage);
    return RegistrationFailure(message, fieldErrors: fieldErrors);
  }

  /// `errors[{field, message}]` del ProblemDetail; si un campo trae varios
  /// errores, se muestra el primero.
  Map<String, String> _fieldErrors(Map<String, dynamic>? body) {
    final fieldErrors = <String, String>{};
    final errors = body?['errors'];
    if (errors is List) {
      for (final error in errors) {
        if (error is! Map) continue;
        final field = error['field'];
        final message = error['message'];
        if (field is String && message is String && message.trim().isNotEmpty) {
          fieldErrors.putIfAbsent(field, () => message.trim());
        }
      }
    }
    return fieldErrors;
  }

  /// ms-users responde `application/problem+json` sin `charset`; se decodifica
  /// siempre como UTF-8 (RFC 8259) para que las tildes no lleguen dañadas
  /// (TD V1, DEF-02).
  Map<String, dynamic>? _decodeJson(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}
