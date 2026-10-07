/// Rol de la cuenta (`role` de `GET /api/users/me`).
enum UserRole {
  client('Cliente'),
  professional('Técnico'),
  admin('Administrador');

  const UserRole(this.label);

  final String label;

  /// Valor del enum `Role` de ms-users (`CLIENT`, `PROFESSIONAL`, `ADMIN`).
  /// Devuelve `null` si el backend envía un rol que el frontend no conoce.
  static UserRole? fromApi(String? value) {
    for (final role in values) {
      if (role.name.toUpperCase() == value) return role;
    }
    return null;
  }
}

/// Datos de la cuenta autenticada (`GET /api/users/me`).
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final UserRole? role;

  String get fullName => '$firstName $lastName'.trim();
}
