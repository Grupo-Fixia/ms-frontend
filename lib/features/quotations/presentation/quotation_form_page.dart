import 'package:flutter/material.dart';

import '../../../core/theme/fixia_theme.dart';
import '../../home/presentation/widgets/dashboard_components.dart';
import '../application/quotation_use_cases.dart';
import '../domain/quotation.dart';
import '../domain/quotation_exceptions.dart';
import '../domain/quotation_rules.dart';
import 'quotation_formatters.dart';

class _MaterialRow {
  final name = TextEditingController();
  final amount = TextEditingController();

  void dispose() {
    name.dispose();
    amount.dispose();
  }
}

/// Formulario para que el técnico seleccionado cotice formalmente una
/// solicitud (GC-355, RF-017): mano de obra, materiales opcionales, fecha
/// estimada de ejecución, vigencia y condiciones.
class QuotationFormPage extends StatefulWidget {
  const QuotationFormPage({
    super.key,
    required this.serviceRequestId,
    required this.sendQuotation,
    this.serviceSummary,
    this.onSent,
    this.onSessionExpired,
    this.onBack,
    this.now,
  });

  final String serviceRequestId;
  final SendQuotation sendQuotation;

  /// Descripción corta de la solicitud que se cotiza.
  final String? serviceSummary;
  final ValueChanged<Quotation>? onSent;
  final VoidCallback? onSessionExpired;
  final VoidCallback? onBack;

  /// Reloj para el rango de fechas (se inyecta en pruebas).
  final DateTime Function()? now;

  @override
  State<QuotationFormPage> createState() => _QuotationFormPageState();
}

class _QuotationFormPageState extends State<QuotationFormPage> {
  final _labor = TextEditingController();
  final _scope = TextEditingController();
  final _conditions = TextEditingController();
  final _materials = <_MaterialRow>[];
  DateTime? _agreedAt;
  DateTime? _validUntil;
  Map<String, String> _errors = {};
  final Map<int, String> _materialErrors = {};
  bool _sending = false;
  String? _formError;
  Quotation? _sentQuotation;

  DateTime get _today => (widget.now ?? DateTime.now)();

  @override
  void dispose() {
    _labor.dispose();
    _scope.dispose();
    _conditions.dispose();
    for (final row in _materials) {
      row.dispose();
    }
    super.dispose();
  }

  int? _totalInCents() {
    final labor = QuotationRules.parseAmount(_labor.text);
    if (labor == null) return null;
    var total = labor;
    for (final row in _materials) {
      if (row.amount.text.trim().isEmpty && row.name.text.trim().isEmpty) {
        continue;
      }
      final amount = QuotationRules.parseAmount(row.amount.text);
      if (amount == null) return null;
      total += amount;
    }
    return total;
  }

  Future<void> _pickDate({required bool agreed}) async {
    final tomorrow = DateTime(_today.year, _today.month, _today.day + 1);
    final picked = await showDatePicker(
      context: context,
      firstDate: tomorrow,
      lastDate: tomorrow.add(const Duration(days: 365)),
      initialDate: (agreed ? _agreedAt : _validUntil) ?? tomorrow,
      helpText: agreed
          ? 'Fecha estimada de ejecución'
          : 'La cotización es válida hasta',
    );
    if (picked == null) return;
    setState(() {
      // La vigencia vence a primera hora y la ejecución al mediodía, así una
      // misma fecha cumple "vigencia no posterior a la fecha acordada".
      if (agreed) {
        _agreedAt = DateTime(picked.year, picked.month, picked.day, 12);
        _errors.remove('agreedAt');
      } else {
        _validUntil = DateTime(picked.year, picked.month, picked.day, 8);
        _errors.remove('validUntil');
      }
    });
  }

  Future<void> _submit() async {
    final materials = <QuotationMaterial>[];
    final materialErrors = <int, String>{};
    for (var i = 0; i < _materials.length; i++) {
      final row = _materials[i];
      final name = row.name.text.trim();
      final text = row.amount.text.trim();
      if (name.isEmpty && text.isEmpty) continue;
      final amount = QuotationRules.parseAmount(text);
      if (name.isEmpty) {
        materialErrors[i] = 'Escribe el nombre del material.';
      } else if (amount == null || amount <= 0) {
        materialErrors[i] = 'Escribe un valor válido.';
      } else {
        materials.add(QuotationMaterial(name: name, amountInCents: amount));
      }
    }
    setState(() {
      _materialErrors
        ..clear()
        ..addAll(materialErrors);
      _formError = null;
    });
    if (materialErrors.isNotEmpty) return;

    setState(() {
      _sending = true;
      _errors = {};
    });
    try {
      final quotation = await widget.sendQuotation(
        NewQuotation(
          serviceRequestId: widget.serviceRequestId,
          amountInCents: _totalInCents(),
          scope: _scope.text,
          conditions: _conditions.text,
          agreedAt: _agreedAt,
          validUntil: _validUntil,
          materials: materials,
        ),
      );
      if (!mounted) return;
      setState(() => _sentQuotation = quotation);
      widget.onSent?.call(quotation);
    } on QuotationFailure catch (failure) {
      if (!mounted) return;
      if (failure.isSessionExpired) widget.onSessionExpired?.call();
      setState(() {
        _errors = failure.fieldErrors;
        _formError = failure.message;
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileFeatureShell(
      title: 'Enviar cotización',
      onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
      child: _sentQuotation != null
          ? _SentConfirmation(
              quotation: _sentQuotation!,
              onDone: widget.onBack ?? () => Navigator.of(context).maybePop(),
            )
          : _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final total = _totalInCents();
    return SingleChildScrollView(
      key: const ValueKey('quotation-form'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Cotización formal', style: theme.textTheme.headlineSmall),
          if (widget.serviceSummary != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.serviceSummary!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: FixiaColors.textSecondary),
            ),
          ],
          const SizedBox(height: 18),
          TextField(
            key: const ValueKey('quotation-labor'),
            controller: _labor,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Mano de obra (COP)',
              prefixText: '\$ ',
              errorText: _errors['amount'],
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Materiales (opcional)',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              TextButton.icon(
                key: const ValueKey('quotation-add-material'),
                onPressed: () => setState(() => _materials.add(_MaterialRow())),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Agregar'),
              ),
            ],
          ),
          for (var i = 0; i < _materials.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      key: ValueKey('quotation-material-name-$i'),
                      controller: _materials[i].name,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Material',
                        errorText: _materialErrors[i] ==
                                'Escribe el nombre del material.'
                            ? _materialErrors[i]
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      key: ValueKey('quotation-material-amount-$i'),
                      controller: _materials[i].amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Valor',
                        prefixText: '\$ ',
                        errorText:
                            _materialErrors[i] == 'Escribe un valor válido.'
                                ? _materialErrors[i]
                                : null,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Quitar material',
                    onPressed: () => setState(() {
                      _materials.removeAt(i).dispose();
                      _materialErrors.clear();
                    }),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          DashboardCard(
            child: Row(
              children: [
                const Expanded(child: Text('Total de la cotización')),
                Text(
                  key: const ValueKey('quotation-total'),
                  total == null ? '—' : formatMoney(total),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: FixiaColors.secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _DateField(
            fieldKey: const ValueKey('quotation-agreed-at'),
            label: 'Fecha estimada de ejecución',
            value: _agreedAt,
            errorText: _errors['agreedAt'],
            onTap: () => _pickDate(agreed: true),
          ),
          const SizedBox(height: 14),
          _DateField(
            fieldKey: const ValueKey('quotation-valid-until'),
            label: 'Válida hasta',
            value: _validUntil,
            errorText: _errors['validUntil'],
            onTap: () => _pickDate(agreed: false),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('quotation-scope'),
            controller: _scope,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Alcance del trabajo',
              alignLabelWithHint: true,
              errorText: _errors['scope'],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('quotation-conditions'),
            controller: _conditions,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Condiciones',
              alignLabelWithHint: true,
              errorText: _errors['conditions'],
            ),
          ),
          if (_formError != null) ...[
            const SizedBox(height: 12),
            Text(
              _formError!,
              key: const ValueKey('quotation-form-error'),
              style: const TextStyle(color: FixiaColors.error),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey('quotation-submit'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
            onPressed: _sending ? null : _submit,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(_sending ? 'Enviando…' : 'Enviar cotización'),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.onTap,
    this.errorText,
  });

  final Key fieldKey;
  final String label;
  final DateTime? value;
  final String? errorText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: fieldKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(FixiaRadii.input),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child:
            Text(value == null ? 'Selecciona una fecha' : formatDate(value!)),
      ),
    );
  }
}

class _SentConfirmation extends StatelessWidget {
  const _SentConfirmation({required this.quotation, required this.onDone});

  final Quotation quotation;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: const ValueKey('quotation-sent'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.mark_email_read_outlined,
              size: 56, color: FixiaColors.accent),
          const SizedBox(height: 14),
          Text('Cotización enviada', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Total ${formatMoney(quotation.amountInCents)}. El cliente la '
            'revisará y te avisaremos si la acepta o la rechaza.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const ValueKey('quotation-sent-done'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
            onPressed: onDone,
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }
}
