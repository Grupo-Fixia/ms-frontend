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

/// Una página de oportunidades tal como la muestra la pantalla (GC-532).
/// [nextCursor] es `null` cuando no queda nada por revisar; una página puede
/// venir corta, o vacía, con cursor no nulo: hay que seguir pidiendo.
class ServiceOpportunityPage {
  const ServiceOpportunityPage({required this.items, this.nextCursor});

  final List<ServiceOpportunity> items;
  final String? nextCursor;
}
