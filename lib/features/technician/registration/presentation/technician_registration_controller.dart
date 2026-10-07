import 'package:flutter/foundation.dart';

import '../../../../core/constants/data_policy.dart';
import '../application/register_technician.dart';
import '../domain/technician_registration.dart';
import '../domain/technician_registration_exceptions.dart';
import '../domain/technician_profession.dart';
import '../../../../core/models/document_type.dart';

/// Estado de la pantalla de registro de técnico.
class TechnicianRegistrationController extends ChangeNotifier {
  TechnicianRegistrationController({
    required RegisterTechnician registerTechnician,
    DateTime Function()? clock,
  })  : _registerTechnician = registerTechnician,
        _clock = clock ?? DateTime.now;

  final RegisterTechnician _registerTechnician;
  final DateTime Function() _clock;

  bool _consentAccepted = false;
  DateTime? _consentAcceptedAt;
  bool _isSubmitting = false;
  bool _isRegistered = false;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};

  String get policyVersion => dataPolicyVersion;
  bool get consentAccepted => _consentAccepted;
  DateTime? get consentAcceptedAt => _consentAcceptedAt;
  bool get isSubmitting => _isSubmitting;
  bool get isRegistered => _isRegistered;
  String? get errorMessage => _errorMessage;
  bool get isLocked => _isSubmitting || _isRegistered;

  String? fieldError(String field) => _fieldErrors[field];

  void clearFieldError(String field) {
    if (!_fieldErrors.containsKey(field)) return;
    _fieldErrors = Map.of(_fieldErrors)..remove(field);
    notifyListeners();
  }

  void setConsentAccepted(bool accepted) {
    _consentAccepted = accepted;
    _consentAcceptedAt = accepted ? _clock() : null;
    notifyListeners();
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required TechnicianProfession? profession,
    required DocumentType? documentType,
    required String documentNumber,
    required String email,
    required String phone,
    required String password,
  }) async {
    if (isLocked) return;
    _isSubmitting = true;
    _errorMessage = null;
    _fieldErrors = const {};
    notifyListeners();

    try {
      if (documentType == null) {
        throw const InvalidTechnicianRegistrationException(['documentType']);
      }
      if (profession == null) {
        throw const InvalidTechnicianRegistrationException(['profession']);
      }
      await _registerTechnician(
        TechnicianRegistration(
          firstName: firstName.trim(),
          lastName: lastName.trim(),
          profession: profession,
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
    } on InvalidTechnicianRegistrationException {
      _errorMessage =
          'Completa los campos obligatorios y acepta el tratamiento de datos.';
    } on TechnicianRegistrationFailure catch (failure) {
      _errorMessage = failure.message;
      _fieldErrors = failure.fieldErrors;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
