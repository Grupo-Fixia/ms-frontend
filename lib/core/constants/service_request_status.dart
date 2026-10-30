/// Estado de una solicitud de servicio (`ServiceRequestStatus` de
/// ms-services). Lo usan las solicitudes del cliente y las postulaciones del
/// técnico.
enum ServiceRequestStatus {
  published('PUBLISHED', 'Publicada'),
  providerSelected('PROVIDER_SELECTED', 'Prestador seleccionado'),
  contracted('CONTRACTED', 'Contratada'),
  inProgress('IN_PROGRESS', 'En ejecución'),
  technicianFinished('TECHNICIAN_FINISHED', 'Finalizada por el técnico'),
  closed('CLOSED', 'Cerrada'),
  cancelled('CANCELLED', 'Cancelada'),
  expired('EXPIRED', 'Vencida');

  const ServiceRequestStatus(this.apiValue, this.label);

  /// Valor exacto que usa el backend.
  final String apiValue;

  /// Texto que ve el usuario.
  final String label;

  /// Ya no admite cambios (GC-441).
  bool get isTerminal => this == closed || this == cancelled || this == expired;

  /// Devuelve `null` si el backend envía un estado que el frontend no conoce.
  static ServiceRequestStatus? fromApi(String? value) {
    for (final status in values) {
      if (status.apiValue == value) return status;
    }
    return null;
  }
}
