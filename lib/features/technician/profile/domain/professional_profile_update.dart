import '../../../../core/constants/service_category.dart';
import 'technician_profile_rules.dart';

/// Información profesional que registra o actualiza el técnico
/// (`TechnicianProfileRequest` de ms-users): reemplaza por completo la
/// anterior.
class ProfessionalProfileUpdate {
  const ProfessionalProfileUpdate({
    required this.professionalDescription,
    required this.yearsOfExperience,
    required this.categories,
  });

  final String professionalDescription;
  final int? yearsOfExperience;
  final Set<ServiceCategory> categories;

  /// Errores por campo, con el nombre que usa el backend. Vacío si es válida.
  Map<String, String> get validationErrors {
    final errors = <String, String>{};
    final description =
        TechnicianProfileRules.description(professionalDescription);
    if (description != null) errors['professionalDescription'] = description;
    final years = TechnicianProfileRules.yearsOfExperience(yearsOfExperience);
    if (years != null) errors['yearsOfExperience'] = years;
    final categories = TechnicianProfileRules.categories(this.categories);
    if (categories != null) errors['categories'] = categories;
    return errors;
  }
}
