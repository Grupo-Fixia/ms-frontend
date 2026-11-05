/// Chat simulado de un servicio contratado (extiende el prototipo GC-431).
///
/// Sigue siendo una simulación: no existe mensajería real en el backend
/// (RF-038 a RF-043 pendientes). Lo nuevo es que la conversación pertenece a
/// un servicio contratado y muestra a la contraparte y el servicio, para que
/// el equipo vea dónde vivirá el chat real.
library;

/// Quién usa el chat dentro del servicio.
enum ChatParticipant {
  client,
  technician;

  /// Cómo se nombra a la otra parte.
  String get counterpartLabel =>
      this == ChatParticipant.client ? 'tu técnico' : 'el cliente';

  /// "a tu técnico" / "al cliente".
  String get toCounterpart =>
      this == ChatParticipant.client ? 'a tu técnico' : 'al cliente';

  String get counterpartTitle =>
      this == ChatParticipant.client ? 'Técnico' : 'Cliente';

  /// Mensajes rápidos que suele mandar cada rol.
  List<String> get quickMessages => this == ChatParticipant.client
      ? const [
          '¿A qué hora llegas?',
          'Ya estoy en casa.',
          '¿Necesitas que compre algún material?',
          'Gracias, todo quedó bien.',
        ]
      : const [
          'Voy en camino.',
          'Llego en 15 minutos.',
          '¿Me confirmas la dirección?',
          'Ya terminé el trabajo.',
        ];

  /// Respuestas automáticas de la contraparte simulada. Son genéricas: no
  /// inventan precios, horarios, nombres ni cambios de estado.
  List<String> get simulatedReplies => this == ChatParticipant.client
      ? const [
          'Recibido, gracias por avisar.',
          'Perfecto, lo tengo en cuenta para el servicio.',
          'Listo. Cualquier novedad te escribo por aquí.',
        ]
      : const [
          'Hola, gracias por escribir.',
          'Perfecto, quedo atento.',
          'Listo, nos vemos en el servicio.',
        ];
}

/// Mensaje del chat de un servicio. Vive solo en memoria.
class ServiceChatMessage {
  const ServiceChatMessage({
    required this.mine,
    required this.text,
    required this.sentAt,
  });

  /// `true` si lo escribió quien usa la app; `false` si es la respuesta
  /// simulada de la contraparte.
  final bool mine;
  final String text;
  final DateTime sentAt;
}
