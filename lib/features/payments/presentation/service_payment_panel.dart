import 'package:flutter/material.dart';
import '../../../core/widgets/fixia_ui.dart';
import '../../quotations/presentation/quotation_card.dart';
import '../domain/payments.dart';
import 'wallet_page.dart';
import '../../../core/theme/fixia_theme.dart';

class ServicePaymentPanel extends StatefulWidget {
  const ServicePaymentPanel(
      {super.key,
      required this.load,
      this.loadWallet,
      this.retryHold,
      this.serviceClosed = false,
      required this.isClient,
      this.topUp,
      this.onError,
      this.openTopUp});
  final Future<ServicePayment?> Function() load;
  final Future<Wallet> Function()? loadWallet;
  final bool isClient;
  final Future<Wallet> Function(int)? topUp;
  final ValueChanged<Object>? onError;
  final Future<ServicePayment> Function(String)? retryHold;
  final bool serviceClosed;
  final Future<void> Function()? openTopUp;
  @override
  State<ServicePaymentPanel> createState() => _ServicePaymentPanelState();
}

class _ServicePaymentPanelState extends State<ServicePaymentPanel> {
  ServicePayment? _payment;
  Wallet? _wallet;
  Object? _error, _walletError;
  bool _refreshing = false;
  bool _operating = false;
  bool _openingTopUp = false;
  int _loadVersion = 0;
  bool get _busy => _refreshing || _operating;
  bool _paymentFresh = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant ServicePaymentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serviceClosed != widget.serviceClosed) {
      _refresh(supersede: true);
    }
  }

  Future<void> _refresh({bool supersede = false}) async {
    if (_refreshing && !supersede) return;
    final version = ++_loadVersion;
    bool isCurrent() => mounted && version == _loadVersion;
    final load = widget.load;
    final loadWallet = widget.loadWallet;
    setState(() {
      _refreshing = true;
      _paymentFresh = false;
      _error = null;
      _wallet = null;
      _walletError = null;
    });
    try {
      final payment = await load();
      if (!isCurrent()) return;
      setState(() {
        _payment = payment;
        _paymentFresh = true;
      });
      if (widget.isClient &&
          payment?.isWalletPayment == true &&
          loadWallet != null) {
        try {
          final wallet = await loadWallet();
          if (isCurrent()) setState(() => _wallet = wallet);
        } catch (error) {
          if (isCurrent()) setState(() => _walletError = error);
        }
      }
    } catch (error) {
      if (isCurrent()) {
        widget.onError?.call(error);
        if (!isCurrent()) return;
        setState(() {
          _payment = null;
          _error = error;
        });
      }
    } finally {
      if (isCurrent()) setState(() => _refreshing = false);
    }
  }

  Future<void> _retry() async {
    final payment = _payment;
    if (_busy ||
        !_paymentFresh ||
        payment == null ||
        !widget.isClient ||
        widget.retryHold == null ||
        !payment.canRetryHold ||
        widget.serviceClosed) return;
    setState(() {
      _operating = true;
      _paymentFresh = false;
    });
    Object? error;
    try {
      await widget.retryHold!(payment.id);
    } catch (failure) {
      error = failure;
    }
    if (!mounted) return;
    await _refresh(supersede: true);
    if (mounted) {
      setState(() {
        _operating = false;
        if (error != null) _error = error;
      });
    }
  }

  Future<void> _topUp() async {
    if (_busy || !widget.isClient || widget.serviceClosed) return;
    setState(() {
      _operating = true;
      _openingTopUp = true;
    });
    try {
      if (widget.openTopUp != null) {
        await widget.openTopUp!();
      } else if (widget.topUp != null && widget.loadWallet != null) {
        final wallet = await widget.loadWallet!();
        if (!mounted) return;
        final missing = (_payment?.amountCents ?? 0) - wallet.availableCents;
        await showDialog<bool>(
            context: context,
            builder: (_) => WalletAmountDialog(
                topUp: true,
                availableCents: wallet.availableCents,
                currency: wallet.currency,
                suggestedCents:
                    wallet.currency == _payment?.currency && missing > 0
                        ? missing
                        : null,
                submit: widget.topUp!,
                onError: widget.onError));
      }
    } catch (error) {
      widget.onError?.call(error);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
    if (mounted) {
      await _refresh(supersede: true);
      if (mounted) {
        setState(() {
          _operating = false;
          _openingTopUp = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final payment = _payment;
    final wallet = _wallet;
    final insufficient = payment?.isWalletPayment == true &&
        payment?.status == PaymentStatus.failed &&
        wallet != null &&
        wallet.currency == payment!.currency &&
        wallet.availableCents < payment.amountCents;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle(title: 'Pago del servicio'),
      FixiaPanel(
          key: const ValueKey('service-payment'),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (widget.serviceClosed) const Text('Servicio cerrado.'),
            if (_busy && !_openingTopUp) const LinearProgressIndicator(),
            if (_error != null) Text('$_error'),
            if (!_busy && _paymentFresh && payment == null)
              const Text(
                  key: ValueKey('service-payment-missing'),
                  'El pago aún no está disponible para consulta. Actualiza su estado.'),
            if (payment != null) ...[
              Text(payment.label,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(payment.label == payment.confirmedHoldStatus.label
                  ? 'Se cobra cuando se confirme el cierre del servicio.'
                  : payment.confirmedHoldStatus.label),
              if (payment.breakdown case final breakdown?)
                PaymentBreakdown(
                  priceCents: breakdown.priceCents,
                  commissionCents: breakdown.commissionCents,
                  totalCents: breakdown.totalCents,
                  rate: breakdown.commissionRate,
                  currency: payment.currency,
                  priceLabel: 'Precio del prestador',
                )
              else ...[
                Text(
                    'Total del pago: ${formatCents(payment.amountCents, payment.currency)}'),
                if (payment.isWalletPayment)
                  const Text('El desglose de este pago no está disponible.'),
              ],
              if (widget.serviceClosed &&
                  payment.status != PaymentStatus.completed &&
                  payment.status != PaymentStatus.refunded)
                const Text(
                    'El cierre está confirmado, pero el pago no está completado. '
                    'Actualiza para comprobar su estado.'),
              if (payment.failureReason?.isNotEmpty == true)
                Text(payment.failureReason!),
            ],
            if (wallet != null) ...[
              const SizedBox(height: 12),
              Text(
                  'Saldo disponible de tu billetera: ${formatCents(wallet.availableCents, wallet.currency)}'),
              Text(
                  'Saldo retenido global: ${formatCents(wallet.heldCents, wallet.currency)}'),
              const Text('Estos saldos incluyen todos tus servicios.'),
            ],
            if (_walletError != null)
              Text('No pudimos actualizar el saldo: $_walletError'),
            if (insufficient)
              const Text(
                  'El saldo disponible es inferior al importe de este pago.'),
            if (payment?.isWalletPayment == true &&
                payment?.status == PaymentStatus.failed &&
                !payment!.canRetryHold)
              const Text(
                  'El reintento de retención no está disponible para este pago.'),
            if (payment?.isWalletPayment == true &&
                payment?.status == PaymentStatus.failed &&
                widget.isClient &&
                widget.openTopUp == null &&
                widget.topUp == null &&
                !widget.serviceClosed)
              const Text(
                  'La recarga virtual todavía no está disponible desde esta pantalla.'),
            Wrap(spacing: 12, runSpacing: 8, children: [
              TextButton(
                  key: const ValueKey('service-payment-reload'),
                  onPressed: _busy ? null : _refresh,
                  child: const Text('Actualizar pago')),
              if (widget.isClient &&
                  widget.retryHold != null &&
                  payment?.canRetryHold == true &&
                  !widget.serviceClosed)
                OutlinedButton(
                    key: const ValueKey('service-payment-retry'),
                    onPressed: _busy || !_paymentFresh ? null : _retry,
                    child: const Text('Reintentar retención')),
              if (payment?.isWalletPayment == true &&
                  payment?.status == PaymentStatus.failed &&
                  widget.isClient &&
                  (widget.openTopUp != null ||
                      (widget.topUp != null && widget.loadWallet != null)) &&
                  !widget.serviceClosed)
                TextButton(
                    key: const ValueKey('service-payment-topup'),
                    onPressed: _busy ? null : _topUp,
                    child: const Text('Recargar saldo')),
            ]),
          ])),
      const SizedBox(height: 20),
    ]);
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
