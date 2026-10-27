import 'package:flutter/material.dart';
import '../domain/proposed_price.dart';

/// Captura reutilizable para la postulación existente.
/// Las reglas de precio las aporta el modelo aprobado y el contrato de GC-423.
/// submit debe resolver solo cuando Backend confirma la postulación.
class ApplicationPriceForm extends StatefulWidget {
  const ApplicationPriceForm({
    super.key,
    required this.serviceRequestId,
    required this.currencyLabel,
    required this.validatePrice,
    required this.submit,
  });

  final String serviceRequestId;
  final String currencyLabel;
  final FormFieldValidator<String> validatePrice;

  /// Texto de entrada, aún sin transformar en un campo JSON.
  final Future<ProposedPrice> Function(String priceInput) submit;

  @override
  State<ApplicationPriceForm> createState() => _ApplicationPriceFormState();
}

class _ApplicationPriceFormState extends State<ApplicationPriceForm> {
  final _form = GlobalKey<FormState>();
  final _price = TextEditingController();
  bool _sending = false;
  bool _sent = false;
  ProposedPrice? _confirmedPrice;
  String? _error;
  int _revision = 0;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ApplicationPriceForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.serviceRequestId != oldWidget.serviceRequestId) {
      _revision++;
      _sending = false;
      _sent = false;
      _confirmedPrice = null;
      _error = null;
      _form.currentState?.reset();
      _price.clear();
    }
  }

  Future<void> _submit() async {
    if (_sending ||
        _sent ||
        widget.serviceRequestId.trim().isEmpty ||
        !(_form.currentState?.validate() ?? false)) {
      return;
    }
    final revision = _revision;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final price = await widget.submit(_price.text.trim());
      if (mounted && revision == _revision) {
        setState(() {
          _sent = true;
          _confirmedPrice = price;
        });
      }
    } catch (error) {
      if (mounted && revision == _revision) {
        setState(() => _error = error is ApplicationPriceFormFailure
            ? error.message
            : 'No pudimos enviar la postulación. Revisa su estado antes de reintentar.');
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_sending,
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('application-price'),
                controller: _price,
                enabled: !_sending && !_sent,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Precio propuesto *',
                  suffixText: widget.currencyLabel,
                  helperText:
                      'Sin separadores de miles; usa coma para decimales.',
                  helperMaxLines: 2,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ingresa el precio que propones.'
                    : widget.validatePrice(value),
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 8),
              const Text(
                  'Este precio es una propuesta. No confirma una contratación ni un pago.'),
              const SizedBox(height: 12),
              if (_error != null)
                Text(_error!, key: const ValueKey('application-price-error')),
              if (_sending)
                const LinearProgressIndicator(
                    key: ValueKey('application-price-sending')),
              if (_sent)
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Postulación enviada.',
                      key: ValueKey('application-price-confirmed')),
                  Text('Precio confirmado: ${_confirmedPrice!.label}'),
                ])
              else
                FilledButton(
                  key: const ValueKey('application-price-submit'),
                  onPressed: _sending || widget.serviceRequestId.trim().isEmpty
                      ? null
                      : _submit,
                  child: const Text('Enviar postulación'),
                ),
            ],
          ),
        ),
      );
}

/// El adaptador de presentación traduce errores conocidos, sin exponer respuestas
/// internas. Conflictos/401/403 se resuelven conforme al contrato vigente.
class ApplicationPriceFormFailure implements Exception {
  const ApplicationPriceFormFailure(this.message);
  final String message;
}
