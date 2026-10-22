import 'document_type.dart';

/// Datos para crear una cuenta en Fixia. Son los mismos para cliente
/// (GC-234, RF-001) y técnico (GC-235, RF-002).
class AccountRegistration {
  const AccountRegistration({
    required this.firstName,
    required this.lastName,
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
  final DocumentType documentType;
  final String documentNumber;
  final String email;
  final String phone;
  final String password;
  final String policyVersion;
  final bool consentAccepted;
  final DateTime? consentAcceptedAt;

  /// Campos obligatorios vacíos, con el nombre que usa el backend.
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

  /// Nunca expone la contraseña (ni datos personales) en logs.
  @override
  String toString() => 'AccountRegistration';
}
