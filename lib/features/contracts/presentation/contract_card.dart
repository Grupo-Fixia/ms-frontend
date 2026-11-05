import 'package:flutter/material.dart';

import '../../../core/theme/fixia_theme.dart';
import '../../../core/widgets/fixia_ui.dart';
import '../../chat_prototype/domain/service_chat.dart';
import '../../chat_prototype/presentation/service_chat_page.dart';
import '../../quotations/presentation/quotation_card.dart';
import '../domain/service_contract.dart';

/// La contratación tal como quedó en ms-services al aceptar la cotización
/// (GC-359): precio contratado, alcance, condiciones, fecha acordada y, para
/// las partes, la dirección exacta. Incluye el estado del servicio y su
/// historial (GC-437, GC-441).
class ContractCard extends StatelessWidget {
  const ContractCard({
    super.key,
    required this.contract,
    this.actions = const [],
    this.walletPayments = false,
    this.chatAs,
  });

  /// Rol de quien ve la contratación. Si se da, se ofrece el chat (simulado)
  /// con la otra parte del servicio.
  final ChatParticipant? chatAs;

  /// El pago se hace con la billetera de Fixia (ms-payments).
  final bool walletPayments;

  final ServiceContract contract;

  /// Acciones del servicio según el rol y el estado (iniciar, finalizar,
  /// confirmar cierre…).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final request = contract.request;
    final status = contract.serviceStatus;
    return FixiaPanel(
      key: ValueKey('contract-${contract.id}'),
      highlight: FixiaColors.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_outlined, color: FixiaColors.accent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Contratación',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: FixiaColors.primary,
                  ),
                ),
              ),
              if (status != null) StatusPill(label: status.label),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Precio contratado',
            style: TextStyle(fontSize: 12, color: FixiaColors.textSecondary),
          ),
          Text(
            formatCents(contract.amountInCents, contract.currency),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: FixiaColors.secondary,
            ),
          ),
          _Line(
              'Servicio', '${request.category.label} · ${request.description}'),
          _Line('Alcance', contract.scope),
          _Line('Condiciones', contract.conditions),
          ResponsiveGrid(
            minItemWidth: 200,
            spacing: 8,
            children: [
              _Line('Fecha acordada', formatDateTime(contract.agreedAt)),
              if (request.exactAddress != null)
                _Line('Dirección', request.exactAddress!)
              else
                _Line(
                    'Ubicación aproximada', '${request.zone}, ${request.city}'),
              _Line('Contratado el', formatDateTime(contract.contractedAt)),
            ],
          ),
          _Line(
            'Pago',
            walletPayments
                ? 'Con la billetera de Fixia: el total queda retenido al contratar y el técnico lo recibe cuando el cliente confirma el cierre.'
                : 'Se acuerda directamente entre las partes; Fixia no procesa pagos en esta versión.',
          ),
          if (contract.timeline.isNotEmpty) ...[
            const Divider(height: 24),
            const Text(
              'Historial del servicio',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            for (var i = 0; i < contract.timeline.length; i++)
              _TimelineStep(
                transition: contract.timeline[i],
                last: i == contract.timeline.length - 1,
              ),
          ],
          if (chatAs != null) ...[
            const SizedBox(height: 16),
            _ChatEntry(contract: contract, participant: chatAs!),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 16),
            ActionBar(actions: actions),
          ],
        ],
      ),
    );
  }
}

/// Acceso al chat del servicio desde la contratación.
class _ChatEntry extends StatelessWidget {
  const _ChatEntry({required this.contract, required this.participant});

  final ServiceContract contract;
  final ChatParticipant participant;

  @override
  Widget build(BuildContext context) {
    final open = ServiceChatPage.isOpenFor(contract);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: FixiaColors.supportBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.forum_outlined, color: FixiaColors.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              open
                  ? 'Escríbele ${participant.toCounterpart} para coordinar el servicio.'
                  : 'Revisa la conversación con ${participant.counterpartLabel}.',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            key: const ValueKey('contract-open-chat'),
            // El tema hace los botones de ancho completo; aquí va en fila.
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ServiceChatPage(
                  contract: contract,
                  participant: participant,
                ),
              ),
            ),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: Text(open ? 'Abrir chat' : 'Ver chat'),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: FixiaColors.textSecondary,
              ),
            ),
            Text(value),
          ],
        ),
      );
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({required this.transition, required this.last});

  final ContractTransition transition;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = transition;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: last ? FixiaColors.accent : FixiaColors.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(width: 2, color: const Color(0xFFDCE5F0)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: Text(
                '${formatDateTime(t.occurredAt)} · ${t.toStatus.label}'
                '${t.actor == null ? '' : ' (${t.actor!.label})'}'
                '${t.reason == null ? '' : '\nMotivo: ${t.reason}'}',
                style: const TextStyle(color: FixiaColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
