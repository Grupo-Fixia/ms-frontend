import '../../../../core/constants/application_status.dart';
import '../../../../core/constants/service_category.dart';
import '../../../../core/domain/service_budget.dart';
import '../../../technician/profile/domain/verification_status.dart';

export '../../../../core/constants/application_status.dart';
export '../../../technician/profile/domain/verification_status.dart';

/// Quién se postula: un técnico independiente o una empresa que propone a
/// uno de sus técnicos asociados (GC-468).
enum ProviderType {
  independent('INDEPENDENT', 'Independiente'),
  company('COMPANY', 'Empresa');

  const ProviderType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// Las postulaciones anteriores a GC-468 no traen el tipo: son de
  /// independientes.
  static ProviderType fromApi(String? value) =>
      value == company.apiValue ? company : independent;
}

/// Perfil público de un prestador tal como lo entrega ms-users (GC-425):
/// solo lo necesario para comparar, sin contacto ni ubicación exacta.
///
/// Cualquier campo puede venir en `null` si el técnico no ha llenado su
/// perfil; el frontend no los completa con valores inventados.
class ProviderPublicProfile {
  const ProviderPublicProfile({
    this.displayName,
    this.verificationStatus,
    this.categories = const [],
    this.professionalDescription,
    this.yearsOfExperience,
    this.city,
  });

  final String? displayName;
  final VerificationStatus? verificationStatus;
  final List<ServiceCategory> categories;
  final String? professionalDescription;
  final int? yearsOfExperience;
  final String? city;
}

/// Prestador postulado a una solicitud del cliente (GC-299, RF-016), tal
/// como lo ve el cliente dueño (GC-425, GC-468).
class Applicant {
  const Applicant({
    required this.id,
    required this.providerId,
    required this.status,
    this.providerType = ProviderType.independent,
    this.technicianId,
    this.proposedPrice,
    this.provider,
    this.executor,
    this.createdAt,
    this.updatedAt,
  });

  /// Identificador de la postulación (se usa para seleccionar al prestador).
  final String id;

  /// Identificador del prestador en ms-users (técnico o empresa).
  final String providerId;
  final ApplicationStatus status;
  final ProviderType providerType;

  /// Técnico propuesto por la empresa; `null` para independientes.
  final String? technicianId;

  /// Precio propuesto (GC-423). `null` en postulaciones anteriores a ese
  /// cambio.
  final ServiceBudget? proposedPrice;

  /// Perfil del independiente, o de la empresa (solo su nombre). `null` si
  /// el prestador ya no está activo.
  final ProviderPublicProfile? provider;

  /// Para una empresa, el técnico que haría el trabajo. `null` para
  /// independientes.
  final ProviderPublicProfile? executor;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isCompany => providerType == ProviderType.company;

  /// Nombre que ve el cliente, sin inventar uno si el perfil no llegó.
  String get displayName {
    final name = provider?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return isCompany ? 'Empresa no disponible' : 'Prestador no disponible';
  }

  /// Perfil de quien haría el trabajo: el técnico propuesto por la empresa o
  /// el propio independiente.
  ProviderPublicProfile? get workerProfile => isCompany ? executor : provider;
}
