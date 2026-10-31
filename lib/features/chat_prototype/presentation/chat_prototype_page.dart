import 'package:flutter/material.dart';

import '../../../core/theme/fixia_theme.dart';
import '../application/simulated_chat_controller.dart';
import '../domain/simulated_message.dart';

/// Chat prototipo (GC-406 / GC-431): simulación visual de cómo sería la
/// comunicación dentro de Fixia.
///
/// No es mensajería real (RF-038 a RF-043 siguen pendientes): no envía nada a
/// otra cuenta, no guarda mensajes y no toca precios, cotizaciones,
/// contratación ni estados. Por eso no recibe repositorios ni clientes HTTP.
class ChatPrototypePage extends StatefulWidget {
  const ChatPrototypePage({super.key, this.controller});

  /// Solo para pruebas; por defecto la página crea su propio estado.
  final SimulatedChatController? controller;

  @override
  State<ChatPrototypePage> createState() => _ChatPrototypePageState();
}

class _ChatPrototypePageState extends State<ChatPrototypePage> {
  late final SimulatedChatController _chat =
      widget.controller ?? SimulatedChatController();
  final TextEditingController _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    if (widget.controller == null) _chat.dispose();
    super.dispose();
  }

  void _send() {
    if (_chat.send(_input.text)) _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FixiaColors.neutralBackground,
      appBar: AppBar(
        title: const Text('Chat de demostración'),
        actions: [
          IconButton(
            key: const ValueKey('chat-prototype-reset'),
            tooltip: 'Reiniciar conversación',
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: _chat.reset,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                const _SimulationBanner(),
                Expanded(
                  child: ListenableBuilder(
                    listenable: _chat,
                    builder: (context, _) => _chat.isEmpty
                        ? const _EmptyState()
                        : _MessageList(messages: _chat.messages),
                  ),
                ),
                _Composer(controller: _input, onSend: _send),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SimulationBanner extends StatelessWidget {
  const _SimulationBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('chat-prototype-banner'),
      width: double.infinity,
      color: const Color(0xFFFFF4D6),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science_outlined, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SIMULACIÓN · Prototipo de chat',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'Lo que escribas aquí no se envía a ninguna cuenta y nadie lo '
            'recibe. Las respuestas son automáticas. No se guarda nada: al '
            'salir de esta pantalla o recargar la página, la conversación '
            'desaparece. No cambia precios, cotizaciones, contrataciones ni '
            'estados reales.',
            style: TextStyle(fontSize: 13, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: ValueKey('chat-prototype-empty'),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Escribe un mensaje para ver cómo funcionaría el chat. '
          'Recibirás una respuesta simulada.',
          textAlign: TextAlign.center,
          style: TextStyle(color: FixiaColors.textSecondary),
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.messages});

  final List<SimulatedMessage> messages;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const ValueKey('chat-prototype-messages'),
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) => _Bubble(message: messages[index]),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final SimulatedMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.author == SimulatedAuthor.you;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: mine ? FixiaColors.secondary : FixiaColors.white,
          borderRadius: BorderRadius.circular(16),
          border: mine ? null : Border.all(color: const Color(0xFFDCE5F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              mine ? 'Tú' : 'Respuesta simulada',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: mine ? FixiaColors.white : FixiaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              message.text,
              style: TextStyle(
                color: mine ? FixiaColors.white : FixiaColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FixiaColors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('chat-prototype-input'),
              controller: controller,
              maxLength: SimulatedChatController.maxMessageLength,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: 'Escribe un mensaje de prueba',
                counterText: '',
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            key: const ValueKey('chat-prototype-send'),
            tooltip: 'Enviar (simulado)',
            icon: const Icon(Icons.send_rounded),
            onPressed: onSend,
          ),
        ],
      ),
    );
  }
}
