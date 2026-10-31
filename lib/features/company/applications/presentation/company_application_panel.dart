import 'package:flutter/material.dart';
import '../../../technician/applications/domain/application_exceptions.dart';
import '../../../technician/applications/domain/service_application.dart';
import '../application/company_repositories.dart';
import '../../technicians/presentation/company_technicians_controller.dart';
import '../../technicians/domain/associated_technician.dart';
import 'company_application_form.dart';
import 'company_technician_selector.dart';

class CompanyApplicationPanel extends StatefulWidget {
  const CompanyApplicationPanel(
      {super.key,
      required this.sessionKey,
      required this.serviceRequestId,
      required this.techniciansController,
      required this.applications,
      this.eligibleTechnicianIds,
      this.onBusyChanged,
      required this.onSessionExpired});
  final String sessionKey;
  final String serviceRequestId;
  final CompanyTechniciansController techniciansController;
  final CompanyApplicationRepository applications;
  final Set<String>? eligibleTechnicianIds;
  final ValueChanged<bool>? onBusyChanged;
  final VoidCallback onSessionExpired;

  @override
  State<CompanyApplicationPanel> createState() =>
      _CompanyApplicationPanelState();
}

class _CompanyApplicationPanelState extends State<CompanyApplicationPanel> {
  bool _expiryHandled = false;
  bool get _loading =>
      widget.techniciansController.status == CompanyTechniciansStatus.idle ||
      widget.techniciansController.isLoading;
  String? get _error => widget.techniciansController.errorMessage;
  List<AssociatedTechnician> get _technicians =>
      widget.techniciansController.technicians;
  List<ServiceApplication>? _applications;

  bool _querying = false;

  String? _queryError;
  int _revision = 0;

  String? get _eligibilityError => widget.eligibleTechnicianIds != null &&
          widget.eligibleTechnicianIds!
              .any((id) => !_technicians.any((t) => t.userId == id))
      ? 'La oportunidad y el listado de técnicos no coinciden. Actualiza ambos listados.'
      : null;

  @override
  void initState() {
    super.initState();
    widget.techniciansController.addListener(_onTechniciansChanged);
    if (widget.techniciansController.status == CompanyTechniciansStatus.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  @override
  void didUpdateWidget(covariant CompanyApplicationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sessionKey != oldWidget.sessionKey ||
        widget.serviceRequestId != oldWidget.serviceRequestId ||
        widget.applications != oldWidget.applications ||
        widget.techniciansController != oldWidget.techniciansController) {
      _revision++;
      _applications = null;
      _querying = false;
      _queryError = null;
      _expiryHandled = false;
      if (widget.techniciansController != oldWidget.techniciansController) {
        oldWidget.techniciansController.removeListener(_onTechniciansChanged);
        widget.techniciansController.addListener(_onTechniciansChanged);
      }
      if (widget.techniciansController.status ==
          CompanyTechniciansStatus.idle) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _load();
        });
      }
    }
  }

  String _message(Object error) {
    if (error is ApplicationFailure) {
      if (error.isSessionExpired) widget.onSessionExpired();
      return error.message;
    }
    return 'No pudimos completar la consulta. Inténtalo de nuevo.';
  }

  void _load() {
    widget.techniciansController.load();
  }

  void _onTechniciansChanged() {
    if (!mounted) return;
    if (widget.techniciansController.sessionExpired && !_expiryHandled) {
      _expiryHandled = true;
      widget.onSessionExpired();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.techniciansController.removeListener(_onTechniciansChanged);
    super.dispose();
  }

  Future<void> _query() async {
    if (_querying || widget.sessionKey.trim().isEmpty) return;
    final revision = _revision;
    setState(() {
      _querying = true;
      _applications = null;
      _queryError = null;
    });
    try {
      final items = await widget.applications.listMine();
      if (mounted && revision == _revision) {
        setState(() => _applications = items);
      }
    } catch (error) {
      if (mounted && revision == _revision) {
        final message = _message(error);
        if (mounted) setState(() => _queryError = message);
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _querying = false);
    }
  }

  Future<void> _detail(ServiceApplication item) async {
    if (_querying) return;
    final revision = _revision;
    setState(() => _querying = true);
    try {
      final saved = await widget.applications.getMine(item.id);
      if (!mounted || revision != _revision) return;
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('Postulación empresarial guardada'),
                  content: Text(
                      'Solicitud: ${saved.serviceRequest.id}\nTécnico propuesto: ${saved.technicianId}\nPrecio: ${saved.proposedPrice?.label ?? 'Precio no informado'}\nEstado: ${saved.status.name}'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cerrar'))
                  ]));
    } catch (error) {
      if (mounted && revision == _revision) {
        final message = _message(error);
        if (mounted) setState(() => _queryError = message);
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _querying = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        OutlinedButton(
            onPressed: _loading ? null : _load,
            child: const Text('Actualizar técnicos asociados')),
        CompanyApplicationForm(
            key: ValueKey(_revision),
            sessionKey: widget.sessionKey,
            serviceRequestId: widget.serviceRequestId,
            technicians: [
              for (final item in widget.eligibleTechnicianIds == null
                  ? widget.techniciansController.technicians
                  : widget.techniciansController
                      .eligibleFor(widget.eligibleTechnicianIds!))
                CompanyTechnicianOption(
                    id: item.userId,
                    name: item.name,
                    eligible:
                        widget.eligibleTechnicianIds?.contains(item.userId))
            ],
            loading: _loading,
            listError: _error ?? (_loading ? null : _eligibilityError),
            onBusyChanged: widget.onBusyChanged,
            repository: widget.applications,
            onRetryTechnicians: _load,
            onSessionExpired: widget.onSessionExpired,
            onSubmitted: (_) {
              _query();
            }),
        const SizedBox(height: 20),
        OutlinedButton(
            onPressed: _querying ? null : _query,
            child: const Text('Consultar postulaciones')),
        if (_querying) const Text('Consultando postulaciones…'),
        if (_queryError != null) Text(_queryError!),
        if (_applications != null && _applications!.isEmpty)
          const Text('Tu empresa todavía no tiene postulaciones.'),
        for (final item in _applications ?? <ServiceApplication>[])
          ListTile(
              title: Text(item.proposedPrice?.label ?? 'Precio no informado'),
              subtitle: Text(
                  'Solicitud: ${item.serviceRequest.id}\nTécnico propuesto: ${item.technicianId}'),
              onTap: _querying ? null : () => _detail(item)),
      ]);
}
