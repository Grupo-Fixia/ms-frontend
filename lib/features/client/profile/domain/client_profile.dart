/// Datos de la cuenta del cliente (GC-293, RF-008) tal como los devuelve
/// ms-users. El correo y el documento son de solo lectura.
class ClientProfile {
  const ClientProfile({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.documentType,
    this.documentNumber,
    this.createdAt,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String phone;

  /// Código del backend (`CC`, `CE`, `PASSPORT`).
  final String? documentType;
  final String? documentNumber;
  final DateTime? createdAt;

  String get fullName => '$firstName $lastName'.trim();
}
