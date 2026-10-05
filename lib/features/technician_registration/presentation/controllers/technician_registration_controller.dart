import 'package:flutter/foundation.dart';

import '../../domain/entities/technician_registration.dart';
import '../../domain/usecases/register_technician.dart';

class TechnicianRegistrationController extends ChangeNotifier {
  TechnicianRegistrationController({
    required RegisterTechnician registerTechnician,
    DateTime Function()? now,
  }) : _registerTechnician = registerTechnician,
       _now = now ?? DateTime.now;

  static const policyVersion = String.fromEnvironment(
    'DATA_POLICY_VERSION',
    defaultValue: 'v1.0',
  );

  final RegisterTechnician _registerTechnician;
  final DateTime Function() _now;

  bool _consentAccepted = false;
  DateTime? _consentAcceptedAt;
  bool _isSubmitting = false;
  bool _isRegistered = false;
  String? _errorMessage;

  bool get consentAccepted => _consentAccepted;
  DateTime? get consentAcceptedAt => _consentAcceptedAt;
  bool get isSubmitting => _isSubmitting;
  bool get isRegistered => _isRegistered;
  String? get errorMessage => _errorMessage;

  void setConsentAccepted(bool accepted) {
    _consentAccepted = accepted;
    _consentAcceptedAt = accepted ? _now() : null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required TechnicianDocumentType? documentType,
    required String documentNumber,
    required String email,
    required String phone,
    required String password,
  }) async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (documentType == null) {
        throw const InvalidTechnicianRegistrationException(['documentType']);
      }
      await _registerTechnician(
        TechnicianRegistration(
          firstName: firstName,
          lastName: lastName,
          documentType: documentType,
          documentNumber: documentNumber,
          email: email,
          phone: phone,
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
    } on TechnicianRegistrationFailure catch (error) {
      _errorMessage = error.message;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
