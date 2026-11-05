import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/chat_prototype/application/service_chat_controller.dart';
import 'package:ms_frontend/features/chat_prototype/domain/service_chat.dart';
import 'package:ms_frontend/features/chat_prototype/presentation/service_chat_page.dart';
import 'package:ms_frontend/features/contracts/domain/service_contract.dart';
import 'package:ms_frontend/features/contracts/presentation/contract_card.dart';

ServiceContract _contract(
        {ServiceRequestStatus status = ServiceRequestStatus.contracted}) =>
    ServiceContract(
      id: 'c1',
      serviceRequestId: 'req-1',
      quotationId: 'q1',
      clientId: 'cli-1',
      providerId: 'tec-1',
      amountInCents: 13800000,
      currency: 'COP',
      scope: 'Cambio de sifón',
      conditions: 'Garantía 30 días',
      agreedAt: DateTime.utc(2029, 12, 2, 15),
      contractedAt: DateTime.utc(2029, 12, 1),
      request: const ContractedRequest(
        category: ServiceCategory.plumbing,
        description: 'Fuga en la cocina',
        city: 'Bogotá',
        zone: 'Chapinero',
      ),
      serviceStatus: status,
    );

Future<void> _pump(WidgetTester tester, Widget home,
    {Size size = const Size(1280, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: FixiaTheme.light, home: home));
  await tester.pump();
}

Finder _key(String k) => find.byKey(ValueKey(k));

void main() {
  tearDown(ServiceChatStore.instance.clear);

  group('ServiceChatController', () {
    test('responde como la contraparte tras escribir y no acepta vacíos',
        () async {
      final chat = ServiceChatController(
        participant: ChatParticipant.client,
        replyDelay: const Duration(milliseconds: 10),
        clock: () => DateTime(2029, 12, 2, 9, 30),
      );
      addTearDown(chat.dispose);
      expect(chat.send('   '), isFalse);
      expect(chat.send('x' * 501), isFalse);
      expect(chat.send(' ¿A qué hora llegas? '), isTrue);
      expect(chat.messages.single.text, '¿A qué hora llegas?');
      expect(chat.counterpartTyping, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(chat.counterpartTyping, isFalse);
      expect(chat.messages, hasLength(2));
      expect(chat.messages.last.mine, isFalse);
      expect(chat.messages.last.text,
          ChatParticipant.client.simulatedReplies.first);
    });

    test('al cerrarse no responde después', () async {
      final chat = ServiceChatController(
        participant: ChatParticipant.technician,
        replyDelay: const Duration(milliseconds: 10),
      );
      chat.send('Voy en camino.');
      chat.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(chat.messages, hasLength(1));
    });

    test('la sesión guarda una conversación por servicio y rol', () {
      final store = ServiceChatStore.instance;
      final a = store.forService('req-1', ChatParticipant.client);
      expect(store.forService('req-1', ChatParticipant.client), same(a));
      expect(store.forService('req-1', ChatParticipant.technician),
          isNot(same(a)));
      expect(store.forService('req-2', ChatParticipant.client), isNot(same(a)));
    });
  });

  testWidgets('el cliente escribe, usa un mensaje rápido y recibe respuesta',
      (tester) async {
    final chat = ServiceChatController(
      participant: ChatParticipant.client,
      replyDelay: const Duration(seconds: 1),
    );
    addTearDown(chat.dispose);
    await _pump(
      tester,
      ServiceChatPage(
        contract: _contract(),
        participant: ChatParticipant.client,
        controller: chat,
      ),
    );

    expect(find.text('Chat con tu técnico'), findsOneWidget);
    expect(find.textContaining('Fuga en la cocina'), findsOneWidget);
    expect(_key('service-chat-demo-notice'), findsOneWidget);
    expect(_key('service-chat-empty'), findsOneWidget);

    await tester.enterText(_key('service-chat-input'), 'Hola, ¿todo bien?');
    await tester.tap(_key('service-chat-send'));
    await tester.pump();
    expect(find.text('Hola, ¿todo bien?'), findsOneWidget);
    expect(_key('service-chat-typing'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(_key('service-chat-typing'), findsNothing);
    expect(find.text('Técnico · simulado'), findsOneWidget);

    await tester.tap(_key('service-chat-quick-1'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('Ya estoy en casa.'), findsWidgets);
    expect(find.text('Técnico · simulado'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('con el servicio cerrado queda de solo lectura', (tester) async {
    await _pump(
      tester,
      ServiceChatPage(
        contract: _contract(status: ServiceRequestStatus.closed),
        participant: ChatParticipant.technician,
      ),
    );
    expect(find.text('Chat con el cliente'), findsOneWidget);
    expect(_key('service-chat-closed'), findsOneWidget);
    expect(_key('service-chat-input'), findsNothing);
    expect(_key('service-chat-quick-0'), findsNothing);
  });

  testWidgets('en celular no desborda', (tester) async {
    await _pump(
      tester,
      ServiceChatPage(
        contract: _contract(),
        participant: ChatParticipant.technician,
      ),
      size: const Size(360, 740),
    );
    expect(tester.takeException(), isNull);
  });

  group('acceso desde la contratación', () {
    testWidgets('sin rol no se ofrece el chat', (tester) async {
      await _pump(
          tester,
          Scaffold(
              body: SingleChildScrollView(
                  child: ContractCard(contract: _contract()))));
      expect(_key('contract-open-chat'), findsNothing);
    });

    testWidgets('el técnico abre el chat y la conversación se conserva',
        (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: ContractCard(
              contract: _contract(),
              chatAs: ChatParticipant.technician,
            ),
          ),
        ),
      );
      expect(find.textContaining('Escríbele al cliente'), findsOneWidget);
      await tester.ensureVisible(_key('contract-open-chat'));
      await tester.tap(_key('contract-open-chat'));
      await tester.pumpAndSettle();
      expect(find.text('Chat con el cliente'), findsOneWidget);

      await tester.tap(_key('service-chat-quick-0'));
      await tester.pump(const Duration(seconds: 2));
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      await tester.tap(_key('contract-open-chat'));
      await tester.pumpAndSettle();
      expect(find.text('Voy en camino.'), findsWidgets);
    });

    testWidgets('servicio cerrado: ver chat', (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: ContractCard(
              contract: _contract(status: ServiceRequestStatus.closed),
              chatAs: ChatParticipant.client,
            ),
          ),
        ),
      );
      expect(find.text('Ver chat'), findsOneWidget);
    });
  });
}
