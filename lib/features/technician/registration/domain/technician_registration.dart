import '../../../../core/models/document_type.dart';
import 'technician_profession.dart';

/// Datos capturados localmente por el formulario de registro de técnico.
class TechnicianRegistration {
  const TechnicianRegistration({
    required this.firstName,
    required this.lastName,
    required this.profession,
    required this.documentType,
    required this.documentNumber,
    required this.email,
    required this.phone,
    required this.password,
    required this.policyVersion,
    required this.consentAccepted,
    required this.consentAcceptedAt,
  });

  final String firstName;
  final String lastName;
  final TechnicianProfession profession;
  final DocumentType documentType;
  final String documentNumber;
  final String email;
  final String phone;
  final String password;
  final String policyVersion;
  final bool consentAccepted;
  final DateTime? consentAcceptedAt;

  List<String> get missingRequiredFields => [
        if (firstName.trim().isEmpty) 'firstName',
        if (lastName.trim().isEmpty) 'lastName',
        if (documentNumber.trim().isEmpty) 'documentNumber',
        if (email.trim().isEmpty) 'email',
        if (phone.trim().isEmpty) 'phone',
        if (password.isEmpty) 'password',
        if (policyVersion.trim().isEmpty) 'policyVersion',
        if (!consentAccepted || consentAcceptedAt == null) 'consentAccepted',
      ];

  @override
  String toString() => 'TechnicianRegistration';
}
