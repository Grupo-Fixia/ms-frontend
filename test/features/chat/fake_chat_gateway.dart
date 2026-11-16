import 'dart:async';

import 'package:ms_frontend/features/chat/domain/service_chat.dart';

ChatMessage chatMessage(
  String id,
  String body, {
  bool mine = false,
  String? clientMessageId,
  int minute = 0,
}) =>
    ChatMessage(
      id: id,
      body: body,
      mine: mine,
      createdAt: DateTime.utc(2026, 11, 10, 14, minute),
      clientMessageId: clientMessageId,
    );

/// Gateway en memoria. Cada lectura con `wait > 0` queda pendiente hasta que
/// la prueba la responda con [deliver], [failPoll] o [closePoll].
class FakeChatGateway implements ChatGateway {
  FakeChatGateway({
    List<ChatMessage> history = const [],
    this.historyPages = 1,
    this.open = true,
  }) : _history = [...history];

  final List<ChatMessage> _history;
  final int historyPages;
  bool open;

  final reads = <(String?, int)>[];
  final sends = <(String, String)>[];
  final conversations = <ChatConversation>[];

  /// Falla las próximas lecturas iniciales con este error.
  ChatFailure? historyError;

  /// Respuestas de los próximos envíos; si está vacía, se guarda bien.
  final sendResults = <Object>[];

  Completer<ChatMessagesPage>? _poll;
  int _historyServed = 0;
  int _next = 100;

  bool get polling => _poll != null && !_poll!.isCompleted;

  @override
  Future<ChatMessagesPage> messages(ChatConversation conversation,
      {String? after, int wait = 0}) {
    conversations.add(conversation);
    reads.add((after, wait));
    if (wait == 0) {
      final error = historyError;
      if (error != null) {
        historyError = null;
        return Future.error(error);
      }
      // Historial en [historyPages] páginas.
      final size = (_history.length / historyPages).ceil();
      final start = _historyServed * size;
      final items = _history.skip(start).take(size).toList();
      _historyServed++;
      return Future.value(ChatMessagesPage(
        items: items,
        nextCursor: 'c$_historyServed',
        hasMore: _historyServed < historyPages,
        open: open,
      ));
    }
    _poll = Completer();
    return _poll!.future;
  }

  void deliver(List<ChatMessage> items, {bool? open}) {
    if (open != null) this.open = open;
    _poll!.complete(ChatMessagesPage(
      items: items,
      nextCursor: 'p${reads.length}',
      hasMore: false,
      open: this.open,
    ));
  }

  void failPoll(ChatFailure failure) => _poll!.completeError(failure);

  @override
  Future<ChatMessage> send(ChatConversation conversation,
      {required String body, required String clientMessageId}) async {
    sends.add((body, clientMessageId));
    if (sendResults.isNotEmpty) {
      final result = sendResults.removeAt(0);
      if (result is ChatFailure) throw result;
    }
    return ChatMessage(
      id: 'm${_next++}',
      body: body,
      mine: true,
      createdAt: DateTime.utc(2026, 11, 10, 15),
      clientMessageId: clientMessageId,
    );
  }
}
