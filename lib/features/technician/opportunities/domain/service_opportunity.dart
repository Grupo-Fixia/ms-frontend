import '../../../../core/constants/service_category.dart';

class ServiceOpportunity {
  const ServiceOpportunity({
    required this.id,
    required this.title,
    required this.category,
    required this.postedLabel,
    required this.budget,
    required this.approximateLocation,
    required this.description,
    required this.expectedMoment,
  });

  final String id;
  final String title;
  final ServiceCategory category;
  final String postedLabel;
  final String budget;
  final String approximateLocation;
  final String description;
  final String expectedMoment;
}
