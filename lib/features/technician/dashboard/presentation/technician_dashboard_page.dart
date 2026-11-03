import 'package:flutter/material.dart';

import '../../../../core/layout/app_shell.dart';
import '../../../../core/theme/fixia_theme.dart';
import '../../../../core/widgets/fixia_ui.dart';
import '../../../contracts/domain/service_contract.dart';
import '../../../quotations/presentation/quotation_card.dart';
import '../../applications/domain/service_application.dart';
import '../../opportunities/domain/service_opportunity.dart';
import '../../profile/domain/verification_status.dart';

/// Trabajo real del técnico (GC-428, GC-429, GC-442): solicitudes donde lo
/// seleccionaron y aún no hay contrato, y sus contrataciones.
class TechnicianWork {
  const TechnicianWork({required this.toQuote, required this.contracts});

  final List<ServiceApplication> toQuote;
  final List<ServiceContract> contracts;

  /// Contratados, en ejecución o esperando el cierre del cliente.
  List<ServiceContract> get active => [
        for (final c in contracts)
          if (c.serviceStatus != null && !c.serviceStatus!.isTerminal) c,
      ];

  int get closed => contracts
      .where((c) => c.serviceStatus == ServiceRequestStatus.closed)
      .length;
}

/// Inicio del técnico: resumen de su trabajo, oportunidades compatibles y
/// lo que tiene pendiente. Todo sale de ms-services y ms-users.
class TechnicianDashboardPage extends StatefulWidget {
  const TechnicianDashboardPage({
    super.key,
    this.firstName,
    this.verificationStatus = VerificationStatus.pending,
    this.onOpenSettings,
    this.onLogout,
    this.onOpenOpportunities,
    this.onOpenJobs,
    this.onOpenSpecialties,
    this.onOpenChat,
    this.onApplyToOpportunity,
    this.onOpenAvailability,
    this.onOpenQuotation,
    this.onOpenContract,
    this.loadOpportunities,
    this.loadWork,
  });

  final String? firstName;
  final VerificationStatus verificationStatus;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onLogout;
  final VoidCallback? onOpenOpportunities;

  /// «Mis trabajos»: cotizaciones y servicios contratados (GC-428, GC-429).
  final VoidCallback? onOpenJobs;
  final VoidCallback? onOpenSpecialties;

  /// Abre el chat prototipo (simulación, GC-431).
  final VoidCallback? onOpenChat;
  final ValueChanged<String>? onApplyToOpportunity;
  final VoidCallback? onOpenAvailability;

  /// Abre la cotización de una solicitud donde lo seleccionaron.
  final Future<void> Function(ServiceApplication application)? onOpenQuotation;

  /// Abre una contratación.
  final Future<void> Function(ServiceContract contract)? onOpenContract;

  /// Solicitudes compatibles reales (GC-340). Sin conexión es `null` y no
  /// se muestran oportunidades de ejemplo.
  final Future<List<ServiceOpportunity>> Function()? loadOpportunities;

  /// Postulaciones seleccionadas y contrataciones. Sin conexión es `null`.
  final Future<TechnicianWork> Function()? loadWork;

  /// Oportunidades que se muestran en el inicio; el resto en la pantalla de
  /// oportunidades.
  static const opportunitiesLimit = 4;

  /// Trabajos que se muestran en el inicio.
  static const jobsLimit = 4;

  @override
  State<TechnicianDashboardPage> createState() =>
      _TechnicianDashboardPageState();
}

class _TechnicianDashboardPageState extends State<TechnicianDashboardPage> {
  late Future<List<ServiceOpportunity>>? _opportunities =
      widget.loadOpportunities?.call();
  late Future<TechnicianWork>? _work = widget.loadWork?.call();

  void _reloadOpportunities() => setState(() {
        _opportunities = widget.loadOpportunities?.call();
      });

  void _reloadWork() => setState(() {
        _work = widget.loadWork?.call();
      });

  Future<void> _openAndReload(Future<void> Function() open) async {
    await open();
    if (!mounted) return;
    _reloadWork();
    _reloadOpportunities();
  }

  void _showProfileMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Inicia sesión como técnico para ver tu perfil.'),
      ),
    );
  }

  void _navigate(ShellDestination destination) {
    final scope = FixiaShellScope.maybeOf(context);
    final VoidCallback? own = switch (destination) {
      ShellDestination.technicianOpportunities => widget.onOpenOpportunities,
      ShellDestination.technicianJobs => widget.onOpenJobs,
      ShellDestination.technicianProfile => widget.onOpenSettings,
      _ => null,
    };
    if (own != null) return own();
    if (scope?.onNavigate != null) return scope!.onNavigate!(destination);
    if (destination == ShellDestination.technicianProfile) {
      _showProfileMessage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.firstName?.trim() ?? '';
    final status = widget.verificationStatus;
    return AppShell(
      destination: ShellDestination.technicianHome,
      userName: name.isEmpty ? null : name,
      userCaption: status.label,
      onNavigate: _navigate,
      onLogout: widget.onLogout,
      child: FutureBuilder<TechnicianWork>(
        future: _work,
        builder: (context, workSnapshot) {
          final work = workSnapshot.hasData ? workSnapshot.data : null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: name.isEmpty ? 'Técnico' : 'Hola, $name',
                titleKey: const ValueKey('technician-dashboard-greeting'),
                subtitle: work == null
                    ? 'Tu panel de trabajo en Fixia.'
                    : _subtitle(work),
                actions: [
                  _VerificationBadge(status: status),
                  OutlinedButton.icon(
                    key: const ValueKey('technician-dashboard-settings'),
                    onPressed: widget.onOpenSettings ?? _showProfileMessage,
                    icon: const Icon(Icons.badge_outlined, size: 18),
                    label: const Text('Perfil profesional'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _VerificationBanner(status: status),
              const SizedBox(height: 20),
              StatGrid(
                minItemWidth: 180,
                children: [
                  StatCard(
                    label: 'Por cotizar',
                    value: work == null ? '–' : '${work.toQuote.length}',
                    emphasis: true,
                  ),
                  StatCard(
                    label: 'En curso',
                    value: work == null ? '–' : '${work.active.length}',
                  ),
                  StatCard(
                    label: 'Cerrados',
                    value: work == null ? '–' : '${work.closed}',
                  ),
                ],
              ),
              const SizedBox(height: 28),
              TwoColumns(
                sideWidth: 360,
                main: _opportunitiesSection(),
                side: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _jobsSection(workSnapshot),
                    const SizedBox(height: 20),
                    _QuickLinks(
                      onOpenSpecialties: widget.onOpenSpecialties,
                      onOpenAvailability: widget.onOpenAvailability,
                      onOpenChat: widget.onOpenChat,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _subtitle(TechnicianWork work) {
    final quote = work.toQuote.length;
    final active = work.active.length;
    if (quote == 0 && active == 0) {
      return 'No tienes pendientes. Revisa las oportunidades para postularte.';
    }
    final parts = <String>[
      if (quote > 0)
        quote == 1
            ? '1 cotización por enviar'
            : '$quote cotizaciones por enviar',
      if (active > 0)
        active == 1 ? '1 servicio en curso' : '$active servicios en curso',
    ];
    return 'Tienes ${parts.join(' y ')}.';
  }

  Widget _opportunitiesSection() {
    final future = _opportunities;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          title: 'Oportunidades para ti',
          action: TextButton(
            key: const ValueKey('technician-see-opportunities'),
            onPressed: widget.onOpenOpportunities,
            child: const Text('Ver todas'),
          ),
        ),
        if (future == null)
          const EmptyState(
            message:
                'Las oportunidades aparecerán aquí cuando te conectes a Fixia.',
            icon: Icons.cloud_off_outlined,
          )
        else
          FutureBuilder<List<ServiceOpportunity>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SectionLoading();
              }
              if (snapshot.hasError) {
                return EmptyState(
                  message: '${snapshot.error}',
                  icon: Icons.error_outline_rounded,
                  action: TextButton(
                    onPressed: _reloadOpportunities,
                    child: const Text('Reintentar'),
                  ),
                );
              }
              final items = snapshot.data!
                  .take(TechnicianDashboardPage.opportunitiesLimit)
                  .toList();
              if (items.isEmpty) {
                return const EmptyState(
                  message:
                      'No hay solicitudes compatibles con tus especialidades y zona en este momento.',
                  icon: Icons.search_off_rounded,
                );
              }
              return ResponsiveGrid(
                minItemWidth: 260,
                children: [
                  for (final o in items)
                    _OpportunityCard(
                      opportunity: o,
                      onApply: () => widget.onApplyToOpportunity != null
                          ? widget.onApplyToOpportunity!(o.id)
                          : widget.onOpenOpportunities?.call(),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _jobsSection(AsyncSnapshot<TechnicianWork> snapshot) {
    Widget body;
    if (_work == null) {
      body = const EmptyState(
        message: 'Tus trabajos aparecerán aquí cuando te conectes a Fixia.',
        icon: Icons.cloud_off_outlined,
      );
    } else if (snapshot.connectionState != ConnectionState.done) {
      body = const SectionLoading();
    } else if (snapshot.hasError) {
      body = EmptyState(
        message: '${snapshot.error}',
        icon: Icons.error_outline_rounded,
        action: TextButton(
          onPressed: _reloadWork,
          child: const Text('Reintentar'),
        ),
      );
    } else {
      final work = snapshot.data!;
      final cards = <Widget>[
        for (final a in work.toQuote)
          _JobCard(
            key: ValueKey('technician-home-quote-${a.id}'),
            eyebrow: 'TE ELIGIERON',
            highlight: true,
            title:
                '${a.serviceRequest.category.label} · ${a.serviceRequest.zone}',
            detail: a.proposedPrice == null
                ? 'Envía tu cotización formal'
                : 'Propusiste ${a.proposedPrice!.label}',
            action: 'Enviar cotización',
            onTap: widget.onOpenQuotation == null
                ? null
                : () => _openAndReload(() => widget.onOpenQuotation!(a)),
          ),
        for (final c in work.active)
          _JobCard(
            key: ValueKey('technician-home-contract-${c.id}'),
            eyebrow: (c.serviceStatus?.label ?? 'Contratado').toUpperCase(),
            title: '${c.request.category.label} · ${c.request.description}',
            detail:
                '${formatCents(c.amountInCents, c.currency)} · ${formatDateTime(c.agreedAt)}',
            action: 'Ver contrato',
            onTap: widget.onOpenContract == null
                ? null
                : () => _openAndReload(() => widget.onOpenContract!(c)),
          ),
      ].take(TechnicianDashboardPage.jobsLimit).toList();
      body = cards.isEmpty
          ? const EmptyState(
              message:
                  'Cuando un cliente te seleccione o te contrate, aparecerá aquí.',
              icon: Icons.work_outline_rounded,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final card in cards) ...[
                  card,
                  const SizedBox(height: 12),
                ],
              ],
            );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          title: 'Mis trabajos',
          action: TextButton(
            key: const ValueKey('technician-open-jobs'),
            onPressed: widget.onOpenJobs,
            child: const Text('Ver todos'),
          ),
        ),
        body,
      ],
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  const _VerificationBadge({required this.status});

  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      VerificationStatus.pending => ('PENDIENTE', PillTone.warning),
      VerificationStatus.valid => ('VIGENTE', PillTone.success),
      VerificationStatus.rejected => ('RECHAZADA', PillTone.warning),
      VerificationStatus.expired => ('VENCIDA', PillTone.warning),
    };
    return Padding(
      key: const ValueKey('technician-verification-badge'),
      padding: const EdgeInsets.only(top: 8),
      child: StatusPill(label: label, tone: tone),
    );
  }
}

class _VerificationBanner extends StatelessWidget {
  const _VerificationBanner({required this.status});

  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final (message, tone) = switch (status) {
      VerificationStatus.pending => (
          'Tu cuenta está en proceso de verificación. Los clientes verán este estado al comparar tu propuesta.',
          PillTone.warning
        ),
      VerificationStatus.valid => (
          'Tu cuenta está verificada. Ya puedes postularte a nuevas oportunidades.',
          PillTone.success
        ),
      VerificationStatus.rejected => (
          'Tu verificación fue rechazada. Revisa tus documentos para continuar.',
          PillTone.warning
        ),
      VerificationStatus.expired => (
          'Tu verificación está vencida. Actualiza tus documentos para postularte.',
          PillTone.warning
        ),
    };
    return NoticeBanner(
      key: const ValueKey('technician-verification-banner'),
      message: message,
      tone: tone,
      icon: status == VerificationStatus.pending
          ? Icons.hourglass_top_rounded
          : Icons.info_outline_rounded,
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({required this.opportunity, required this.onApply});

  final ServiceOpportunity opportunity;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) => FixiaPanel(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: StatusPill(label: opportunity.category.label),
                ),
                const SizedBox(width: 8),
                const Spacer(),
                Flexible(
                  child: Text(
                    opportunity.postedLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 12,
                      color: FixiaColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              opportunity.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              '${opportunity.approximateLocation} · ${opportunity.expectedMoment}',
              style: const TextStyle(
                fontSize: 13,
                color: FixiaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Presupuesto',
                        style: TextStyle(
                          fontSize: 11,
                          color: FixiaColors.textSecondary,
                        ),
                      ),
                      Text(
                        opportunity.budget,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: FixiaColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  key: ValueKey('technician-apply-${opportunity.id}'),
                  onPressed: onApply,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  child: const Text('Postularme'),
                ),
              ],
            ),
          ],
        ),
      );
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.detail,
    required this.action,
    required this.onTap,
    this.highlight = false,
  });

  final String eyebrow;
  final String title;
  final String detail;
  final String action;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) => FixiaPanel(
        padding: const EdgeInsets.all(16),
        highlight: highlight ? FixiaColors.secondary : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color:
                    highlight ? FixiaColors.secondary : const Color(0xFF00745F),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: const TextStyle(
                fontSize: 13,
                color: FixiaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            if (highlight)
              FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                child: Text(action),
              )
            else
              OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                child: Text(action),
              ),
          ],
        ),
      );
}

class _QuickLinks extends StatelessWidget {
  const _QuickLinks({
    required this.onOpenSpecialties,
    required this.onOpenAvailability,
    required this.onOpenChat,
  });

  final VoidCallback? onOpenSpecialties;
  final VoidCallback? onOpenAvailability;
  final VoidCallback? onOpenChat;

  @override
  Widget build(BuildContext context) {
    if (onOpenSpecialties == null &&
        onOpenAvailability == null &&
        onOpenChat == null) {
      return const SizedBox.shrink();
    }
    return FixiaPanel(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onOpenSpecialties != null)
            _link(
              key: 'technician-open-specialties',
              icon: Icons.tune_rounded,
              label: 'Editar especialidades',
              onTap: onOpenSpecialties,
            ),
          if (onOpenAvailability != null)
            _link(
              key: 'technician-open-availability',
              icon: Icons.edit_calendar_rounded,
              label: 'Horario y zona de atención',
              onTap: onOpenAvailability,
            ),
          if (onOpenChat != null)
            _link(
              key: 'technician-open-chat-prototype',
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Chat de demostración',
              onTap: onOpenChat,
            ),
        ],
      ),
    );
  }

  Widget _link({
    required String key,
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) =>
      TextButton.icon(
        key: ValueKey(key),
        onPressed: onTap,
        icon: Icon(icon, size: 19),
        label: Align(alignment: Alignment.centerLeft, child: Text(label)),
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 46),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      );
}
