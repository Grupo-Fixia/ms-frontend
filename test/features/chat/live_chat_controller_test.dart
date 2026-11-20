import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/chat/application/live_chat_controller.dart';
import 'package:ms_frontend/features/chat/domain/service_chat.dart';

import 'fake_chat_gateway.dart';

const _conversation = ChatConversation(
  participant: ChatParticipant.client,
  contractId: 'c1',
  serviceRequestId: 'r1',
);

LiveChatController _controller(
  FakeChatGateway gateway, {
  void Function()? onSessionExpired,
}) {
  var ids = 0;
  final chat = LiveChatController(
    gateway: gateway,
    conversation: _conversation,
    newMessageId: () => 'cm-${++ids}',
    onSessionExpired: onSessionExpired,
    retryDelay: (_) => const Duration(milliseconds: 5),
  );
  addTearDown(chat.dispose);
  return chat;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('carga el historial por páginas y luego escucha con wait=25', () async {
    final gateway = FakeChatGateway(
      history: [
        chatMessage('a', 'Hola'),
        chatMessage('b', '¿A qué hora?', mine: true),
        chatMessage('c', 'A las 9'),
      ],
      historyPages: 2,
    );
    final chat = _controller(gateway)..start();
    expect(chat.loading, isTrue);
    await _settle();
    await _settle();

    expect(chat.loading, isFalse);
    expect(
        chat.messages.map((m) => m.body), ['Hola', '¿A qué hora?', 'A las 9']);
    expect(gateway.reads, [(null, 0), ('c1', 0), ('c2', 25)]);
    expect(gateway.polling, isTrue);
  });

  test('cada mensaje nuevo llega sin repetir y vuelve a preguntar', () async {
    final gateway = FakeChatGateway(history: [chatMessage('a', 'Hola')]);
    final chat = _controller(gateway)..start();
    await _settle();

    gateway.deliver([chatMessage('a', 'Hola'), chatMessage('b', 'Nuevo')]);
    await _settle();

    expect(chat.messages.map((m) => m.id), ['a', 'b']);
    expect(gateway.reads.last, ('p2', 25));
  });

  test('enviar: muestra «enviando» y luego el mensaje guardado', () async {
    final gateway = FakeChatGateway();
    final chat = _controller(gateway)..start();
    await _settle();

    expect(chat.send('   '), isFalse);
    expect(chat.send('x' * 2001), isFalse);
    expect(chat.send('  Voy en camino  '), isTrue);
    expect(chat.messages.single.delivery, ChatDelivery.sending);
    expect(chat.messages.single.body, 'Voy en camino');

    await _settle();
    expect(gateway.sends, [('Voy en camino', 'cm-1')]);
    expect(chat.messages.single.delivery, ChatDelivery.sent);
    expect(chat.messages.single.id, isNotNull);
  });

  test('si el long polling trae el propio mensaje primero, no se duplica',
      () async {
    final gateway = FakeChatGateway();
    final chat = _controller(gateway)..start();
    await _settle();

    chat.send('Hola');
    gateway.deliver([
      chatMessage('srv-1', 'Hola', mine: true, clientMessageId: 'cm-1'),
    ]);
    await _settle();
    await _settle();

    expect(chat.messages, hasLength(1));
    expect(chat.messages.single.delivery, ChatDelivery.sent);
  });

  test('un envío fallido se reintenta con el mismo clientMessageId', () async {
    final gateway = FakeChatGateway()
      ..sendResults.add(const ChatFailure('caído', isConnection: true));
    final chat = _controller(gateway)..start();
    await _settle();

    chat.send('Hola');
    await _settle();
    final failed = chat.messages.single;
    expect(failed.delivery, ChatDelivery.failed);

    chat.retry(failed);
    await _settle();

    expect(gateway.sends.map((s) => s.$2), ['cm-1', 'cm-1']);
    expect(chat.messages.single.delivery, ChatDelivery.sent);
  });

  test('409 al enviar cierra la caja de texto', () async {
    final gateway = FakeChatGateway()
      ..sendResults.add(const ChatFailure('Cerrada', statusCode: 409));
    final chat = _controller(gateway)..start();
    await _settle();

    chat.send('Hola');
    await _settle();

    expect(chat.open, isFalse);
    expect(chat.send('Otro'), isFalse);
  });

  test('conversación cerrada: solo lectura y deja de preguntar', () async {
    final gateway = FakeChatGateway(
      history: [chatMessage('a', 'Gracias')],
      open: false,
    );
    final chat = _controller(gateway)..start();
    await _settle();

    expect(chat.open, isFalse);
    expect(chat.messages, hasLength(1));
    expect(gateway.reads, [(null, 0)]);
    expect(chat.send('Hola'), isFalse);
  });

  test('si se cae la red reintenta con espera y se recupera', () async {
    final gateway = FakeChatGateway();
    final chat = _controller(gateway)..start();
    await _settle();

    gateway.failPoll(const ChatFailure('red', isConnection: true));
    await _settle();
    expect(chat.reconnecting, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(gateway.polling, isTrue);
    gateway.deliver([chatMessage('b', 'Ya')]);
    await _settle();

    expect(chat.reconnecting, isFalse);
    expect(chat.messages.single.body, 'Ya');
  });

  test('sin acceso muestra el error y no reintenta', () async {
    final gateway = FakeChatGateway()
      ..historyError = const ChatFailure('No existe', statusCode: 404);
    final chat = _controller(gateway)..start();
    await _settle();

    expect(chat.error, 'No existe');
    expect(chat.loading, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(gateway.reads, hasLength(1));
    expect(chat.send('Hola'), isFalse);
  });

  test('sesión vencida avisa y deja de preguntar', () async {
    var expired = 0;
    final gateway = FakeChatGateway()
      ..historyError = const ChatFailure('Expiró', isSessionExpired: true);
    _controller(gateway, onSessionExpired: () => expired++).start();
    await _settle();
    expect(expired, 1);
    expect(gateway.reads, hasLength(1));
  });

  test('al cerrar la pantalla no sigue preguntando', () async {
    final gateway = FakeChatGateway();
    final chat = LiveChatController(
      gateway: gateway,
      conversation: _conversation,
      newMessageId: () => 'x',
      retryDelay: (_) => const Duration(milliseconds: 5),
    )..start();
    await _settle();
    gateway.failPoll(const ChatFailure('red', isConnection: true));
    await _settle();
    chat.dispose();
    final reads = gateway.reads.length;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(gateway.reads.length, reads);
  });

  test('espera creciente: 2, 4, 8, 16 y luego 30 s', () {
    expect(
      [for (var i = 0; i < 7; i++) LiveChatController.defaultRetryDelay(i)],
      [2, 4, 8, 16, 30, 30, 30].map((s) => Duration(seconds: s)).toList(),
    );
  });

  test('las rutas dependen del rol', () {
    expect(_conversation.pathSegments, ['requests', 'r1', 'messages']);
    expect(
      const ChatConversation(
        participant: ChatParticipant.technician,
        contractId: 'c1',
        serviceRequestId: 'r1',
      ).pathSegments,
      ['contracts', 'c1', 'messages'],
    );
  });
}
