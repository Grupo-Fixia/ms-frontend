enum TechnicianDocumentType {
  cc('CC', 'Cédula de ciudadanía'),
  ce('CE', 'Cédula de extranjería'),
  passport('PASSPORT', 'Pasaporte');

  const TechnicianDocumentType(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

enum TechnicianRole { professional }

class TechnicianRegistration {
  const TechnicianRegistration({
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
  final TechnicianDocumentType documentType;
  final String documentNumber;
  final String email;
  final String phone;
  final String password;
  final String policyVersion;
  final bool consentAccepted;
  final DateTime? consentAcceptedAt;

  TechnicianRole get role => TechnicianRole.professional;

  List<String> get missingRequiredFields {
    final missing = <String>[];
    if (firstName.trim().isEmpty) missing.add('firstName');
    if (lastName.trim().isEmpty) missing.add('lastName');
    if (documentNumber.trim().isEmpty) missing.add('documentNumber');
    if (email.trim().isEmpty) missing.add('email');
    if (phone.trim().isEmpty) missing.add('phone');
    if (password.isEmpty) missing.add('password');
    if (policyVersion.trim().isEmpty) missing.add('policyVersion');
    if (!consentAccepted || consentAcceptedAt == null) {
      missing.add('consentAccepted');
    }
    return missing;
  }

  @override
  String toString() => 'TechnicianRegistration';
}
