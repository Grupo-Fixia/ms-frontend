import 'package:flutter/material.dart';

import '../../../core/theme/fixia_theme.dart';
import '../../../core/widgets/fixia_ui.dart';
import '../../quotations/presentation/quotation_card.dart';
import '../domain/payments.dart';
import 'wallet_page.dart';

/// Pago de un servicio contratado (GC-491): cuánto se retuvo, en qué va y,
/// si al cliente le faltó saldo, recargar y reintentar desde aquí.
class ServicePaymentPanel extends StatefulWidget {
  const ServicePaymentPanel({
    super.key,
    required this.load,
    required this.isClient,
    this.retryHold,
    this.loadWallet,
    this.topUp,
    this.onError,
  });

  /// `null` si todavía no hay pago registrado (llega por eventos en unos
  /// segundos).
  final Future<ServicePayment?> Function() load;
  final bool isClient;
  final Future<ServicePayment> Function(String paymentId)? retryHold;
  final Future<Wallet> Function()? loadWallet;
  final Future<Wallet> Function(int amountCents)? topUp;
  final ValueChanged<Object>? onError;

  @override
  State<ServicePaymentPanel> createState() => _ServicePaymentPanelState();
}

class _ServicePaymentPanelState extends State<ServicePaymentPanel> {
  late Future<ServicePayment?> _payment = widget.load();
  bool _busy = false;
  String? _retryError;

  void _reload() => setState(() {
        // El error lo muestra el FutureBuilder; se marca como atendido para
        // que no se reporte antes de que lo escuche.
        _payment = widget.load()..ignore();
      });

  Future<void> _retry(ServicePayment payment) async {
    final retry = widget.retryHold;
    if (retry == null || _busy) return;
    setState(() {
      _busy = true;
      _retryError = null;
    });
    try {
      final updated = await retry(payment.id);
      if (!mounted) return;
      setState(() => _payment = Future.value(updated));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(updated.holdStatus == HoldStatus.held
            ? 'Listo: el pago quedó retenido.'
            : updated.failureReason ?? 'Todavía no se pudo retener el pago.'),
      ));
    } catch (error) {
      widget.onError?.call(error);
      if (mounted) setState(() => _retryError = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _topUpAndRetry(ServicePayment payment) async {
    final topUp = widget.topUp;
    final loadWallet = widget.loadWallet;
    if (topUp == null || loadWallet == null) return;
    Wallet wallet;
    try {
      wallet = await loadWallet();
    } catch (error) {
      widget.onError?.call(error);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
      return;
    }
    if (!mounted) return;
    final missing = (payment.totalCents ?? 0) - wallet.availableCents;
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => WalletAmountDialog(
        topUp: true,
        availableCents: wallet.availableCents,
        currency: wallet.currency,
        suggestedCents: missing > 0 ? missing : null,
        submit: topUp,
        onError: widget.onError,
      ),
    );
    if (done == true && mounted) await _retry(payment);
  }

  @override
  Widget build(BuildContext context) => FixiaPanel(
        key: const ValueKey('service-payment'),
        child: FutureBuilder<ServicePayment?>(
          future: _payment,
          builder: (context, snapshot) {
            final header = Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    color: FixiaColors.secondary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Pago del servicio',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: FixiaColors.primary,
                    ),
                  ),
                ),
                if (snapshot.data case final p?)
                  StatusPill(
                    key: const ValueKey('service-payment-status'),
                    label: p.holdStatus.label,
                    tone: switch (p.holdStatus) {
                      HoldStatus.held ||
                      HoldStatus.captured =>
                        PillTone.success,
                      HoldStatus.failed => PillTone.warning,
                      _ => PillTone.neutral,
                    },
                  ),
              ],
            );
            if (snapshot.connectionState != ConnectionState.done) {
              return Column(children: [header, const SectionLoading()]);
            }
            if (snapshot.hasError) {
              widget.onError?.call(snapshot.error!);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header,
                  const SizedBox(height: 8),
                  Text('${snapshot.error}',
                      style: const TextStyle(color: FixiaColors.textSecondary)),
                  TextButton(
                    key: const ValueKey('service-payment-reload'),
                    onPressed: _reload,
                    child: const Text('Reintentar'),
                  ),
                ],
              );
            }
            final payment = snapshot.data;
            if (payment == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header,
                  const SizedBox(height: 8),
                  const Text(
                    'Estamos registrando el pago de esta contratación; tarda unos segundos.',
                    key: ValueKey('service-payment-missing'),
                    style: TextStyle(color: FixiaColors.textSecondary),
                  ),
                  TextButton(
                    key: const ValueKey('service-payment-reload'),
                    onPressed: _reload,
                    child: const Text('Actualizar'),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: 12),
                PaymentBreakdown(
                  priceCents: payment.priceCents,
                  commissionCents: payment.commissionCents,
                  totalCents: payment.totalCents,
                  rate: payment.rate,
                  currency: payment.currency,
                  priceLabel:
                      widget.isClient ? 'Precio del técnico' : 'Lo que recibes',
                ),
                const SizedBox(height: 12),
                Text(
                  _message(payment),
                  key: const ValueKey('service-payment-message'),
                  style: const TextStyle(color: FixiaColors.textSecondary),
                ),
                if (_retryError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _retryError!,
                    key: const ValueKey('service-payment-retry-error'),
                    style: const TextStyle(color: FixiaColors.error),
                  ),
                ],
                if (widget.isClient &&
                    payment.holdStatus == HoldStatus.failed &&
                    payment.canRetryHold) ...[
                  const SizedBox(height: 12),
                  ActionBar(actions: [
                    OutlinedButton(
                      key: const ValueKey('service-payment-retry'),
                      onPressed: _busy ? null : () => _retry(payment),
                      child: const Text('Reintentar pago'),
                    ),
                    if (widget.topUp != null && widget.loadWallet != null)
                      FilledButton(
                        key: const ValueKey('service-payment-topup'),
                        onPressed: _busy ? null : () => _topUpAndRetry(payment),
                        child: const Text('Recargar y pagar'),
                      ),
                  ]),
                ],
              ],
            );
          },
        ),
      );

  String _message(ServicePayment p) {
    final total =
        p.totalCents == null ? '' : formatCents(p.totalCents!, p.currency);
    final price =
        p.priceCents == null ? '' : formatCents(p.priceCents!, p.currency);
    if (widget.isClient) {
      return switch (p.holdStatus) {
        HoldStatus.held =>
          'Retuvimos $total de tu billetera. El técnico lo recibe cuando confirmes el cierre.',
        HoldStatus.failed => p.failureReason ??
            'No pudimos retener el pago. Recarga tu billetera y reintenta.',
        HoldStatus.captured =>
          'Pagado: el técnico recibió $price y Fixia su comisión.',
        HoldStatus.released => 'Se liberó lo retenido y volvió a tu saldo.',
        HoldStatus.reversed => 'Se revirtió el pago y volvió a tu saldo.',
        HoldStatus.pending => 'Estamos reteniendo el pago en tu billetera.',
        HoldStatus.notApplicable =>
          'Este servicio no se paga con la billetera.',
      };
    }
    return switch (p.holdStatus) {
      HoldStatus.held =>
        'El pago del cliente está retenido. Recibirás $price en tu billetera cuando confirme el cierre.',
      HoldStatus.failed =>
        'El cliente todavía no tiene saldo para retener el pago.',
      HoldStatus.captured => 'Recibiste $price en tu billetera.',
      HoldStatus.released ||
      HoldStatus.reversed =>
        'El pago de este servicio se devolvió al cliente.',
      HoldStatus.pending => 'El pago del cliente se está procesando.',
      HoldStatus.notApplicable => 'Este servicio no se paga con la billetera.',
    };
  }
}

/// Precio, comisión de Fixia y total.
class PaymentBreakdown extends StatelessWidget {
  const PaymentBreakdown({
    super.key,
    required this.priceCents,
    required this.commissionCents,
    required this.totalCents,
    this.rate,
    this.currency = 'COP',
    this.priceLabel = 'Precio del técnico',
  });

  final int? priceCents;
  final int? commissionCents;
  final int? totalCents;
  final double? rate;
  final String currency;
  final String priceLabel;

  @override
  Widget build(BuildContext context) {
    String show(int? cents) =>
        cents == null ? '–' : formatCents(cents, currency);
    final percent = rate == null
        ? ''
        : ' (${CommissionQuote(priceCents: 0, commissionCents: 0, totalCents: 0, rate: rate!).ratePercent})';
    Widget row(String label, String value, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: strong
                        ? FixiaColors.primary
                        : FixiaColors.textSecondary,
                    fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                  fontSize: strong ? 17 : 14,
                  color: strong ? FixiaColors.secondary : FixiaColors.primary,
                ),
              ),
            ],
          ),
        );
    return Container(
      key: const ValueKey('payment-breakdown'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FixiaColors.supportBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          row(priceLabel, show(priceCents)),
          row('Comisión de Fixia$percent', show(commissionCents)),
          const Divider(height: 14),
          row('Total del cliente', show(totalCents), strong: true),
        ],
      ),
    );
  }
}

/// Desglose antes de aceptar una cotización (GC-491) y si el saldo alcanza.
class CommissionPreview extends StatefulWidget {
  const CommissionPreview({
    super.key,
    required this.priceCents,
    required this.quote,
    this.loadWallet,
  });

  final int priceCents;
  final Future<CommissionQuote> Function(int priceCents) quote;
  final Future<Wallet> Function()? loadWallet;

  @override
  State<CommissionPreview> createState() => _CommissionPreviewState();
}

class _CommissionPreviewState extends State<CommissionPreview> {
  late final Future<(CommissionQuote, Wallet?)> _data = () async {
    final quote = await widget.quote(widget.priceCents);
    Wallet? wallet;
    try {
      wallet = await widget.loadWallet?.call();
    } catch (_) {
      wallet = null;
    }
    return (quote, wallet);
  }();

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<(CommissionQuote, Wallet?)>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox.shrink();
          }
          if (snapshot.hasError) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'No pudimos calcular la comisión en este momento.',
                key: ValueKey('commission-preview-error'),
                style: TextStyle(color: FixiaColors.textSecondary),
              ),
            );
          }
          final (quote, wallet) = snapshot.data!;
          final short =
              wallet != null && wallet.availableCents < quote.totalCents;
          return Padding(
            key: const ValueKey('commission-preview'),
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Si aceptas, pagarás',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: FixiaColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                PaymentBreakdown(
                  priceCents: quote.priceCents,
                  commissionCents: quote.commissionCents,
                  totalCents: quote.totalCents,
                  rate: quote.rate,
                  currency: quote.currency,
                ),
                const SizedBox(height: 8),
                const Text(
                  'El total se retiene de tu billetera al aceptar y el técnico lo recibe cuando confirmes el cierre.',
                  style: TextStyle(
                    fontSize: 12,
                    color: FixiaColors.textSecondary,
                  ),
                ),
                if (wallet != null) ...[
                  const SizedBox(height: 8),
                  NoticeBanner(
                    key: const ValueKey('commission-preview-balance'),
                    message: short
                        ? 'Tu saldo disponible es ${formatCents(wallet.availableCents, wallet.currency)}: no alcanza. Puedes aceptar y recargar después, o recargar antes en Billetera.'
                        : 'Tu saldo disponible (${formatCents(wallet.availableCents, wallet.currency)}) alcanza para este servicio.',
                    tone: short ? PillTone.warning : PillTone.success,
                    icon: short
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline_rounded,
                  ),
                ],
              ],
            ),
          );
        },
      );
}
