import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/chat/domain/service_chat.dart';
import 'package:ms_frontend/features/chat/presentation/service_chat_page.dart';
import 'package:ms_frontend/features/contracts/domain/service_contract.dart';
import 'package:ms_frontend/features/contracts/presentation/contract_card.dart';

import 'fake_chat_gateway.dart';

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

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  ChatGateway? gateway,
  VoidCallback? onSessionExpired,
  Size size = const Size(1280, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: FixiaTheme.light,
    builder: (context, child) => ServiceChatScope(
      gateway: gateway,
      onSessionExpired: onSessionExpired ?? () {},
      child: child!,
    ),
    home: home,
  ));
  await tester.pump();
  await tester.pump();
}

Widget _page(ChatParticipant participant,
        {ServiceRequestStatus status = ServiceRequestStatus.contracted}) =>
    ServiceChatPage(
      contract: _contract(status: status),
      participant: participant,
      newMessageId: () => 'cm-1',
      retryDelay: (_) => const Duration(milliseconds: 10),
    );

Finder _key(String k) => find.byKey(ValueKey(k));

void main() {
  testWidgets('el cliente ve el historial y le llegan mensajes nuevos',
      (tester) async {
    final gateway = FakeChatGateway(history: [
      chatMessage('a', 'Buenos días, ¿confirmas?', mine: true),
      chatMessage('b', 'A las 9', minute: 1),
    ]);
    await _pump(tester, _page(ChatParticipant.client), gateway: gateway);

    expect(find.text('Chat con tu técnico'), findsOneWidget);
    expect(find.text('Buenos días, ¿confirmas?'), findsOneWidget);
    expect(find.text('A las 9'), findsOneWidget);
    expect(gateway.conversations.first.pathSegments,
        ['requests', 'req-1', 'messages']);
    expect(find.textContaining('simulad'), findsNothing);
    expect(_key('service-chat-demo-notice'), findsNothing);

    gateway.deliver([chatMessage('c', 'Ya voy en camino', minute: 2)]);
    await tester.pump();
    await tester.pump();
    expect(find.text('Ya voy en camino'), findsOneWidget);
  });

  testWidgets('escribe y envía; el mensaje rápido también se envía',
      (tester) async {
    final gateway = FakeChatGateway();
    await _pump(tester, _page(ChatParticipant.technician), gateway: gateway);

    expect(_key('service-chat-empty'), findsOneWidget);
    expect(gateway.conversations.first.pathSegments,
        ['contracts', 'c1', 'messages']);

    await tester.enterText(_key('service-chat-input'), 'Llego en 10');
    await tester.tap(_key('service-chat-send'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Llego en 10'), findsOneWidget);
    expect(gateway.sends.single.$1, 'Llego en 10');
    final input = tester.widget<TextField>(_key('service-chat-input'));
    expect(input.controller!.text, isEmpty);

    await tester.tap(_key('service-chat-quick-0'));
    await tester.pump();
    await tester.pump();
    expect(gateway.sends.last.$1, ChatParticipant.technician.quickMessages[0]);
  });

  testWidgets('un envío fallido muestra «Reintentar»', (tester) async {
    final gateway = FakeChatGateway()
      ..sendResults.add(const ChatFailure('caído', isConnection: true));
    await _pump(tester, _page(ChatParticipant.client), gateway: gateway);

    await tester.enterText(_key('service-chat-input'), 'Hola');
    await tester.tap(_key('service-chat-send'));
    await tester.pump();
    await tester.pump();

    expect(find.text('No se envió'), findsOneWidget);
    await tester.tap(_key('service-chat-retry-cm-1'));
    await tester.pump();
    await tester.pump();

    expect(find.text('No se envió'), findsNothing);
    expect(gateway.sends.map((s) => s.$2), ['cm-1', 'cm-1']);
  });

  testWidgets('conversación cerrada: solo lectura', (tester) async {
    final gateway =
        FakeChatGateway(history: [chatMessage('a', 'Gracias')], open: false);
    await _pump(tester,
        _page(ChatParticipant.client, status: ServiceRequestStatus.closed),
        gateway: gateway);

    expect(find.text('Gracias'), findsOneWidget);
    expect(_key('service-chat-closed'), findsOneWidget);
    expect(_key('service-chat-input'), findsNothing);
  });

  testWidgets('sin red avisa que reintenta y se recupera', (tester) async {
    final gateway = FakeChatGateway();
    await _pump(tester, _page(ChatParticipant.client), gateway: gateway);

    gateway.failPoll(const ChatFailure('red', isConnection: true));
    await tester.pump();
    await tester.pump();
    expect(_key('service-chat-reconnecting'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 20));
    gateway.deliver([chatMessage('b', 'Volvió')]);
    await tester.pump();
    await tester.pump();
    expect(_key('service-chat-reconnecting'), findsNothing);
    expect(find.text('Volvió'), findsOneWidget);
  });

  testWidgets('sin acceso muestra el error', (tester) async {
    final gateway = FakeChatGateway()
      ..historyError = const ChatFailure('Sin acceso', statusCode: 404);
    await _pump(tester, _page(ChatParticipant.client), gateway: gateway);
    expect(_key('service-chat-error'), findsOneWidget);
    expect(find.text('Sin acceso'), findsOneWidget);
  });

  testWidgets('sesión vencida avisa a la app', (tester) async {
    var expired = 0;
    final gateway = FakeChatGateway()
      ..historyError = const ChatFailure('Expiró', isSessionExpired: true);
    await _pump(tester, _page(ChatParticipant.client),
        gateway: gateway, onSessionExpired: () => expired++);
    expect(expired, 1);
  });

  testWidgets('sin backend no muestra mensajes falsos', (tester) async {
    await _pump(tester, _page(ChatParticipant.client));
    expect(_key('service-chat-unavailable'), findsOneWidget);
    expect(_key('service-chat-input'), findsNothing);
  });

  testWidgets('en celular no desborda', (tester) async {
    final gateway = FakeChatGateway(history: [
      for (var i = 0; i < 20; i++) chatMessage('m$i', 'Mensaje $i' * 5),
    ]);
    await _pump(tester, _page(ChatParticipant.client),
        gateway: gateway, size: const Size(390, 844));
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

    testWidgets('el técnico abre el chat real desde la contratación',
        (tester) async {
      final gateway = FakeChatGateway(history: [chatMessage('a', 'Hola')]);
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
        gateway: gateway,
      );
      expect(find.textContaining('Escríbele al cliente'), findsOneWidget);
      await tester.ensureVisible(_key('contract-open-chat'));
      await tester.tap(_key('contract-open-chat'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Chat con el cliente'), findsOneWidget);
      expect(find.text('Hola'), findsOneWidget);
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
