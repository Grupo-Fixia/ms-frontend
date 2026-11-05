import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/service_chat.dart';

/// Estado del chat simulado de un servicio contratado.
///
/// Igual que el prototipo, no recibe repositorios ni clientes HTTP: no puede
/// enviar nada a otra cuenta ni cambiar datos del servicio. La contraparte
/// "escribe" un momento y responde con un texto genérico.
class ServiceChatController extends ChangeNotifier {
  ServiceChatController({
    required this.participant,
    this.replyDelay = const Duration(milliseconds: 1200),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const int maxMessageLength = 500;

  final ChatParticipant participant;
  final Duration replyDelay;
  final DateTime Function() _clock;

  final List<ServiceChatMessage> _messages = [];
  final List<Timer> _timers = [];
  int _replies = 0;
  int _typing = 0;
  bool _disposed = false;

  List<ServiceChatMessage> get messages => List.unmodifiable(_messages);
  bool get isEmpty => _messages.isEmpty;

  /// La contraparte simulada está "escribiendo".
  bool get counterpartTyping => _typing > 0;

  /// Agrega el mensaje y programa la respuesta simulada. `false` si el texto
  /// está vacío o es demasiado largo.
  bool send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > maxMessageLength) return false;
    _messages
        .add(ServiceChatMessage(mine: true, text: trimmed, sentAt: _clock()));
    _typing++;
    notifyListeners();
    _timers.add(Timer(replyDelay, _reply));
    return true;
  }

  void _reply() {
    if (_disposed) return;
    final replies = participant.simulatedReplies;
    _messages.add(ServiceChatMessage(
      mine: false,
      text: replies[_replies % replies.length],
      sentAt: _clock(),
    ));
    _replies++;
    _typing--;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }
}

/// Conversaciones simuladas abiertas durante la sesión, una por servicio y
/// rol. Así el chat se conserva al salir y volver a entrar mientras la app
/// sigue abierta; al recargar la página se pierde (no hay backend).
class ServiceChatStore {
  ServiceChatStore._();

  static final ServiceChatStore instance = ServiceChatStore._();

  final Map<String, ServiceChatController> _chats = {};

  ServiceChatController forService(
    String serviceRequestId,
    ChatParticipant participant,
  ) =>
      _chats.putIfAbsent(
        '${participant.name}:$serviceRequestId',
        () => ServiceChatController(participant: participant),
      );

  /// Solo para pruebas.
  @visibleForTesting
  void clear() {
    for (final chat in _chats.values) {
      chat.dispose();
    }
    _chats.clear();
  }
}
