import '../../../../core/constants/service_category.dart';
import 'opportunity.dart';

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

  /// Vista de una solicitud compatible real de ms-services. El backend no
  /// envía título ni presupuesto: el título es la categoría y el presupuesto
  /// queda "a convenir".
  factory ServiceOpportunity.fromOpportunity(
    Opportunity opportunity, {
    DateTime? now,
  }) {
    return ServiceOpportunity(
      id: opportunity.id,
      title: opportunity.category.label,
      category: opportunity.category,
      postedLabel: _postedLabel(opportunity.publishedAt, now ?? DateTime.now()),
      budget: 'A convenir',
      approximateLocation: '${opportunity.zone}, ${opportunity.city}',
      description: opportunity.description,
      expectedMoment: _formatMoment(opportunity.expectedAt),
    );
  }

  static String _postedLabel(DateTime? publishedAt, DateTime now) {
    if (publishedAt == null) return 'recientemente';
    final diff = now.difference(publishedAt);
    if (diff.inMinutes < 1) return 'hace un momento';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} d';
  }

  static String _formatMoment(DateTime moment) {
    final local = moment.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  final String id;
  final String title;
  final ServiceCategory category;
  final String postedLabel;
  final String budget;
  final String approximateLocation;
  final String description;
  final String expectedMoment;
}
