import '../../../../core/constants/service_category.dart';
import '../../../../core/domain/service_budget.dart';

class ServiceRequestDraft {
  const ServiceRequestDraft({
    required this.category,
    required this.description,
    required this.expectedAt,
    required this.photoCount,
    this.city = '',
    this.zone = '',
    this.budget,
  });

  final ServiceCategory category;
  final String description;
  final DateTime expectedAt;
  final int photoCount;
  final ServiceBudget? budget;

  /// Ubicación aproximada que se comparte con los técnicos (GC-335).
  final String city;
  final String zone;
}
