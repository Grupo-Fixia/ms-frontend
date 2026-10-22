/// Estado de una solicitud de servicio (`ServiceRequestStatus` de
/// ms-services). Lo usan las solicitudes del cliente y las postulaciones del
/// técnico.
enum ServiceRequestStatus {
  published('PUBLISHED', 'Publicada'),
  providerSelected('PROVIDER_SELECTED', 'Prestador seleccionado'),
  contracted('CONTRACTED', 'Contratada'),
  cancelled('CANCELLED', 'Cancelada'),
  expired('EXPIRED', 'Vencida');

  const ServiceRequestStatus(this.apiValue, this.label);

  /// Valor exacto que usa el backend.
  final String apiValue;

  /// Texto que ve el usuario.
  final String label;

  /// Devuelve `null` si el backend envía un estado que el frontend no conoce.
  static ServiceRequestStatus? fromApi(String? value) {
    for (final status in values) {
      if (status.apiValue == value) return status;
    }
    return null;
  }
}
