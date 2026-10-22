import 'package:flutter/material.dart';

import '../../../core/theme/fixia_theme.dart';
import '../../home/presentation/widgets/dashboard_components.dart';
import '../application/quotation_use_cases.dart';
import '../domain/quotation.dart';
import '../domain/quotation_exceptions.dart';
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
    this.onSessionExpired,
    this.onBack,
  });

  final String serviceRequestId;
  final ListRequestQuotations listQuotations;

  /// Descripción corta del servicio solicitado.
  final String? serviceSummary;
  final String? providerName;
  final VoidCallback? onSessionExpired;
  final VoidCallback? onBack;

  @override
  State<QuotationDetailPage> createState() => _QuotationDetailPageState();
}

class _QuotationDetailPageState extends State<QuotationDetailPage> {
  Quotation? _quotation;
  bool _loading = true;
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
      child: QuotationSummary(
        quotation: quotation,
        serviceSummary: widget.serviceSummary,
        providerName: widget.providerName,
      ),
    );
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
