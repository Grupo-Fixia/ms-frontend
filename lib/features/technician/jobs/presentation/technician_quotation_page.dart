import 'package:flutter/material.dart';

import '../../../../core/theme/fixia_theme.dart';
import '../../../quotations/domain/quotation.dart';
import '../../../quotations/domain/quotation_exceptions.dart';
import '../../../quotations/domain/quotation_rules.dart';
import '../../../quotations/presentation/quotation_card.dart';
import '../../applications/domain/service_application.dart';

/// El técnico seleccionado envía la cotización formal y la ajusta con
/// nuevas versiones (GC-428, API de GC-354/GC-427). Cada envío crea una
/// versión en ms-services y la anterior queda reemplazada; aquí no se
/// cambia nada solo en memoria.
class TechnicianQuotationPage extends StatefulWidget {
  const TechnicianQuotationPage({
    super.key,
    required this.application,
    required this.load,
    required this.send,
    this.now,
  });

  final ServiceApplication application;

  /// Mis cotizaciones de esta solicitud.
  final Future<List<Quotation>> Function() load;
  final Future<Quotation> Function(NewQuotation quotation) send;
  final DateTime Function()? now;

  @override
  State<TechnicianQuotationPage> createState() =>
      _TechnicianQuotationPageState();
}

class _TechnicianQuotationPageState extends State<TechnicianQuotationPage> {
  late Future<List<Quotation>> _quotations = widget.load();
  bool _editing = false;

  void _reload() => setState(() {
        _quotations = widget.load();
      });

  @override
  Widget build(BuildContext context) {
    final request = widget.application.serviceRequest;
    return Scaffold(
      backgroundColor: FixiaColors.neutralBackground,
      appBar: AppBar(title: const Text('Cotización')),
      body: FutureBuilder<List<Quotation>>(
        future: _quotations,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${snapshot.error}', textAlign: TextAlign.center),
                  TextButton(
                    onPressed: _reload,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          final versions = splitVersions(snapshot.data!);
          final main = versions.main;
          final accepted = main?.status == QuotationStatus.accepted;
          final showForm = !accepted && (_editing || main == null);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${request.category.label} · ${request.zone}, ${request.city}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: FixiaColors.primary,
                ),
              ),
              if (widget.application.proposedPrice != null)
                Text(
                  'Precio que propusiste al postularte: ${widget.application.proposedPrice!.label}',
                  style: const TextStyle(color: FixiaColors.textSecondary),
                ),
              const SizedBox(height: 12),
              if (accepted)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'El cliente aceptó esta cotización: el servicio quedó contratado. Lo ves en Servicios contratados.',
                    style: TextStyle(color: FixiaColors.accent),
                  ),
                ),
              if (main != null) QuotationCard(quotation: main),
              if (main != null && !accepted && !_editing)
                OutlinedButton.icon(
                  onPressed: () => setState(() => _editing = true),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Ajustar cotización (nueva versión)'),
                ),
              if (showForm)
                QuotationForm(
                  serviceRequestId: request.id,
                  base: main,
                  expectedAt: request.expectedAt,
                  now: widget.now ?? DateTime.now,
                  send: widget.send,
                  onSent: () {
                    setState(() => _editing = false);
                    _reload();
                  },
                  onCancel: main == null
                      ? null
                      : () => setState(() => _editing = false),
                ),
              if (versions.history.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Versiones anteriores',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                for (final q in versions.history)
                  QuotationCard(quotation: q, compact: true),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Formulario de la cotización. Valida con [QuotationRules] antes de
/// enviar y muestra los errores por campo que devuelva el backend.
class QuotationForm extends StatefulWidget {
  const QuotationForm({
    super.key,
    required this.serviceRequestId,
    required this.send,
    required this.onSent,
    required this.now,
    this.base,
    this.expectedAt,
    this.onCancel,
  });

  final String serviceRequestId;
  final Future<Quotation> Function(NewQuotation quotation) send;
  final VoidCallback onSent;
  final DateTime Function() now;

  /// Versión vigente: el ajuste parte de sus datos.
  final Quotation? base;
  final DateTime? expectedAt;
  final VoidCallback? onCancel;

  @override
  State<QuotationForm> createState() => _QuotationFormState();
}

class _QuotationFormState extends State<QuotationForm> {
  late final _amount = TextEditingController(
    text: widget.base == null ? '' : _plainAmount(widget.base!.amountInCents),
  );
  late final _scope = TextEditingController(text: widget.base?.scope ?? '');
  late final _conditions =
      TextEditingController(text: widget.base?.conditions ?? '');
  late DateTime _agreedAt = _initialAgreedAt();
  late DateTime _validUntil = _initialValidUntil();
  Map<String, String> _errors = const {};
  String? _message;
  bool _sending = false;

  static String _plainAmount(int cents) =>
      cents % 100 == 0 ? '${cents ~/ 100}' : (cents / 100).toStringAsFixed(2);

  DateTime _initialAgreedAt() {
    final now = widget.now();
    final base = widget.base?.agreedAt.toLocal();
    if (base != null && base.isAfter(now)) return base;
    final expected = widget.expectedAt?.toLocal();
    if (expected != null &&
        expected.isAfter(now.add(const Duration(hours: 2)))) {
      return expected;
    }
    final tomorrow = now.add(const Duration(days: 2));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9);
  }

  DateTime _initialValidUntil() {
    final now = widget.now();
    final dayAfter = now.add(const Duration(days: 1));
    final beforeService = _agreedAt.subtract(const Duration(hours: 1));
    return dayAfter.isBefore(beforeService) ? dayAfter : beforeService;
  }

  @override
  void dispose() {
    _amount.dispose();
    _scope.dispose();
    _conditions.dispose();
    super.dispose();
  }

  Future<void> _pickAgreedAt() async {
    final now = widget.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _agreedAt,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_agreedAt),
    );
    if (!mounted) return;
    setState(() {
      _agreedAt = DateTime(date.year, date.month, date.day,
          time?.hour ?? _agreedAt.hour, time?.minute ?? _agreedAt.minute);
    });
  }

  Future<void> _pickValidUntil() async {
    final now = widget.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _validUntil,
      firstDate: now,
      lastDate: _agreedAt.isAfter(now) ? _agreedAt : now,
    );
    if (date == null || !mounted) return;
    setState(() {
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59);
      _validUntil = endOfDay.isAfter(_agreedAt) ? _agreedAt : endOfDay;
    });
  }

  Future<void> _submit() async {
    if (_sending) return;
    final quotation = NewQuotation(
      serviceRequestId: widget.serviceRequestId,
      amountInCents: QuotationRules.parseAmount(_amount.text),
      scope: _scope.text,
      conditions: _conditions.text,
      agreedAt: _agreedAt.toUtc(),
      validUntil: _validUntil.toUtc(),
    );
    final errors = QuotationRules.validate(quotation, now: widget.now());
    if (errors.isNotEmpty) {
      setState(() {
        _errors = errors;
        _message = 'Revisa los datos marcados.';
      });
      return;
    }
    setState(() {
      _sending = true;
      _errors = const {};
      _message = null;
    });
    try {
      final sent = await widget.send(quotation);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${sent.versionLabel} enviada al cliente.'),
      ));
      widget.onSent();
    } on QuotationFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _errors = failure.fieldErrors;
        _message = failure.message;
      });
    } catch (error) {
      if (mounted) setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        color: FixiaColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FixiaRadii.card),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.base == null
                    ? 'Enviar cotización formal'
                    : 'Nueva versión de la cotización',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: FixiaColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('quotation-amount'),
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Valor (COP)',
                  hintText: 'Ej. 145000',
                  errorText: _errors['amount'],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('quotation-scope'),
                controller: _scope,
                maxLines: 3,
                maxLength: QuotationRules.textMaxLength,
                decoration: InputDecoration(
                  labelText: 'Alcance del trabajo',
                  errorText: _errors['scope'],
                ),
              ),
              TextField(
                key: const ValueKey('quotation-conditions'),
                controller: _conditions,
                maxLines: 3,
                maxLength: QuotationRules.textMaxLength,
                decoration: InputDecoration(
                  labelText: 'Condiciones (materiales, garantía…)',
                  errorText: _errors['conditions'],
                ),
              ),
              _DateField(
                label: 'Fecha acordada',
                value: formatDateTime(_agreedAt),
                error: _errors['agreedAt'],
                onTap: _pickAgreedAt,
              ),
              _DateField(
                label: 'Válida hasta',
                value: formatDateTime(_validUntil),
                error: _errors['validUntil'],
                onTap: _pickValidUntil,
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _message!,
                    style: const TextStyle(color: FixiaColors.error),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _sending ? null : _submit,
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.base == null
                        ? 'Enviar cotización'
                        : 'Enviar nueva versión'),
              ),
              if (widget.onCancel != null)
                TextButton(
                  onPressed: _sending ? null : widget.onCancel,
                  child: const Text('Cancelar'),
                ),
            ],
          ),
        ),
      );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.error,
  });

  final String label;
  final String value;
  final String? error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: InkWell(
          onTap: onTap,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              errorText: error,
              suffixIcon: const Icon(Icons.event_outlined),
            ),
            child: Text(value),
          ),
        ),
      );
}
