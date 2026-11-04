import 'package:flutter/foundation.dart';

import '../domain/simulated_message.dart';
import '../domain/simulated_replies.dart';

/// Estado del chat prototipo (GC-431).
///
/// Todo ocurre en memoria: no recibe repositorios, clientes HTTP ni sesión, y
/// por eso no puede enviar mensajes, publicar eventos ni modificar datos de
/// negocio. Al destruirse el controlador (salir de la pantalla o recargar) la
/// conversación desaparece.
class SimulatedChatController extends ChangeNotifier {
  /// Largo máximo de un mensaje de la demo.
  static const int maxMessageLength = 500;

  final List<SimulatedMessage> _messages = [];
  int _sentCount = 0;

  /// Mensajes en orden cronológico.
  List<SimulatedMessage> get messages => List.unmodifiable(_messages);

  bool get isEmpty => _messages.isEmpty;

  /// Agrega el mensaje de la persona y la respuesta simulada.
  ///
  /// Devuelve `false` (sin cambios) si el texto está vacío o supera
  /// [maxMessageLength].
  bool send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > maxMessageLength) return false;
    _messages
      ..add(SimulatedMessage(author: SimulatedAuthor.you, text: trimmed))
      ..add(SimulatedMessage(
        author: SimulatedAuthor.simulation,
        text: SimulatedReplies.at(_sentCount),
      ));
    _sentCount++;
    notifyListeners();
    return true;
  }

  /// Borra la conversación y reinicia el ciclo de respuestas.
  void reset() {
    _messages.clear();
    _sentCount = 0;
    notifyListeners();
  }
}
