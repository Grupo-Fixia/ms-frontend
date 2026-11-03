import 'package:flutter/material.dart';
import '../../quotations/domain/quotation.dart';
import '../domain/payments.dart';
import 'service_payment_panel.dart';

class CommissionConfirmation extends StatefulWidget {
  const CommissionConfirmation(
      {super.key, required this.quotation, required this.load});
  final Quotation quotation;
  final Future<CommissionQuote> Function(int cents, String currency)? load;
  @override
  State<CommissionConfirmation> createState() => _CommissionConfirmationState();
}

class _CommissionConfirmationState extends State<CommissionConfirmation> {
  late Future<CommissionQuote> _future = _load();
  bool _submitted = false;
  Future<CommissionQuote> _load() async {
    final load = widget.load;
    if (load == null) {
      throw const PaymentsFailure('El desglose de pagos no está disponible.');
    }
    final q = widget.quotation;
    final result = await load(q.amountInCents, q.currency);
    if (!result.matches(q.amountInCents, q.currency)) {
      throw const PaymentsFailure(
          'El desglose no corresponde a esta cotización.');
    }
    return result;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<CommissionQuote>(
      future: _future,
      builder: (context, snapshot) {
        final ready = snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData &&
            !snapshot.hasError;
        final quote = ready ? snapshot.data : null;
        return AlertDialog(
          title: const Text('Aceptar cotización'),
          content: SingleChildScrollView(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.quotation.versionLabel),
              if (snapshot.connectionState != ConnectionState.done)
                const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator()),
              if (snapshot.hasError) ...[
                Text('${snapshot.error}'),
                TextButton(
                    onPressed: () => setState(() {
                          _future = _load();
                        }),
                    child: const Text('Reintentar desglose')),
              ],
              if (quote != null) ...[
                PaymentBreakdown(
                  priceCents: quote.priceCents,
                  commissionCents: quote.commissionCents,
                  totalCents: quote.totalCents,
                  rate: quote.rate,
                  currency: quote.currency,
                  priceLabel: 'Precio del prestador',
                ),
                const SizedBox(height: 12),
                const Text(
                    'Pago virtual. Al contratar se solicitará la retención del total. '
                    'La contratación no confirma por sí sola que el saldo esté retenido.'),
              ],
            ],
          )),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Volver')),
            FilledButton(
                onPressed: ready
                    ? () {
                        if (_submitted) return;
                        _submitted = true;
                        Navigator.pop(context, true);
                      }
                    : null,
                child: const Text('Aceptar y contratar')),
          ],
        );
      });
}
