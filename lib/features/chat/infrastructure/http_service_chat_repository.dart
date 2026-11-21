import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/http/authorized_http.dart';
import '../domain/service_chat.dart';

/// Chat por servicio de ms-services (GC-527):
/// - Cliente: `GET|POST /api/services/requests/{serviceRequestId}/messages`.
/// - Técnico: `GET|POST /api/services/contracts/{contractId}/messages`.
class HttpServiceChatRepository implements ChatGateway {
  HttpServiceChatRepository({
    required http.Client client,
    required Uri baseUrl,
    required AuthorizedHttp authorizedHttp,
  })  : _client = client,
        _base = baseUrl.resolve('/api/services/'),
        _http = authorizedHttp;

  static const connectionErrorMessage =
      'No pudimos conectar con Fixia. Revisa tu conexión.';
  static const sessionExpiredMessage =
      'Tu sesión expiró. Inicia sesión de nuevo.';
  static const unavailableMessage =
      'El chat no está disponible en este momento. Inténtalo más tarde.';
  static const notFoundMessage =
      'No encontramos esta conversación o ya no tienes acceso a ella.';
  static const closedMessage =
      'La conversación está cerrada: ya no se pueden enviar mensajes.';

  /// La espera del servidor (hasta 25 s) más margen para la red.
  static const longPollTimeout = Duration(seconds: 35);

  final http.Client _client;
  final Uri _base;
  final AuthorizedHttp _http;

  @override
  Future<ChatMessagesPage> messages(
    ChatConversation conversation, {
    String? after,
    int wait = 0,
  }) async {
    final uri = _uri(conversation).replace(queryParameters: {
      if (after != null) 'after': after,
      if (wait > 0) 'wait': '${wait.clamp(0, 25)}',
    });
    final response = await _send(
      (headers) => _client.get(uri, headers: headers),
      timeout: wait > 0 ? longPollTimeout : null,
    );
    _check(response);
    final json = _decode(response);
    final items = json is Map ? json['items'] : null;
    if (json is! Map || items is! List) {
      throw const ChatFailure(unavailableMessage);
    }
    final cursor = json['nextCursor'];
    return ChatMessagesPage(
      items: [
        for (final item in items)
          if (_message(item) case final message?) message,
      ],
      nextCursor: cursor is String && cursor.isNotEmpty ? cursor : after,
      hasMore: json['hasMore'] == true,
      open: json['open'] != false,
    );
  }

  @override
  Future<ChatMessage> send(
    ChatConversation conversation, {
    required String body,
    required String clientMessageId,
  }) async {
    final clean = cleanChatMessage(body);
    if (clean == null) {
      throw const ChatFailure('Escribe un mensaje de hasta 2000 caracteres.',
          statusCode: 400);
    }
    final response = await _send((headers) => _client.post(
          _uri(conversation),
          headers: {...headers, 'Content-Type': 'application/json'},
          body: jsonEncode({'body': clean, 'clientMessageId': clientMessageId}),
        ));
    if (response.statusCode == 409) {
      // Mismo clientMessageId con otro texto también es 409; la app nunca
      // reutiliza el identificador con otro texto, así que es la conversación
      // cerrada.
      throw ChatFailure(_detail(response) ?? closedMessage, statusCode: 409);
    }
    _check(response);
    final message = _message(_decode(response));
    if (message == null) throw const ChatFailure(unavailableMessage);
    return message;
  }

  Uri _uri(ChatConversation conversation) => _base.replace(pathSegments: [
        ..._base.pathSegments.where((s) => s.isNotEmpty),
        ...conversation.pathSegments,
      ]);

  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) request, {
    Duration? timeout,
  }) async {
    try {
      return await _http.send(request, timeout: timeout);
    } on SessionExpiredException {
      throw const ChatFailure(sessionExpiredMessage, isSessionExpired: true);
    } on BackendUnreachableException {
      throw const ChatFailure(connectionErrorMessage, isConnection: true);
    }
  }

  void _check(http.Response response) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) return;
    if (status == 403 || status == 404) {
      throw ChatFailure(notFoundMessage, statusCode: status);
    }
    if (status >= 400 && status < 500) {
      throw ChatFailure(_detail(response) ?? unavailableMessage,
          statusCode: status);
    }
    // 5xx (por ejemplo, durante un despliegue): se reintenta con espera.
    throw ChatFailure(unavailableMessage,
        statusCode: status, isConnection: true);
  }

  String? _detail(http.Response response) {
    final body = _decode(response);
    final detail = body is Map ? body['detail'] ?? body['title'] : null;
    return detail is String && detail.trim().isNotEmpty ? detail.trim() : null;
  }

  Object? _decode(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      return null;
    }
  }

  static ChatMessage? _message(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    try {
      return ChatMessage.fromJson(json);
    } on FormatException {
      return null;
    }
  }
}
