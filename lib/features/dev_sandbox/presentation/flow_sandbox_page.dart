import 'package:flutter/material.dart';

import '../../../core/theme/fixia_theme.dart';
import '../../client/service_requests/application/provider_profile_use_cases.dart';
import '../../client/service_requests/application/service_request_use_cases.dart';
import '../../client/service_requests/domain/service_request.dart';
import '../../client/service_requests/infrastructure/mock_provider_profile_repository.dart';
import '../../client/service_requests/infrastructure/mock_service_request_repository.dart';
import '../../client/service_requests/presentation/applicants_page.dart';
import '../../home/presentation/widgets/dashboard_components.dart';
import '../../quotations/application/quotation_use_cases.dart';
import '../../quotations/domain/quotation.dart';
import '../../quotations/infrastructure/mock_quotation_repository.dart';
import '../../quotations/presentation/quotation_detail_page.dart';
import '../../quotations/presentation/quotation_form_page.dart';
import '../../quotations/presentation/quotation_formatters.dart';
import '../../technician/applications/application/application_use_cases.dart';
import '../../technician/applications/infrastructure/mock_application_repository.dart';
import '../../technician/opportunities/presentation/technician_opportunities_page.dart';

/// Herramienta de desarrollo: recorre en una sola sesión el flujo
/// postulación → postulantes → selección → cotización → decisión
/// (GC-344, GC-349, GC-350, GC-355 y GC-360) alternando entre el rol técnico
/// y el cliente, siempre con datos locales (sin red ni sesión).
class FlowSandboxPage extends StatefulWidget {
  const FlowSandboxPage({super.key, this.onBack, this.latency});

  final VoidCallback? onBack;

  /// Latencia simulada de la postulación (en pruebas, cero).
  final Duration? latency;

  @override
  State<FlowSandboxPage> createState() => _FlowSandboxPageState();
}

class _FlowSandboxPageState extends State<FlowSandboxPage> {
  static const _requestId = MockServiceRequestRepository.demoRequestId;
  static const _summary = 'Fuga en el lavaplatos';

  late MockServiceRequestRepository _requests;
  late MockApplicationRepository _applications;
  late MockQuotationRepository _quotations;
  late MockProviderProfileRepository _profiles;

  bool _applied = false;
  ServiceRequest? _request;
  Quotation? _quotation;

  bool get _selected =>
      _request?.selectedProviderId == demoTechnicianProviderId;
  bool get _otherSelected => _request?.selectedProviderId != null && !_selected;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    _requests = MockServiceRequestRepository.demo();
    _profiles = MockProviderProfileRepository();
    _quotations = MockQuotationRepository(providerId: demoTechnicianProviderId);
    _applications = MockApplicationRepository(
      latency: widget.latency ?? const Duration(milliseconds: 300),
      onApplied: (application) {
        _requests.addApplicant(
          application.serviceRequest.id,
          demoTechnicianProviderId,
        );
        if (mounted) setState(() => _applied = true);
      },
    );
    _applied = false;
    _request = null;
    _quotation = null;
  }

  Future<void> _open(WidgetBuilder builder) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: builder));
    await _refreshQuotation();
  }

  Future<void> _refreshQuotation() async {
    final all = await _quotations.listForRequest(_requestId);
    final active =
        all.where((q) => q.status != QuotationStatus.superseded).toList();
    if (!mounted) return;
    setState(() => _quotation = active.isEmpty ? null : active.first);
  }

  void _openApply() => _open(
        (context) => TechnicianOpportunitiesPage(
          applyToServiceRequest: ApplyToServiceRequest(_applications),
          onBack: () => Navigator.of(context).pop(),
        ),
      );

  void _openApplicants() => _open(
        (context) => ApplicantsPage(
          requestId: _requestId,
          listApplicants: ListApplicants(_requests),
          selectProvider: SelectProvider(_requests),
          getProfile: GetProviderPublicProfile(_profiles),
          onProviderSelected: (request) => setState(() => _request = request),
          onBack: () => Navigator.of(context).pop(),
        ),
      );

  void _openQuotationForm() => _open(
        (context) => QuotationFormPage(
          serviceRequestId: _requestId,
          serviceSummary: _summary,
          sendQuotation: SendQuotation(_quotations),
          onSent: (quotation) => setState(() => _quotation = quotation),
          onBack: () => Navigator.of(context).pop(),
        ),
      );

  void _openQuotationDecision() => _open(
        (context) => QuotationDetailPage(
          serviceRequestId: _requestId,
          serviceSummary: _summary,
          providerName: 'Carlos Ramírez',
          listQuotations: ListRequestQuotations(_quotations),
          acceptQuotation: AcceptQuotation(_quotations),
          rejectQuotation: RejectQuotation(_quotations),
          onBack: () => Navigator.of(context).pop(),
        ),
      );

  Future<void> _expire() async {
    final quotation = _quotation;
    if (quotation == null) return;
    _quotations.expire(quotation.id);
    await _refreshQuotation();
  }

  @override
  Widget build(BuildContext context) {
    final quotation = _quotation;
    final decided = quotation != null && !quotation.isOpen;
    return MobileFeatureShell(
      title: 'Flujo E2E (desarrollo)',
      onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
      child: ListView(
        key: const ValueKey('flow-sandbox'),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          Text(
            'Recorre el flujo completo con datos locales. Sigue los pasos en '
            'orden; cada uno abre la pantalla real del rol indicado.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: FixiaColors.textSecondary),
          ),
          const SizedBox(height: 16),
          _StepCard(
            keyName: 'step-apply',
            number: 1,
            role: 'Técnico',
            title: 'Postularse a la solicitud (GC-344)',
            description: 'Abre «$_summary» y toca Postularse.',
            done: _applied,
            enabled: true,
            actionLabel: 'Abrir solicitudes',
            onPressed: _openApply,
          ),
          _StepCard(
            keyName: 'step-applicants',
            number: 2,
            role: 'Cliente',
            title: 'Revisar postulantes, ver perfil y seleccionar '
                '(GC-349/350)',
            description: _otherSelected
                ? 'Seleccionaste a otro prestador: reinicia y elige a '
                    'Carlos Ramírez para continuar el flujo.'
                : 'Consulta el perfil público y selecciona a Carlos Ramírez.',
            done: _selected,
            enabled: _applied,
            actionLabel: 'Ver postulantes',
            onPressed: _openApplicants,
          ),
          _StepCard(
            keyName: 'step-quotation',
            number: 3,
            role: 'Técnico',
            title: 'Enviar cotización (GC-355)',
            description:
                'Diligencia mano de obra, materiales, fecha y condiciones.',
            done: quotation != null,
            enabled: _selected,
            actionLabel: quotation == null ? 'Crear cotización' : 'Reenviar',
            onPressed: _openQuotationForm,
          ),
          _StepCard(
            keyName: 'step-decision',
            number: 4,
            role: 'Cliente',
            title: 'Aceptar o rechazar la cotización (GC-360)',
            description: decided
                ? 'Estado actual: ${quotationStatusText(quotation)}.'
                : 'Revisa el desglose y decide.',
            done: decided,
            enabled: quotation != null,
            actionLabel: 'Ver cotización',
            onPressed: _openQuotationDecision,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('sandbox-expire'),
            onPressed: quotation != null && quotation.isOpen ? _expire : null,
            icon: const Icon(Icons.timer_off_outlined),
            label: const Text('Simular vencimiento de la cotización'),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            key: const ValueKey('sandbox-reset'),
            onPressed: () => setState(_reset),
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reiniciar flujo'),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.keyName,
    required this.number,
    required this.role,
    required this.title,
    required this.description,
    required this.done,
    required this.enabled,
    required this.actionLabel,
    required this.onPressed,
  });

  final String keyName;
  final int number;
  final String role;
  final String title;
  final String description;
  final bool done;
  final bool enabled;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DashboardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      done ? Colors.green.shade600 : FixiaColors.primary,
                  child: done
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Text('$number',
                          style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 10),
                Chip(
                  label: Text(role),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              description,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: FixiaColors.textSecondary),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                key: ValueKey(keyName),
                onPressed: enabled ? onPressed : null,
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
