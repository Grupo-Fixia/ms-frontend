import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/service_chat.dart';

/// Estado de la conversación real de un servicio (GC-528), según el contrato
/// GC-527 §6:
/// 1. Carga el historial (página tras página mientras `hasMore`).
/// 2. Mientras la pantalla está abierta, repite `GET ?after=<cursor>&wait=25`
///    y vuelve a preguntar apenas llega la respuesta (long polling).
/// 3. Si falla la red o hay un despliegue, espera con tiempo creciente y
///    reintenta. Al cerrar la pantalla deja de preguntar.
/// 4. Cada envío lleva un `clientMessageId` nuevo y lo reutiliza al reintentar,
///    así un doble toque o un corte no duplican el mensaje.
class LiveChatController extends ChangeNotifier {
  LiveChatController({
    required ChatGateway gateway,
    required this.conversation,
    required String Function() newMessageId,
    this.onSessionExpired,
    this.longPollSeconds = 25,
    Duration Function(int failures)? retryDelay,
  })  : _gateway = gateway,
        _newMessageId = newMessageId,
        _retryDelay = retryDelay ?? defaultRetryDelay;

  /// 2, 4, 8, 16 y luego 30 s entre reintentos.
  static Duration defaultRetryDelay(int failures) =>
      Duration(seconds: [2, 4, 8, 16, 30][failures.clamp(0, 4)]);

  final ChatConversation conversation;
  final VoidCallback? onSessionExpired;
  final int longPollSeconds;
  final ChatGateway _gateway;
  final String Function() _newMessageId;
  final Duration Function(int failures) _retryDelay;

  final List<ChatMessage> _confirmed = [];
  final Set<String> _ids = {};

  /// `clientMessageId` de los propios ya confirmados.
  final Set<String> _sentIds = {};
  final List<ChatMessage> _pending = [];

  String? _cursor;
  bool _loading = true;
  bool _open = true;
  bool _reconnecting = false;
  String? _error;
  bool _started = false;
  bool _disposed = false;
  Timer? _sleep;
  Completer<void>? _wake;

  /// Mensajes en orden: los confirmados por el servidor y luego los propios
  /// que aún viajan o fallaron.
  List<ChatMessage> get messages =>
      List.unmodifiable([..._confirmed, ..._pending]);

  /// Cargando el historial por primera vez.
  bool get loading => _loading;

  /// El servicio todavía admite mensajes.
  bool get open => _open;

  /// Se perdió la conexión y se está reintentando; los mensajes cargados
  /// siguen a la vista.
  bool get reconnecting => _reconnecting;

  /// Error que impide mostrar la conversación (sin acceso, no existe).
  String? get error => _error;

  /// Empieza a cargar y a escuchar. Se llama una sola vez.
  void start() {
    if (_started) return;
    _started = true;
    unawaited(_run());
  }

  /// Envía [text]. `false` si está vacío, es muy largo o la conversación ya
  /// no admite mensajes.
  bool send(String text) {
    final body = cleanChatMessage(text);
    if (body == null || !_open || _error != null) return false;
    final message = ChatMessage(
      id: null,
      body: body,
      mine: true,
      createdAt: DateTime.now(),
      clientMessageId: _newMessageId(),
      delivery: ChatDelivery.sending,
    );
    _pending.add(message);
    _notify();
    unawaited(_deliver(message));
    return true;
  }

  /// Reintenta un envío fallido con el mismo `clientMessageId`.
  void retry(ChatMessage message) {
    final index = _pending
        .indexWhere((m) => m.clientMessageId == message.clientMessageId);
    if (index < 0 || _pending[index].delivery != ChatDelivery.failed) return;
    if (!_open) return;
    final again = _withDelivery(_pending[index], ChatDelivery.sending);
    _pending[index] = again;
    _notify();
    unawaited(_deliver(again));
  }

  Future<void> _deliver(ChatMessage message) async {
    try {
      final saved = await _gateway.send(
        conversation,
        body: message.body,
        clientMessageId: message.clientMessageId!,
      );
      if (_disposed) return;
      _merge([saved]);
      _pending.removeWhere((m) => m.clientMessageId == message.clientMessageId);
    } on ChatFailure catch (f) {
      if (_disposed) return;
      if (f.isSessionExpired) onSessionExpired?.call();
      if (f.isClosed) _open = false;
      _mark(message, ChatDelivery.failed);
    } catch (_) {
      if (_disposed) return;
      _mark(message, ChatDelivery.failed);
    }
    _notify();
  }

  void _mark(ChatMessage message, ChatDelivery delivery) {
    final index = _pending
        .indexWhere((m) => m.clientMessageId == message.clientMessageId);
    if (index >= 0) _pending[index] = _withDelivery(_pending[index], delivery);
  }

  static ChatMessage _withDelivery(ChatMessage m, ChatDelivery delivery) =>
      ChatMessage(
        id: m.id,
        body: m.body,
        mine: m.mine,
        createdAt: m.createdAt,
        clientMessageId: m.clientMessageId,
        delivery: delivery,
      );

  /// Agrega los mensajes nuevos del servidor sin repetir y quita los propios
  /// pendientes que ya llegaron (por ejemplo, por el long polling antes de
  /// que respondiera el envío).
  void _merge(List<ChatMessage> items) {
    for (final m in items) {
      final clientId = m.mine ? m.clientMessageId : null;
      if (clientId != null && _sentIds.contains(clientId)) continue;
      if (!_ids.add(m.id!)) continue;
      _confirmed.add(m);
      if (clientId != null) {
        _sentIds.add(clientId);
        _pending.removeWhere((p) => p.clientMessageId == clientId);
      }
    }
  }

  Future<void> _run() async {
    var failures = 0;
    var first = true;
    while (!_disposed) {
      try {
        final page = await _gateway.messages(
          conversation,
          after: _cursor,
          // El historial se pide sin esperar; luego, long polling.
          wait: first ? 0 : longPollSeconds,
        );
        if (_disposed) return;
        _merge(page.items);
        _cursor = page.nextCursor ?? _cursor;
        _open = page.open;
        _loading = false;
        _reconnecting = false;
        failures = 0;
        _notify();
        // Mientras haya más páginas, se piden enseguida y sin esperar.
        first = page.hasMore;
        // Cerrada la conversación ya no llegan mensajes: se deja de preguntar.
        if (!page.open && !page.hasMore) return;
      } on ChatFailure catch (f) {
        if (_disposed) return;
        if (f.isSessionExpired) {
          onSessionExpired?.call();
          return;
        }
        if (!f.isConnection) {
          // Sin acceso o inexistente: no tiene sentido reintentar.
          _error = f.message;
          _loading = false;
          _notify();
          return;
        }
        _reconnecting = true;
        _notify();
        await _pause(_retryDelay(failures++));
      } catch (_) {
        if (_disposed) return;
        _reconnecting = true;
        _notify();
        await _pause(_retryDelay(failures++));
      }
    }
  }

  /// Espera cancelable: al cerrar la pantalla no queda un temporizador vivo.
  Future<void> _pause(Duration delay) {
    final wake = Completer<void>();
    _wake = wake;
    _sleep = Timer(delay, () {
      if (!wake.isCompleted) wake.complete();
    });
    return wake.future;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sleep?.cancel();
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
    super.dispose();
  }
}
