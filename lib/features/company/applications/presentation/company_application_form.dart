import 'package:flutter/material.dart';
import '../../../technician/applications/domain/application_exceptions.dart';
import '../../../technician/applications/domain/service_application.dart';
import '../../../technician/applications/presentation/application_price_form.dart';
import '../application/company_repositories.dart';
import '../domain/company_application_failure.dart';
import 'company_technician_selector.dart';

class CompanyApplicationForm extends StatefulWidget {
  const CompanyApplicationForm(
      {super.key,
      required this.sessionKey,
      required this.serviceRequestId,
      required this.technicians,
      required this.loading,
      required this.repository,
      required this.onRetryTechnicians,
      this.listError,
      this.onSubmitted,
      this.onBusyChanged,
      this.onSessionExpired});
  final String sessionKey;
  final String serviceRequestId;
  final List<CompanyTechnicianOption> technicians;
  final bool loading;
  final String? listError;
  final CompanyApplicationRepository repository;
  final VoidCallback onRetryTechnicians;
  final ValueChanged<ServiceApplication>? onSubmitted;
  final ValueChanged<bool>? onBusyChanged;
  final VoidCallback? onSessionExpired;

  @override
  State<CompanyApplicationForm> createState() => _CompanyApplicationFormState();
}

class _CompanyApplicationFormState extends State<CompanyApplicationForm> {
  String? _selected;
  bool _sending = false;
  bool _locked = false;
  int _generation = 0;
  bool get _selectedValid =>
      !widget.loading &&
      widget.listError == null &&
      _selected != null &&
      widget.technicians.map((t) => t.id).toSet().length ==
          widget.technicians.length &&
      widget.technicians.every((t) => t.id.trim().isNotEmpty) &&
      widget.technicians.any((t) => t.id == _selected && t.eligible != false);

  @override
  void didUpdateWidget(covariant CompanyApplicationForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sessionKey != oldWidget.sessionKey ||
        widget.serviceRequestId != oldWidget.serviceRequestId ||
        widget.repository != oldWidget.repository) {
      _generation++;
      _selected = null;
      _sending = false;
      _locked = false;
    } else if (!_sending && !_locked && _selected != null && !_selectedValid) {
      _generation++;
      _selected = null;
    }
  }

  Future<ProposedPrice> _submit(String input) async {
    final price = ProposedPrice.tryParse(input);
    if (_sending ||
        _locked ||
        !_selectedValid ||
        price == null ||
        validateCompanyPrice(input) != null ||
        widget.sessionKey.trim().isEmpty) {
      throw const ApplicationPriceFormFailure(
          'Selecciona un técnico asociado e ingresa un precio válido.');
    }
    final generation = _generation;
    final technicianId = _selected!;
    setState(() => _sending = true);
    widget.onBusyChanged?.call(true);
    try {
      final saved = await widget.repository.applyCompany(
          widget.serviceRequestId,
          technicianUserId: technicianId,
          price: price);
      if (saved.providerType != ApplicationProviderType.company ||
          saved.technicianId != technicianId ||
          saved.serviceRequest.id != widget.serviceRequestId ||
          saved.proposedPrice?.amount != price.amount) {
        throw const CompanySubmissionUnconfirmed();
      }
      if (mounted && generation == _generation) {
        setState(() => _locked = true);
        widget.onSubmitted?.call(saved);
      }
      return saved.proposedPrice!;
    } on ApplicationFailure catch (failure) {
      if (mounted && generation == _generation) {
        if (failure.isDuplicate ||
            failure is CompanySubmissionUnconfirmed ||
            failure is CompanyApplicationConflict) {
          setState(() => _locked = true);
        }
        if (failure.isSessionExpired) widget.onSessionExpired?.call();
      }
      throw ApplicationPriceFormFailure(failure.fieldErrors.isNotEmpty
          ? failure.fieldErrors.values.join(' ')
          : failure.message);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _sending = false);
        widget.onBusyChanged?.call(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CompanyTechnicianSelector(
              key: ValueKey(_generation),
              technicians: widget.technicians,
              loading: widget.loading,
              error: widget.listError,
              enabled: !_sending && !_locked,
              onRetry: widget.onRetryTechnicians,
              onChanged: (id) {
                if (!_sending && !_locked) setState(() => _selected = id);
              }),
          const SizedBox(height: 16),
          if (_locked)
            const Text(
                'Consulta tus postulaciones para verificar el estado. No envíes otra propuesta para cambiar el técnico o el precio.'),
          AbsorbPointer(
            absorbing:
                !_selectedValid || _locked || widget.sessionKey.trim().isEmpty,
            child: ApplicationPriceForm(
                key: ValueKey(_generation),
                serviceRequestId: widget.serviceRequestId,
                currencyLabel: ProposedPrice.currency,
                validatePrice: validateCompanyPrice,
                submit: _submit),
          ),
        ],
      );
}
