/// Categorías de servicio de Fixia, las mismas que acepta ms-users
/// (`ServiceCategory`, DD V2). Las usan la página de inicio y el perfil
/// profesional del técnico.
enum ServiceCategory {
  plumbing('PLUMBING', 'Plomería'),
  electrical('ELECTRICAL', 'Electricidad'),
  maintenance('MAINTENANCE', 'Mantenimiento'),
  locksmithing('LOCKSMITHING', 'Cerrajería'),
  painting('PAINTING', 'Pintura'),
  carpentry('CARPENTRY', 'Carpintería');

  const ServiceCategory(this.apiValue, this.label);

  /// Valor exacto que espera el backend.
  final String apiValue;

  /// Texto que ve el usuario.
  final String label;
}
