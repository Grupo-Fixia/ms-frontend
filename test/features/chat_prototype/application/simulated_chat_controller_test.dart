import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/chat_prototype/application/simulated_chat_controller.dart';
import 'package:ms_frontend/features/chat_prototype/domain/simulated_message.dart';
import 'package:ms_frontend/features/chat_prototype/domain/simulated_replies.dart';

void main() {
  group('SimulatedChatController (GC-431)', () {
    test('empieza vacío', () {
      final chat = SimulatedChatController();
      expect(chat.isEmpty, isTrue);
      expect(chat.messages, isEmpty);
    });

    test('enviar agrega el mensaje y una respuesta simulada', () {
      final chat = SimulatedChatController();
      var notified = 0;
      chat.addListener(() => notified++);

      expect(chat.send('  Hola  '), isTrue);

      expect(chat.messages, hasLength(2));
      expect(chat.messages[0].author, SimulatedAuthor.you);
      expect(chat.messages[0].text, 'Hola');
      expect(chat.messages[1].author, SimulatedAuthor.simulation);
      expect(chat.messages[1].text, SimulatedReplies.at(0));
      expect(notified, 1);
    });

    test('rechaza texto vacío o solo espacios sin cambiar nada', () {
      final chat = SimulatedChatController();
      var notified = 0;
      chat.addListener(() => notified++);

      expect(chat.send(''), isFalse);
      expect(chat.send('   \n '), isFalse);

      expect(chat.isEmpty, isTrue);
      expect(notified, 0);
    });

    test('rechaza mensajes de más de 500 caracteres y acepta 500', () {
      final chat = SimulatedChatController();
      expect(chat.send('a' * (SimulatedChatController.maxMessageLength + 1)),
          isFalse);
      expect(chat.isEmpty, isTrue);
      expect(chat.send('a' * SimulatedChatController.maxMessageLength), isTrue);
      expect(chat.messages, hasLength(2));
    });

    test('las respuestas son reproducibles y cíclicas', () {
      final chat = SimulatedChatController();
      final total = SimulatedReplies.texts.length + 1;
      for (var i = 0; i < total; i++) {
        chat.send('mensaje $i');
      }
      final replies = chat.messages
          .where((m) => m.author == SimulatedAuthor.simulation)
          .map((m) => m.text)
          .toList();
      expect(replies, hasLength(total));
      for (var i = 0; i < total; i++) {
        expect(replies[i], SimulatedReplies.at(i));
      }
      expect(replies.first, replies.last);
    });

    test('reiniciar borra la conversación y vuelve al primer ciclo', () {
      final chat = SimulatedChatController();
      chat.send('uno');
      chat.send('dos');
      var notified = 0;
      chat.addListener(() => notified++);

      chat.reset();

      expect(chat.isEmpty, isTrue);
      expect(notified, 1);
      chat.send('otra vez');
      expect(chat.messages[1].text, SimulatedReplies.at(0));
    });

    test('la lista expuesta no se puede modificar desde fuera', () {
      final chat = SimulatedChatController()..send('hola');
      expect(
        () => chat.messages.add(const SimulatedMessage(
            author: SimulatedAuthor.you, text: 'intruso')),
        throwsUnsupportedError,
      );
    });

    test('las respuestas simuladas no nombran dinero, personas ni estados', () {
      final all = SimulatedReplies.texts.join(' ').toLowerCase();
      for (final forbidden in [r'$', 'cotiz', 'contrat', 'precio', 'pago']) {
        expect(all.contains(forbidden), isFalse, reason: forbidden);
      }
    });
  });
}
