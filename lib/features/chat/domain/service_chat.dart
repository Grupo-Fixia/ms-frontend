/// Chat real entre el cliente y el técnico que ejecuta un servicio contratado
/// (GC-528). Contrato: `ms-services/docs/contracts/mensajeria.md` (GC-527).
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
}

/// La conversación de un contrato. El cliente entra por su solicitud y el
/// técnico por el contrato: son dos puertas a la misma conversación (§2).
class ChatConversation {
  const ChatConversation({
    required this.participant,
    required this.contractId,
    required this.serviceRequestId,
  });

  final ChatParticipant participant;
  final String contractId;
  final String serviceRequestId;

  /// Segmentos de la ruta bajo `/api/services/`.
  List<String> get pathSegments => participant == ChatParticipant.client
      ? ['requests', serviceRequestId, 'messages']
      : ['contracts', contractId, 'messages'];
}

/// Estado de un mensaje propio mientras viaja.
enum ChatDelivery { sent, sending, failed }

/// Un mensaje de la conversación. Los del servidor son inmutables; los
/// propios aún sin confirmar no tienen [id].
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.body,
    required this.mine,
    required this.createdAt,
    this.clientMessageId,
    this.delivery = ChatDelivery.sent,
  });

  /// `null` mientras el servidor no lo confirma.
  final String? id;
  final String body;
  final bool mine;
  final DateTime createdAt;

  /// Identificador que pone la app al enviar; un reintento con el mismo no
  /// duplica el mensaje (D6).
  final String? clientMessageId;
  final ChatDelivery delivery;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final body = json['body'];
    final createdAt = DateTime.tryParse('${json['createdAt']}');
    if (id is! String || id.isEmpty || body is! String || createdAt == null) {
      throw const FormatException('Mensaje inválido');
    }
    final clientId = json['clientMessageId'];
    return ChatMessage(
      id: id,
      body: body,
      mine: json['mine'] == true,
      createdAt: createdAt,
      clientMessageId:
          clientId is String && clientId.isNotEmpty ? clientId : null,
    );
  }
}

/// Una lectura de `GET …/messages`.
class ChatMessagesPage {
  const ChatMessagesPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
    required this.open,
  });

  final List<ChatMessage> items;

  /// Posición del último mensaje entregado; se manda como `after`.
  final String? nextCursor;

  /// Ya hay más mensajes esperando: se pide otra página enseguida.
  final bool hasMore;

  /// El servicio todavía admite mensajes; si no, se oculta la caja de texto.
  final bool open;
}

class ChatFailure implements Exception {
  const ChatFailure(
    this.message, {
    this.isSessionExpired = false,
    this.isConnection = false,
    this.statusCode,
  });

  final String message;
  final bool isSessionExpired;

  /// Sin red, plazo vencido o servidor caído: se puede reintentar.
  final bool isConnection;
  final int? statusCode;

  /// 409 al enviar: la conversación ya no admite mensajes.
  bool get isClosed => statusCode == 409;

  @override
  String toString() => message;
}

abstract interface class ChatGateway {
  /// `wait` en segundos (0 a 25) activa el long polling (§2.3).
  Future<ChatMessagesPage> messages(
    ChatConversation conversation, {
    String? after,
    int wait = 0,
  });

  Future<ChatMessage> send(
    ChatConversation conversation, {
    required String body,
    required String clientMessageId,
  });
}

const maxChatMessageLength = 2000;

/// Texto válido para enviar: 1 a 2000 caracteres sin los espacios de los
/// extremos (§2.1). Devuelve el texto limpio o `null`.
String? cleanChatMessage(String text) {
  final body = text.trim();
  if (body.isEmpty || body.length > maxChatMessageLength) return null;
  return body;
}
