/// Categorías de perfil sugeridas por QA para el formulario de técnico.
enum TechnicianProfession {
  plumbing('Plomería', 'PLUMBING'),
  electrical('Electricidad', 'ELECTRICAL'),
  maintenance('Mantenimiento general', 'MAINTENANCE'),
  locksmithing('Cerrajería', 'LOCKSMITHING'),
  painting('Pintura', 'PAINTING'),
  carpentry('Carpintería', 'CARPENTRY');

  const TechnicianProfession(this.label, this.categoryCode);

  final String label;
  final String categoryCode;
}
