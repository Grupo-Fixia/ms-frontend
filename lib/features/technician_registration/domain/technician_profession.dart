/// Profesiones provisionales disponibles en el formulario de técnico.
enum TechnicianProfession {
  electrician('Electricidad'),
  plumber('Plomería'),
  carpenter('Carpintería'),
  painter('Pintura'),
  locksmith('Cerrajería'),
  mason('Albañilería'),
  refrigerationTechnician('Refrigeración y aire acondicionado'),
  gardener('Jardinería');

  const TechnicianProfession(this.label);

  final String label;
}
