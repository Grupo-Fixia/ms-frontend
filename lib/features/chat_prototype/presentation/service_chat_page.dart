import 'package:flutter/material.dart';

import '../../../core/layout/app_shell.dart';
import '../../../core/theme/fixia_theme.dart';
import '../../../core/widgets/fixia_ui.dart';
import '../../contracts/domain/service_contract.dart';
import '../../quotations/presentation/quotation_card.dart';
import '../application/service_chat_controller.dart';
import '../domain/service_chat.dart';

/// Chat simulado entre cliente y técnico de un servicio contratado.
///
/// Se abre desde la contratación. La conversación es local y las respuestas
/// son automáticas: la mensajería real aún no existe en el backend.
class ServiceChatPage extends StatefulWidget {
  const ServiceChatPage({
    super.key,
    required this.contract,
    required this.participant,
    this.controller,
  });

  final ServiceContract contract;
  final ChatParticipant participant;

  /// Solo para pruebas; por defecto usa la conversación de la sesión.
  final ServiceChatController? controller;

  /// Con el servicio cerrado o cancelado la conversación queda de solo
  /// lectura.
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
  late final ServiceChatController _chat = widget.controller ??
      ServiceChatStore.instance
          .forService(widget.contract.serviceRequestId, widget.participant);
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _chat.addListener(_toBottom);
  }

  @override
  void dispose() {
    _chat.removeListener(_toBottom);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _send([String? text]) {
    if (_chat.send(text ?? _input.text) && text == null) _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final participant = widget.participant;
    final contract = widget.contract;
    final open = ServiceChatPage.isOpenFor(contract);
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
                    const _DemoNotice(),
                    Expanded(
                      child: ListenableBuilder(
                        listenable: _chat,
                        builder: (context, _) => _chat.isEmpty &&
                                !_chat.counterpartTyping
                            ? _EmptyChat(participant: participant)
                            : ListView(
                                key: const ValueKey('service-chat-messages'),
                                controller: _scroll,
                                padding: const EdgeInsets.all(16),
                                children: [
                                  for (final m in _chat.messages)
                                    _Bubble(
                                        message: m, participant: participant),
                                  if (_chat.counterpartTyping)
                                    _Typing(participant: participant),
                                ],
                              ),
                      ),
                    ),
                    if (open) ...[
                      _QuickMessages(
                        messages: participant.quickMessages,
                        onTap: _send,
                      ),
                      _Composer(controller: _input, onSend: _send),
                    ] else
                      const _ClosedNotice(),
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

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('service-chat-demo-notice'),
        width: double.infinity,
        color: const Color(0xFFFFF4D6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: const Row(
          children: [
            Icon(Icons.science_outlined, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Demostración: los mensajes no llegan a la otra persona y las '
                'respuestas son automáticas. La conversación se borra al '
                'recargar la página.',
                style: TextStyle(fontSize: 12.5, height: 1.3),
              ),
            ),
          ],
        ),
      );
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
  const _Bubble({required this.message, required this.participant});

  final ServiceChatMessage message;
  final ChatParticipant participant;

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
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
                '${participant.counterpartTitle} · simulado',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: FixiaColors.textSecondary,
                ),
              ),
            Text(
              message.text,
              style: TextStyle(
                color: mine ? FixiaColors.white : FixiaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              widthFactor: 1,
              child: Text(
                _time(message.sentAt),
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
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing({required this.participant});

  final ChatParticipant participant;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 4),
          child: Text(
            '${participant.counterpartTitle} está escribiendo…',
            key: const ValueKey('service-chat-typing'),
            style: const TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: FixiaColors.textSecondary,
            ),
          ),
        ),
      );
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
                maxLength: ServiceChatController.maxMessageLength,
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
