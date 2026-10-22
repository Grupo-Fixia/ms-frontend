import '../../../../core/constants/service_category.dart';
import '../../../../core/constants/verification_status.dart';

/// Reseña que otro cliente dejó al prestador.
class ProviderReview {
  const ProviderReview({
    required this.authorName,
    required this.rating,
    required this.comment,
    required this.dateLabel,
  });

  final String authorName;

  /// De 1 a 5.
  final int rating;
  final String comment;
  final String dateLabel;
}

/// Trabajo ya realizado por el prestador en Fixia.
class CompletedJob {
  const CompletedJob({
    required this.title,
    required this.category,
    required this.dateLabel,
  });

  final String title;
  final ServiceCategory category;
  final String dateLabel;
}

/// Ficha pública del prestador que ve el cliente (GC-350, RF-016).
///
/// Solo trae la zona aproximada: la ubicación exacta del prestador no se
/// comparte (RNF-014).
class ProviderPublicProfile {
  const ProviderPublicProfile({
    required this.providerId,
    required this.displayName,
    required this.approximateZone,
    this.isCompany = false,
    this.photoUrl,
    this.verificationStatus,
    this.verifiedCategories = const {},
    this.description,
    this.yearsOfExperience,
    this.averageRating,
    this.ratingCount = 0,
    this.completedJobs = const [],
    this.reviews = const [],
  });

  final String providerId;
  final String displayName;
  final String approximateZone;

  /// `true` si el prestador es una empresa y no un técnico independiente.
  final bool isCompany;
  final String? photoUrl;

  /// `null` si el backend envía un estado que el frontend no conoce.
  final VerificationStatus? verificationStatus;

  /// Especialidades que Fixia ya verificó.
  final Set<ServiceCategory> verifiedCategories;
  final String? description;
  final int? yearsOfExperience;

  /// `null` mientras no tenga reseñas.
  final double? averageRating;
  final int ratingCount;
  final List<CompletedJob> completedJobs;
  final List<ProviderReview> reviews;

  bool get isVerified => verificationStatus == VerificationStatus.valid;

  /// Iniciales para el avatar cuando no hay foto.
  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }
}
