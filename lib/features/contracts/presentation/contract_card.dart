import 'package:flutter/material.dart';

import '../../../core/theme/fixia_theme.dart';
import '../../quotations/presentation/quotation_card.dart';
import '../domain/service_contract.dart';

/// La contratación tal como quedó en ms-services al aceptar la cotización
/// (GC-359): precio contratado, alcance, condiciones, fecha acordada y, para
/// las partes, la dirección exacta. Incluye el estado del servicio y su
/// historial (GC-437, GC-441).
class ContractCard extends StatelessWidget {
  const ContractCard(
      {super.key, required this.contract, this.actions = const []});

  final ServiceContract contract;

  /// Acciones del servicio según el rol y el estado (iniciar, finalizar,
  /// confirmar cierre…).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final request = contract.request;
    final status = contract.serviceStatus;
    return Card(
      key: ValueKey('contract-${contract.id}'),
      color: FixiaColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FixiaRadii.card),
        side: const BorderSide(color: FixiaColors.accent, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                if (status != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: FixiaColors.supportBackground,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: FixiaColors.primary,
                      ),
                    ),
                  ),
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
            _Line('Servicio',
                '${request.category.label} · ${request.description}'),
            _Line('Alcance', contract.scope),
            _Line('Condiciones', contract.conditions),
            _Line('Fecha acordada', formatDateTime(contract.agreedAt)),
            if (request.exactAddress != null)
              _Line('Dirección', request.exactAddress!)
            else
              _Line('Ubicación aproximada', '${request.zone}, ${request.city}'),
            _Line('Contratado el', formatDateTime(contract.contractedAt)),
            const _Line(
              'Pago',
              'Se acuerda directamente entre las partes; Fixia no procesa pagos en esta versión.',
            ),
            if (contract.timeline.isNotEmpty) ...[
              const Divider(height: 24),
              const Text(
                'Historial del servicio',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              for (final t in contract.timeline)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${formatDateTime(t.occurredAt)} · ${t.toStatus.label}'
                    '${t.actor == null ? '' : ' (${t.actor!.label})'}'
                    '${t.reason == null ? '' : '\nMotivo: ${t.reason}'}',
                    style: const TextStyle(color: FixiaColors.textSecondary),
                  ),
                ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final action in actions)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(width: double.infinity, child: action),
                ),
            ],
          ],
        ),
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
