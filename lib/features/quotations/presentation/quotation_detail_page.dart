import 'package:flutter/material.dart';

import '../../../core/theme/fixia_theme.dart';
import '../../home/presentation/widgets/dashboard_components.dart';
import '../application/quotation_use_cases.dart';
import '../domain/quotation.dart';
import '../domain/quotation_exceptions.dart';
import '../domain/quotation_rules.dart';
import 'quotation_formatters.dart';

/// Cotización recibida por el cliente (GC-355): desglose económico,
/// condiciones e información del servicio.
class QuotationDetailPage extends StatefulWidget {
  const QuotationDetailPage({
    super.key,
    required this.serviceRequestId,
    required this.listQuotations,
    this.serviceSummary,
    this.providerName,
    this.acceptQuotation,
    this.rejectQuotation,
    this.onSessionExpired,
    this.onBack,
  });

  final String serviceRequestId;
  final ListRequestQuotations listQuotations;

  /// Descripción corta del servicio solicitado.
  final String? serviceSummary;
  final String? providerName;

  /// Si se envían ambos, el cliente puede aceptar o rechazar (GC-360).
  final AcceptQuotation? acceptQuotation;
  final RejectQuotation? rejectQuotation;
  final VoidCallback? onSessionExpired;
  final VoidCallback? onBack;

  @override
  State<QuotationDetailPage> createState() => _QuotationDetailPageState();
}

class _QuotationDetailPageState extends State<QuotationDetailPage> {
  Quotation? _quotation;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final quotations = await widget.listQuotations(widget.serviceRequestId);
      if (!mounted) return;
      setState(() {
        // La más reciente primero; las reemplazadas no se muestran.
        _quotation = quotations
            .where((q) => q.status != QuotationStatus.superseded)
            .firstOrNull;
        _loading = false;
      });
    } on QuotationFailure catch (failure) {
      if (!mounted) return;
      if (failure.isSessionExpired) widget.onSessionExpired?.call();
      setState(() {
        _error = failure.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileFeatureShell(
      title: 'Cotización',
      onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    final quotation = _quotation;
    if (quotation == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'El prestador aún no ha enviado su cotización.',
            key: ValueKey('quotation-empty'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return SingleChildScrollView(
      key: const ValueKey('quotation-detail'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuotationSummary(
            quotation: quotation,
            serviceSummary: widget.serviceSummary,
            providerName: widget.providerName,
          ),
          const SizedBox(height: 20),
          _buildDecision(context, quotation),
        ],
      ),
    );
  }

  Widget _buildDecision(BuildContext context, Quotation quotation) {
    final canDecide =
        widget.acceptQuotation != null && widget.rejectQuotation != null;
    if (quotation.isOpen && canDecide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              key: const ValueKey('quotation-accept'),
              onPressed: _busy ? null : () => _accept(quotation),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Aceptar Cotización'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              key: const ValueKey('quotation-reject'),
              onPressed: _busy ? null : () => _reject(quotation),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Rechazar Cotización'),
            ),
          ),
        ],
      );
    }
    final next = _nextStep(quotation);
    if (next == null) return const SizedBox.shrink();
    return DashboardCard(
      child: Row(
        key: const ValueKey('quotation-next-step'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.flag_outlined, color: FixiaColors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(next)),
        ],
      ),
    );
  }

  String? _nextStep(Quotation quotation) {
    if (quotation.status == QuotationStatus.accepted) {
      return 'Cotización aceptada. Siguiente paso: coordina con el prestador '
          'la ejecución del servicio para la fecha acordada.';
    }
    if (quotation.status == QuotationStatus.rejected &&
        quotation.counterOfferInCents != null) {
      return 'Contraoferta enviada. Siguiente paso: el prestador debe aceptarla '
          'o enviarte una nueva cotización.';
    }
    if (quotation.status == QuotationStatus.rejected) {
      return 'Cotización rechazada. Siguiente paso: puedes esperar una nueva '
          'cotización del prestador o elegir a otro postulante.';
    }
    if (quotation.status == QuotationStatus.expired || quotation.isExpired) {
      return 'La cotización venció. Siguiente paso: pide al prestador que '
          'envíe una nueva cotización vigente.';
    }
    return null;
  }

  Future<void> _accept(Quotation quotation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('accept-dialog'),
        title: const Text('¿Aceptar la cotización?'),
        content: Text(
          'Aceptarás ${formatMoney(quotation.amountInCents)} por el '
          'servicio descrito.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('accept-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _decide(() => widget.acceptQuotation!(quotation.id));
  }

  Future<void> _reject(Quotation quotation) async {
    final reasonController = TextEditingController();
    final counterController = TextEditingController();
    final result = await showDialog<({String reason, int? counter})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final counter = QuotationRules.parseAmount(counterController.text);
          final counterText = counterController.text.trim();
          final counterInvalid =
              counterText.isNotEmpty && (counter == null || counter <= 0);
          final canCounter = counter != null && counter > 0;
          return AlertDialog(
            key: const ValueKey('reject-dialog'),
            title: const Text('Responder la cotización'),
            scrollable: true,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const ValueKey('reject-reason'),
                  controller: reasonController,
                  maxLines: 3,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Motivo (opcional)',
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Contraoferta',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Si prefieres negociar, propón un valor total al prestador '
                  'en lugar de rechazar sin más. Cotización actual: '
                  '${formatMoney(quotation.amountInCents)}.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey('counter-offer-amount'),
                  controller: counterController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Valor de la contraoferta (COP)',
                    prefixText: '\$ ',
                    errorText: counterInvalid
                        ? 'Ingresa un valor mayor a cero.'
                        : null,
                  ),
                ),
              ],
            ),
            actionsOverflowDirection: VerticalDirection.down,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                key: const ValueKey('reject-confirm'),
                onPressed: () => Navigator.of(context)
                    .pop((reason: reasonController.text, counter: null)),
                child: const Text('Rechazar'),
              ),
              FilledButton(
                key: const ValueKey('counter-offer-confirm'),
                onPressed: canCounter
                    ? () => Navigator.of(context)
                        .pop((reason: reasonController.text, counter: counter))
                    : null,
                child: const Text('Enviar contraoferta'),
              ),
            ],
          );
        },
      ),
    );
    if (result == null) return;
    await _decide(
      () => widget.rejectQuotation!(
        quotation.id,
        reason: result.reason,
        counterOfferInCents: result.counter,
      ),
    );
  }

  Future<void> _decide(Future<Quotation> Function() action) async {
    setState(() => _busy = true);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() {
        _quotation = updated;
        _busy = false;
      });
    } on QuotationFailure catch (failure) {
      if (!mounted) return;
      if (failure.isSessionExpired) widget.onSessionExpired?.call();
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

/// Contenido de la cotización: servicio, desglose, fechas y condiciones.
class QuotationSummary extends StatelessWidget {
  const QuotationSummary({
    super.key,
    required this.quotation,
    this.serviceSummary,
    this.providerName,
  });

  final Quotation quotation;
  final String? serviceSummary;
  final String? providerName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                providerName == null
                    ? 'Cotización recibida'
                    : 'Cotización de $providerName',
                style: theme.textTheme.titleLarge,
              ),
            ),
            QuotationStatusChip(quotation: quotation),
          ],
        ),
        if (serviceSummary != null) ...[
          const SizedBox(height: 8),
          Text(
            serviceSummary!,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: FixiaColors.textSecondary),
          ),
        ],
        const SizedBox(height: 18),
        DashboardCard(
          child: Column(
            key: const ValueKey('quotation-breakdown'),
            children: [
              _AmountRow(
                label: 'Mano de obra',
                cents: quotation.laborInCents,
              ),
              for (final material in quotation.materials)
                _AmountRow(
                  label: material.name,
                  cents: material.amountInCents,
                ),
              const Divider(height: 24),
              _AmountRow(
                label: 'Total',
                cents: quotation.amountInCents,
                emphasized: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _InfoBlock(
          icon: Icons.event_available_outlined,
          title: 'Fecha estimada de ejecución',
          text: formatDate(quotation.agreedAt),
        ),
        _InfoBlock(
          icon: Icons.timer_outlined,
          title: 'Válida hasta',
          text: formatDate(quotation.validUntil),
        ),
        _InfoBlock(
          icon: Icons.handyman_outlined,
          title: 'Alcance del trabajo',
          text: quotation.scope,
        ),
        _InfoBlock(
          icon: Icons.rule_folder_outlined,
          title: 'Condiciones',
          text: quotation.conditions,
        ),
        if (quotation.counterOfferInCents != null)
          _InfoBlock(
            icon: Icons.price_change_outlined,
            title: 'Contraoferta enviada',
            text: '${formatMoney(quotation.counterOfferInCents!)}. Queda a la '
                'espera de que el prestador responda.',
          ),
        if (quotation.rejectionReason != null &&
            quotation.rejectionReason!.isNotEmpty)
          _InfoBlock(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Motivo del rechazo',
            text: quotation.rejectionReason!,
          ),
      ],
    );
  }
}

/// Estado de la cotización con color: enviada, aceptada, rechazada o
/// vencida.
class QuotationStatusChip extends StatelessWidget {
  const QuotationStatusChip({super.key, required this.quotation});

  final Quotation quotation;

  @override
  Widget build(BuildContext context) {
    final expired =
        quotation.status == QuotationStatus.expired || quotation.isExpired;
    final color = expired
        ? FixiaColors.textSecondary
        : switch (quotation.status) {
            QuotationStatus.accepted => FixiaColors.accent,
            QuotationStatus.rejected => FixiaColors.error,
            QuotationStatus.sent => FixiaColors.secondary,
            _ => FixiaColors.textSecondary,
          };
    return Container(
      key: const ValueKey('quotation-status'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        quotationStatusText(quotation).toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.cents,
    this.emphasized = false,
  });

  final String label;
  final int cents;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
              color: FixiaColors.secondary,
              fontWeight: FontWeight.w800,
            )
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(formatMoney(cents), style: style),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: FixiaColors.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(text),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
