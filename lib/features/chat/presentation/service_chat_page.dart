import 'package:flutter/material.dart';

import '../../../core/layout/app_shell.dart';
import '../../../core/theme/fixia_theme.dart';
import '../../../core/widgets/fixia_ui.dart';
import '../../contracts/domain/service_contract.dart';
import '../../payments/domain/payments.dart' show newIdempotencyKey;
import '../../quotations/presentation/quotation_card.dart';
import '../application/live_chat_controller.dart';
import '../domain/service_chat.dart';

/// Da a las pantallas el chat real del backend (GC-528) sin pasarlo por cada
/// tarjeta de contratación. La app lo pone encima del navegador.
class ServiceChatScope extends InheritedWidget {
  const ServiceChatScope({
    super.key,
    required this.gateway,
    required this.onSessionExpired,
    required super.child,
  });

  final ChatGateway? gateway;
  final VoidCallback onSessionExpired;

  static ServiceChatScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ServiceChatScope>();

  @override
  bool updateShouldNotify(ServiceChatScope oldWidget) =>
      gateway != oldWidget.gateway;
}

/// Chat real entre el cliente y el técnico que ejecuta un servicio contratado
/// (GC-528). Se abre desde la contratación; los mensajes se guardan en
/// ms-services y llegan casi en tiempo real (long polling, GC-527).
class ServiceChatPage extends StatefulWidget {
  const ServiceChatPage({
    super.key,
    required this.contract,
    required this.participant,
    this.gateway,
    this.newMessageId = newIdempotencyKey,
    this.retryDelay,
  });

  final ServiceContract contract;
  final ChatParticipant participant;

  /// Por defecto, el de [ServiceChatScope].
  final ChatGateway? gateway;
  final String Function() newMessageId;

  /// Solo para pruebas: espera entre reintentos de conexión.
  final Duration Function(int failures)? retryDelay;

  /// Lo que dice la tarjeta antes de abrir el chat. Quien manda es el
  /// backend (`open`): el servicio cerrado queda solo para consulta.
  static bool isOpenFor(ServiceContract contract) {
    final status = contract.serviceStatus;
    return status != ServiceRequestStatus.closed &&
        status != ServiceRequestStatus.cancelled &&
        status != ServiceRequestStatus.expired;
  }

  @override
  State<ServiceChatPage> createState() => _ServiceChatPageState();
}

class _ServiceChatPageState extends State<ServiceChatPage> {
  LiveChatController? _chat;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  int _shown = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_chat != null) return;
    final scope = ServiceChatScope.maybeOf(context);
    final gateway = widget.gateway ?? scope?.gateway;
    if (gateway == null) return;
    final contract = widget.contract;
    _chat = LiveChatController(
      gateway: gateway,
      conversation: ChatConversation(
        participant: widget.participant,
        contractId: contract.id,
        serviceRequestId: contract.serviceRequestId,
      ),
      newMessageId: widget.newMessageId,
      onSessionExpired: scope?.onSessionExpired,
      retryDelay: widget.retryDelay,
    )
      ..addListener(_onChange)
      ..start();
  }

  @override
  void dispose() {
    _chat
      ?..removeListener(_onChange)
      ..dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Baja al final cuando llega un mensaje nuevo.
  void _onChange() {
    final count = _chat!.messages.length;
    if (count == _shown) return;
    _shown = count;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _send([String? text]) {
    if ((_chat?.send(text ?? _input.text) ?? false) && text == null) {
      _input.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final participant = widget.participant;
    final contract = widget.contract;
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < ShellBreakpoints.tablet;
    final chatHeight =
        (size.height - (compact ? 170 : 250)).clamp(340.0, 780.0).toDouble();
    final title = 'Chat con ${participant.counterpartLabel}';
    return AppShell(
      destination: participant == ChatParticipant.client
          ? ShellDestination.clientRequests
          : ShellDestination.technicianJobs,
      subpage: true,
      mobileTitle: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compact) ...[
            const BackLink(),
            PageHeader(
              title: title,
              subtitle:
                  '${contract.request.category.label} · ${contract.request.description}',
            ),
            const SizedBox(height: 16),
          ],
          Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Container(
                key: const ValueKey('service-chat'),
                height: chatHeight,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE3EAF4)),
                ),
                child: Column(
                  children: [
                    _ChatHeader(contract: contract, participant: participant),
                    Expanded(child: _body(participant)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension on _ServiceChatPageState {
  Widget _body(ChatParticipant participant) {
    final chat = _chat;
    if (chat == null) {
      return const _Notice(
        key: ValueKey('service-chat-unavailable'),
        text: 'El chat no está disponible sin conexión con Fixia.',
      );
    }
    return ListenableBuilder(
      listenable: chat,
      builder: (context, _) {
        if (chat.loading) return const Center(child: SectionLoading());
        if (chat.error != null) {
          return _Notice(
              key: const ValueKey('service-chat-error'), text: chat.error!);
        }
        final messages = chat.messages;
        return Column(
          children: [
            if (chat.reconnecting) const _ReconnectingBanner(),
            Expanded(
              child: messages.isEmpty
                  ? _EmptyChat(participant: participant)
                  : ListView(
                      key: const ValueKey('service-chat-messages'),
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (final m in messages)
                          _Bubble(
                            message: m,
                            participant: participant,
                            onRetry: () => chat.retry(m),
                          ),
                      ],
                    ),
            ),
            if (chat.open) ...[
              _QuickMessages(
                messages: participant.quickMessages,
                onTap: _send,
              ),
              _Composer(controller: _input, onSend: _send),
            ] else
              const _ClosedNotice(),
          ],
        );
      },
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: FixiaColors.textSecondary),
          ),
        ),
      );
}

class _ReconnectingBanner extends StatelessWidget {
  const _ReconnectingBanner();

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('service-chat-reconnecting'),
        width: double.infinity,
        color: const Color(0xFFFFF4D6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: const Row(
          children: [
            SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sin conexión. Reintentando para traer los mensajes nuevos…',
                style: TextStyle(fontSize: 12.5),
              ),
            ),
          ],
        ),
      );
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.contract, required this.participant});

  final ServiceContract contract;
  final ChatParticipant participant;

  @override
  Widget build(BuildContext context) {
    final status = contract.serviceStatus;
    return Container(
      color: FixiaColors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFE7F0FF),
            child: Icon(
              participant == ChatParticipant.client
                  ? Icons.engineering_outlined
                  : Icons.person_outline_rounded,
              color: FixiaColors.secondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  participant.counterpartTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Servicio para el ${formatDateTime(contract.agreedAt)}',
                  key: const ValueKey('service-chat-agreed-at'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: FixiaColors.textSecondary),
                ),
              ],
            ),
          ),
          if (status != null) StatusPill(label: status.label),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.participant});

  final ChatParticipant participant;

  @override
  Widget build(BuildContext context) => Center(
        key: const ValueKey('service-chat-empty'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.forum_outlined,
                  size: 36, color: Color(0xFF9AAABB)),
              const SizedBox(height: 8),
              Text(
                'Coordina los detalles del servicio con '
                '${participant.counterpartLabel}.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: FixiaColors.textSecondary),
              ),
            ],
          ),
        ),
      );
}

String _time(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.participant,
    required this.onRetry,
  });

  final ChatMessage message;
  final ChatParticipant participant;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    final failed = message.delivery == ChatDelivery.failed;
    final bubble = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: mine ? FixiaColors.secondary : FixiaColors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(mine ? 16 : 4),
          bottomRight: Radius.circular(mine ? 4 : 16),
        ),
        border: mine ? null : Border.all(color: const Color(0xFFDCE5F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!mine)
            Text(
              participant.counterpartTitle,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: FixiaColors.textSecondary,
              ),
            ),
          Text(
            message.body,
            style: TextStyle(
              color: mine ? FixiaColors.white : FixiaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            widthFactor: 1,
            child: Text(
              switch (message.delivery) {
                ChatDelivery.sending => 'Enviando…',
                ChatDelivery.failed => 'No se envió',
                ChatDelivery.sent => _time(message.createdAt),
              },
              style: TextStyle(
                fontSize: 10.5,
                color: mine
                    ? FixiaColors.white.withOpacity(0.8)
                    : FixiaColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
    final keyed = KeyedSubtree(
      key: ValueKey(message.id ?? 'pending-${message.clientMessageId}'),
      child: bubble,
    );
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: failed
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Opacity(opacity: 0.6, child: keyed),
                TextButton.icon(
                  key:
                      ValueKey('service-chat-retry-${message.clientMessageId}'),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 32)),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Reintentar'),
                ),
              ],
            )
          : keyed,
    );
  }
}

class _QuickMessages extends StatelessWidget {
  const _QuickMessages({required this.messages, required this.onTap});

  final List<String> messages;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => Container(
        color: FixiaColors.white,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (i, text) in messages.indexed)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    key: ValueKey('service-chat-quick-$i'),
                    label: Text(text),
                    onPressed: () => onTap(text),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Container(
        color: FixiaColors.white,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('service-chat-input'),
                controller: controller,
                maxLength: maxChatMessageLength,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Escribe un mensaje',
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              key: const ValueKey('service-chat-send'),
              tooltip: 'Enviar',
              icon: const Icon(Icons.send_rounded),
              onPressed: onSend,
            ),
          ],
        ),
      );
}

class _ClosedNotice extends StatelessWidget {
  const _ClosedNotice();

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('service-chat-closed'),
        width: double.infinity,
        color: FixiaColors.white,
        padding: const EdgeInsets.all(14),
        child: const Text(
          'El servicio ya terminó: la conversación queda solo para consulta.',
          textAlign: TextAlign.center,
          style: TextStyle(color: FixiaColors.textSecondary),
        ),
      );
}
