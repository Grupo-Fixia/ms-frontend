import 'package:flutter/material.dart';
import '../../../core/widgets/fixia_ui.dart';
import '../../quotations/presentation/quotation_card.dart';
import '../domain/payment.dart';

class ServicePaymentSection extends StatefulWidget {
  const ServicePaymentSection(
      {super.key,
      required this.load,
      required this.loadWallet,
      required this.retryHold,
      required this.serviceClosed,
      this.openTopUp});
  final Future<ServicePayment?> Function() load;
  final Future<WalletBalance> Function() loadWallet;
  final Future<ServicePayment> Function(ServicePayment) retryHold;
  final bool serviceClosed;
  final Future<void> Function()? openTopUp;
  @override
  State<ServicePaymentSection> createState() => _ServicePaymentSectionState();
}

class _ServicePaymentSectionState extends State<ServicePaymentSection> {
  ServicePayment? _payment;
  WalletBalance? _wallet;
  Object? _error, _walletError;
  bool _refreshing = false;
  bool _operating = false;
  int _loadVersion = 0;
  bool get _busy => _refreshing || _operating;
  bool _paymentFresh = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant ServicePaymentSection oldWidget) {
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
      if (payment?.isWalletPayment == true) {
        try {
          final wallet = await loadWallet();
          if (isCurrent()) setState(() => _wallet = wallet);
        } catch (error) {
          if (isCurrent()) setState(() => _walletError = error);
        }
      }
    } catch (error) {
      if (isCurrent()) {
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
        !payment.canRetryHold ||
        widget.serviceClosed) return;
    setState(() {
      _operating = true;
      _paymentFresh = false;
    });
    Object? error;
    try {
      await widget.retryHold(payment);
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
    if (_busy || widget.openTopUp == null) return;
    setState(() => _operating = true);
    try {
      await widget.openTopUp!();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
    if (mounted) {
      await _refresh(supersede: true);
      if (mounted) setState(() => _operating = false);
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
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.serviceClosed) const Text('Servicio cerrado.'),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) Text('$_error'),
        if (!_busy && _paymentFresh && payment == null)
          const Text(
              'El pago aún no está disponible para consulta. Actualiza su estado.'),
        if (payment != null) ...[
          Text(payment.label,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(
              'Total del pago: ${formatCents(payment.amountCents, payment.currency)}'),
          Text(payment.confirmedHoldStatus.label),
          if (payment.breakdown case final breakdown?) ...[
            Text(
                'Precio del prestador: ${formatCents(breakdown.priceCents, payment.currency)}'),
            Text(
                'Comisión Fixia: ${formatCents(breakdown.commissionCents, payment.currency)}'),
          ] else if (payment.isWalletPayment)
            const Text('El desglose de este pago no está disponible.'),
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
            widget.openTopUp == null &&
            !widget.serviceClosed)
          const Text(
              'La recarga virtual todavía no está disponible desde esta pantalla.'),
        Wrap(spacing: 12, runSpacing: 8, children: [
          TextButton(
              onPressed: _busy ? null : _refresh,
              child: const Text('Actualizar pago')),
          if (payment?.canRetryHold == true && !widget.serviceClosed)
            OutlinedButton(
                onPressed: _busy || !_paymentFresh ? null : _retry,
                child: const Text('Reintentar retención')),
          if (payment?.isWalletPayment == true &&
              payment?.status == PaymentStatus.failed &&
              widget.openTopUp != null &&
              !widget.serviceClosed)
            TextButton(
                onPressed: _busy ? null : _topUp,
                child: const Text('Recargar saldo')),
        ]),
      ])),
      const SizedBox(height: 20),
    ]);
  }
}
