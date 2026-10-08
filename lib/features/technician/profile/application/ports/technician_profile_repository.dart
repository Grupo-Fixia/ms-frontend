import '../../domain/professional_profile_update.dart';
import '../../domain/technician_profile.dart';

/// Puerto de salida: perfil profesional del técnico autenticado (lo
/// implementa infraestructura, GC-264).
///
/// Ambos métodos lanzan `TechnicianProfileFailure` si el backend rechaza la
/// solicitud o no se puede contactar.
abstract interface class TechnicianProfileRepository {
  Future<TechnicianProfile> fetchProfile();

  /// Reemplaza la información profesional y devuelve el perfil guardado.
  Future<TechnicianProfile> updateProfile(ProfessionalProfileUpdate update);
}
