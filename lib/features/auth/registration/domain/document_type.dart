/// Tipos de documento que acepta ms-users (`DocumentType`).
enum DocumentType {
  cc('CC', 'Cédula de ciudadanía'),
  ce('CE', 'Cédula de extranjería'),
  passport('PASSPORT', 'Pasaporte');

  const DocumentType(this.apiValue, this.label);

  /// Valor exacto que espera el backend.
  final String apiValue;

  /// Texto que ve el usuario.
  final String label;
}
