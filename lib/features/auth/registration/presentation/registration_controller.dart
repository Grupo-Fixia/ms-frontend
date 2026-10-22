import 'package:flutter/foundation.dart';

import '../../../../core/constants/data_policy.dart';
import '../application/register_account.dart';
import '../domain/account_registration.dart';
import '../domain/registration_exceptions.dart';
import '../domain/document_type.dart';

/// Estado de la pantalla de registro (cliente o técnico).
class RegistrationController extends ChangeNotifier {
  RegistrationController({
    required RegisterAccount registerAccount,
    DateTime Function()? clock,
  })  : _registerAccount = registerAccount,
        _clock = clock ?? DateTime.now;

  final RegisterAccount _registerAccount;
  final DateTime Function() _clock;

  bool _consentAccepted = false;
  DateTime? _consentAcceptedAt;
  bool _isSubmitting = false;
  bool _isRegistered = false;
  String? _errorMessage;
  bool _isAccountConflict = false;
  Map<String, String> _fieldErrors = const {};

  String get policyVersion => dataPolicyVersion;
  bool get consentAccepted => _consentAccepted;
  DateTime? get consentAcceptedAt => _consentAcceptedAt;
  bool get isSubmitting => _isSubmitting;
  bool get isRegistered => _isRegistered;
  String? get errorMessage => _errorMessage;

  /// Ya existe una cuenta con ese correo o documento (409); el aviso va debajo
  /// del correo.
  bool get isAccountConflict => _isAccountConflict;

  /// El usuario cerró el aviso de error.
  void dismissError() {
    if (_errorMessage == null && !_isAccountConflict) return;
    _errorMessage = null;
    _isAccountConflict = false;
    notifyListeners();
  }

  /// Evita el doble envío y bloquea el formulario tras crear la cuenta.
  bool get isLocked => _isSubmitting || _isRegistered;

  /// Error que devolvió el backend para un campo (`email`, `phone`...).
  String? fieldError(String field) => _fieldErrors[field];

  /// El usuario editó el campo: se descarta el error que vino del backend.
  void clearFieldError(String field) {
    if (!_fieldErrors.containsKey(field)) return;
    _fieldErrors = Map.of(_fieldErrors)..remove(field);
    notifyListeners();
  }

  /// Registra la fecha en que se aceptó la política (RF-007).
  void setConsentAccepted(bool accepted) {
    _consentAccepted = accepted;
    _consentAcceptedAt = accepted ? _clock() : null;
    notifyListeners();
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required DocumentType? documentType,
    required String documentNumber,
    required String email,
    required String phone,
    required String password,
  }) async {
    if (isLocked) return;
    _isSubmitting = true;
    _errorMessage = null;
    _isAccountConflict = false;
    _fieldErrors = const {};
    notifyListeners();

    try {
      if (documentType == null) {
        throw const InvalidRegistrationException(['documentType']);
      }
      await _registerAccount(
        AccountRegistration(
          firstName: firstName.trim(),
          lastName: lastName.trim(),
          documentType: documentType,
          documentNumber: documentNumber.trim(),
          email: email.trim(),
          phone: phone.trim(),
          password: password,
          policyVersion: policyVersion,
          consentAccepted: _consentAccepted,
          consentAcceptedAt: _consentAcceptedAt,
        ),
      );
      _isRegistered = true;
    } on InvalidRegistrationException {
      _errorMessage =
          'Completa los campos obligatorios y acepta el tratamiento de datos.';
    } on RegistrationFailure catch (failure) {
      _errorMessage = failure.message;
      _fieldErrors = failure.fieldErrors;
      _isAccountConflict = failure.isAccountConflict;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
