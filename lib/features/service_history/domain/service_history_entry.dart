import '../../../core/constants/service_category.dart';
import '../../../core/constants/service_request_status.dart';
import '../../../core/domain/service_budget.dart';

export '../../../core/constants/service_request_status.dart';

/// Cómo participó en el servicio quien consulta su historial.
enum HistoryRole {
  client('CLIENT', 'Como cliente'),
  professional('PROFESSIONAL', 'Como técnico');

  const HistoryRole(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static HistoryRole? fromApi(String? value) {
    for (final role in values) {
      if (role.apiValue == value) return role;
    }
    return null;
  }
}

/// Etapa del servicio para distinguir el historial (GC-414, criterio 3).
///
/// - **Activo:** contratado o en ejecución.
/// - **Finalizado:** el técnico declaró el trabajo terminado y falta la
///   confirmación del cliente.
/// - **Cerrado:** el cliente confirmó el cierre.
///
/// Un estado que no es ninguno de los anteriores (cancelado, vencido o uno
/// que el frontend no conoce) queda en [other]: se muestra, sin forzarlo a
/// una etapa que no le corresponde.
enum HistoryStage {
  active('Activos'),
  finished('Finalizados'),
  closed('Cerrados'),
  other('Otros');

  const HistoryStage(this.label);

  final String label;

  static HistoryStage of(ServiceRequestStatus? status) => switch (status) {
        ServiceRequestStatus.contracted ||
        ServiceRequestStatus.inProgress =>
          active,
        ServiceRequestStatus.technicianFinished => finished,
        ServiceRequestStatus.closed => closed,
        _ => other,
      };
}

/// Un servicio contratado del historial propio (GC-448, `HistoryItem`). Es un
/// resumen: el detalle con condiciones e historial de cambios se pide aparte
/// por el contrato.
///
/// Las fechas del ciclo son `null` si el servicio no llegó a esa etapa o es
/// anterior al registro de transiciones; el frontend no las completa.
class ServiceHistoryEntry {
  const ServiceHistoryEntry({
    required this.serviceRequestId,
    required this.contractId,
    required this.role,
    required this.counterpartId,
    required this.category,
    required this.status,
    required this.contractedAmount,
    required this.agreedAt,
    required this.contractedAt,
    this.budget,
    this.startedAt,
    this.finishedAt,
    this.closedAt,
    this.lastTransitionAt,
  });

  /// Con este id el cliente pide el detalle del contrato.
  final String serviceRequestId;

  /// Con este id el técnico pide el detalle del contrato.
  final String contractId;
  final HistoryRole role;

  /// El técnico si quien consulta es cliente; el cliente si es técnico.
  final String counterpartId;
  final ServiceCategory? category;

  /// `null` si el backend envía un estado que el frontend no conoce.
  final ServiceRequestStatus? status;

  /// Importe acordado en la contratación.
  final ServiceBudget contractedAmount;

  /// Presupuesto orientativo del cliente; `null` en solicitudes anteriores.
  final ServiceBudget? budget;
  final DateTime agreedAt;
  final DateTime contractedAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime? closedAt;
  final DateTime? lastTransitionAt;

  HistoryStage get stage => HistoryStage.of(status);
}

/// Una página del historial: los servicios y el cursor de la siguiente
/// (`null` si no quedan más).
class ServiceHistoryResult {
  const ServiceHistoryResult({required this.items, this.nextCursor});

  final List<ServiceHistoryEntry> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}
