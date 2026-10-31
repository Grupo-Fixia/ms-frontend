import 'package:flutter/material.dart';

import '../../../core/theme/fixia_theme.dart';
import '../domain/quotation.dart';

/// Valor en centavos con separador de miles: 14500050 → «145.000,50 COP».
String formatCents(int cents, [String currency = 'COP']) {
  final pesos = (cents ~/ 100).toString();
  final rest = cents % 100;
  final groups = <String>[];
  for (var end = pesos.length; end > 0; end -= 3) {
    groups.insert(0, pesos.substring(end > 3 ? end - 3 : 0, end));
  }
  final decimals = rest == 0 ? '' : ',${rest.toString().padLeft(2, '0')}';
  return '${groups.join('.')}$decimals $currency';
}

/// Fecha y hora local: «02/11/2026 09:30».
String formatDateTime(DateTime date) {
  final local = date.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

/// Una versión de la cotización tal como la guarda ms-services. La vigente
/// se resalta; las anteriores se muestran atenuadas para no confundirlas.
class QuotationCard extends StatelessWidget {
  const QuotationCard({
    super.key,
    required this.quotation,
    this.actions = const [],
    this.compact = false,
  });

  final Quotation quotation;
  final List<Widget> actions;

  /// Versiones anteriores: solo valor, estado y fecha.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final current = quotation.isCurrent;
    final accepted = quotation.status == QuotationStatus.accepted;
    final highlight = current || accepted;
    return Card(
      key: ValueKey('quotation-${quotation.id}'),
      color: FixiaColors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FixiaRadii.card),
        side: BorderSide(
          color: highlight ? FixiaColors.secondary : const Color(0xFFE3E8EF),
          width: highlight ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    quotation.versionLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: FixiaColors.primary,
                    ),
                  ),
                ),
                if (current) ...[
                  const _Tag('Vigente', strong: true),
                  const SizedBox(width: 6),
                ],
                _Tag(quotation.isExpired && !accepted
                    ? 'Vencida'
                    : quotation.statusName),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formatCents(quotation.amountInCents, quotation.currency),
              style: TextStyle(
                fontSize: compact ? 16 : 22,
                fontWeight: FontWeight.w700,
                color: highlight
                    ? FixiaColors.secondary
                    : FixiaColors.textSecondary,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 8),
              _Field('Alcance', quotation.scope),
              _Field('Condiciones', quotation.conditions),
              _Field('Fecha acordada', formatDateTime(quotation.agreedAt)),
              _Field('Válida hasta', formatDateTime(quotation.validUntil)),
            ] else
              Text(
                'Enviada el ${formatDateTime(quotation.createdAt ?? quotation.validUntil)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: FixiaColors.textSecondary,
                ),
              ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: actions[i]),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
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

class _Tag extends StatelessWidget {
  const _Tag(this.label, {this.strong = false});

  final String label;
  final bool strong;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: strong ? FixiaColors.secondary : FixiaColors.supportBackground,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: strong ? FixiaColors.white : FixiaColors.primary,
          ),
        ),
      );
}

/// Versiones ordenadas de la más reciente a la más antigua, separando la
/// vigente (o la aceptada) del historial.
({Quotation? main, List<Quotation> history}) splitVersions(
    List<Quotation> quotations) {
  final sorted = [...quotations]..sort((a, b) {
      final byRevision = (b.revision ?? 0).compareTo(a.revision ?? 0);
      if (byRevision != 0) return byRevision;
      return (b.createdAt ?? b.validUntil)
          .compareTo(a.createdAt ?? a.validUntil);
    });
  Quotation? main;
  for (final q in sorted) {
    if (q.isCurrent || q.status == QuotationStatus.accepted) {
      main = q;
      break;
    }
  }
  return (
    main: main,
    history: [
      for (final q in sorted)
        if (!identical(q, main)) q
    ],
  );
}
