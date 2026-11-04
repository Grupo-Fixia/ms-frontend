import '../domain/opportunity.dart';
import '../domain/service_opportunity.dart';

/// Convierte una solicitud compatible del backend (GC-340) en la tarjeta que
/// muestra la pantalla de oportunidades.
///
/// La solicitud tampoco trae título: se usa el inicio de la descripción.
ServiceOpportunity opportunityView(Opportunity opportunity, {DateTime? now}) {
  return ServiceOpportunity(
    id: opportunity.id,
    title: _title(opportunity.description),
    category: opportunity.category,
    postedLabel: _postedLabel(opportunity.publishedAt, now ?? DateTime.now()),
    budget: opportunity.budget?.label ?? 'Presupuesto no informado',
    approximateLocation: '${opportunity.zone}, ${opportunity.city}',
    description: opportunity.description,
    expectedMoment: _moment(opportunity.expectedAt.toLocal()),
  );
}

String _title(String description) {
  final text = description.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.length <= _titleMaxLength) return text;
  return '${text.substring(0, _titleMaxLength - 1).trimRight()}…';
}

const _titleMaxLength = 60;

String _postedLabel(DateTime? publishedAt, DateTime now) {
  if (publishedAt == null) return 'Recientemente';
  final elapsed = now.difference(publishedAt.toLocal());
  if (elapsed.inMinutes < 1) return 'Hace un momento';
  if (elapsed.inMinutes < 60) return 'Hace ${elapsed.inMinutes} min';
  if (elapsed.inHours < 24) {
    return elapsed.inHours == 1
        ? 'Hace 1 hora'
        : 'Hace ${elapsed.inHours} horas';
  }
  return elapsed.inDays == 1 ? 'Hace 1 día' : 'Hace ${elapsed.inDays} días';
}

String _moment(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} · '
      '${two(value.hour)}:${two(value.minute)}';
}
