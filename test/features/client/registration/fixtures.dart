import 'package:ms_frontend/features/client/registration/domain/client_registration.dart';
import 'package:ms_frontend/core/models/document_type.dart';

ClientRegistration validRegistration({
  String firstName = 'Ana',
  String lastName = 'Pérez',
  String documentNumber = '1020304050',
  String email = 'ana@fixia.com',
  String phone = '3001234567',
  String password = 'Segura123',
  String policyVersion = 'v1.0',
  bool consentAccepted = true,
  DateTime? consentAcceptedAt,
  bool withoutConsentDate = false,
}) {
  return ClientRegistration(
    firstName: firstName,
    lastName: lastName,
    documentType: DocumentType.cc,
    documentNumber: documentNumber,
    email: email,
    phone: phone,
    password: password,
    policyVersion: policyVersion,
    consentAccepted: consentAccepted,
    consentAcceptedAt: withoutConsentDate
        ? null
        : consentAcceptedAt ?? DateTime(2026, 10, 6, 12),
  );
}
