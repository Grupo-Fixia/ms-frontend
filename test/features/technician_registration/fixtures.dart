import 'package:ms_frontend/features/client/registration/domain/document_type.dart';
import 'package:ms_frontend/features/technician_registration/domain/technician_registration.dart';
import 'package:ms_frontend/features/technician_registration/domain/technician_profession.dart';

TechnicianRegistration validTechnicianRegistration({
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
  return TechnicianRegistration(
    firstName: firstName,
    lastName: lastName,
    profession: TechnicianProfession.electrician,
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
