import '../../../../core/constants/service_category.dart';

class ServiceRequestDraft {
  const ServiceRequestDraft({
    required this.category,
    required this.description,
    required this.expectedAt,
    required this.photoCount,
  });

  final ServiceCategory category;
  final String description;
  final DateTime expectedAt;
  final int photoCount;
}
