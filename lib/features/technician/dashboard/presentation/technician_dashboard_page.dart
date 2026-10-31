import 'package:flutter/material.dart';

import '../../../../core/theme/fixia_theme.dart';
import '../../../../features/home/presentation/widgets/dashboard_components.dart';
import '../../opportunities/domain/service_opportunity.dart';
import '../../profile/domain/verification_status.dart';

/// Resumen real del trabajo del técnico (GC-428, GC-429, GC-442),
/// calculado con sus postulaciones y contrataciones en ms-services.
class TechnicianWorkStats {
  const TechnicianWorkStats({
    required this.toQuote,
    required this.active,
    required this.closed,
  });

  /// Solicitudes donde lo seleccionaron y aún no hay contrato.
  final int toQuote;

  /// Contratados, en ejecución o esperando el cierre del cliente.
  final int active;
  final int closed;
}

class TechnicianDashboardPage extends StatelessWidget {
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
    this.onRecordEvidence,
    this.onMarkFinished,
    this.onRequestWithdrawal,
    this.onApplyToOpportunity,
    this.onAvailabilityChanged,
    this.onOpenAvailability,
    this.loadOpportunities,
    this.loadStats,
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
  final VoidCallback? onRecordEvidence;
  final VoidCallback? onMarkFinished;
  final VoidCallback? onRequestWithdrawal;
  final ValueChanged<String>? onApplyToOpportunity;
  final ValueChanged<bool>? onAvailabilityChanged;
  final VoidCallback? onOpenAvailability;

  /// Solicitudes compatibles reales (GC-340). Sin conexión es `null` y no
  /// se muestran oportunidades de ejemplo.
  final Future<List<ServiceOpportunity>> Function()? loadOpportunities;

  /// Resumen de «Mis trabajos». Sin conexión es `null`.
  final Future<TechnicianWorkStats> Function()? loadStats;

  /// Oportunidades que se muestran en el inicio; el resto en la pantalla de
  /// oportunidades.
  static const opportunitiesLimit = 3;

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      contentPadding: EdgeInsets.zero,
      bottomNavigationBar: _TechnicianNavigationBar(
        onOpenProfile: onOpenSettings ?? () => _showProfileMessage(context),
        onOpenOpportunities: onOpenJobs ?? onOpenOpportunities,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TechnicianHeader(
            firstName: firstName,
            status: verificationStatus,
            onOpenSettings: onOpenSettings,
            onLogout: onLogout,
            loadStats: loadStats,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _VerificationBanner(status: verificationStatus),
                const SizedBox(height: 14),
                _AvailabilityCard(
                  onAvailabilityChanged: onAvailabilityChanged,
                  onOpenAvailability: onOpenAvailability,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: const ValueKey('technician-open-specialties'),
                    onPressed: onOpenSpecialties,
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('Editar especialidades'),
                  ),
                ),
                if (onOpenChat != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: const ValueKey('technician-open-chat-prototype'),
                      onPressed: onOpenChat,
                      icon: const Icon(Icons.chat_bubble_outline_rounded,
                          size: 18),
                      label: const Text('Chat de demostración'),
                    ),
                  ),
                const SizedBox(height: 24),
                _LiveOpportunities(
                  load: loadOpportunities,
                  onOpenOpportunities: onOpenOpportunities,
                  onApply: (id) => onApplyToOpportunity != null
                      ? onApplyToOpportunity!(id)
                      : onOpenOpportunities?.call(),
                ),
                const SizedBox(height: 32),
                DashboardSectionHeading(
                  title: 'Mis trabajos',
                  subtitle: 'Cotizaciones por enviar y servicios contratados.',
                  trailing: TextButton(
                    key: const ValueKey('technician-open-jobs'),
                    onPressed: onOpenJobs,
                    child: const Text('Ver'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TechnicianHeader extends StatelessWidget {
  const _TechnicianHeader({
    required this.firstName,
    required this.status,
    required this.onOpenSettings,
    required this.onLogout,
    this.loadStats,
  });

  final String? firstName;
  final VerificationStatus status;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onLogout;
  final Future<TechnicianWorkStats> Function()? loadStats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: const BoxDecoration(
        color: FixiaColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bienvenido,',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFFB7CCE8),
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      firstName == null || firstName!.trim().isEmpty
                          ? 'Técnico'
                          : firstName!,
                      key: const ValueKey('technician-dashboard-greeting'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: FixiaColors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    _VerificationBadge(status: status),
                  ],
                ),
              ),
              IconButton(
                key: const ValueKey('technician-dashboard-settings'),
                tooltip: 'Ajustes',
                onPressed: onOpenSettings ?? () => _showProfileMessage(context),
                icon: const Icon(
                  Icons.settings_outlined,
                  color: FixiaColors.white,
                ),
              ),
              if (onLogout != null)
                IconButton(
                  key: const ValueKey('technician-dashboard-logout'),
                  tooltip: 'Cerrar sesión',
                  onPressed: onLogout,
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: FixiaColors.white,
                  ),
                ),
              const SizedBox(width: 4),
              InkWell(
                key: const ValueKey('technician-dashboard-profile'),
                onTap: onOpenSettings ?? () => _showProfileMessage(context),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: FixiaColors.supportBackground,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _initials(firstName),
                    style: const TextStyle(
                      color: FixiaColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _StatsRow(load: loadStats),
        ],
      ),
    );
  }
}

class _TechnicianStat extends StatelessWidget {
  const _TechnicianStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
      decoration: const BoxDecoration(
        color: Color(0x1FFFFFFF),
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              color: FixiaColors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFB7CCE8),
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityCard extends StatefulWidget {
  const _AvailabilityCard(
      {required this.onAvailabilityChanged, this.onOpenAvailability});

  final ValueChanged<bool>? onAvailabilityChanged;
  final VoidCallback? onOpenAvailability;

  @override
  State<_AvailabilityCard> createState() => _AvailabilityCardState();
}

class _AvailabilityCardState extends State<_AvailabilityCard> {
  bool _isAvailable = true;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: FixiaColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE3EAF4)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x1001255D), blurRadius: 10, offset: Offset(0, 3))
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                      color: Color(0x2600B79E), shape: BoxShape.circle),
                  child: const Icon(Icons.circle,
                      color: FixiaColors.accent, size: 12),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          _isAvailable
                              ? 'Disponible para trabajos'
                              : 'No disponible',
                          style: const TextStyle(
                              color: FixiaColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(
                          _isAvailable
                              ? 'Recibes solicitudes nuevas'
                              : 'No recibirás solicitudes nuevas',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Switch(
                  key: const ValueKey('technician-availability-switch'),
                  value: _isAvailable,
                  activeColor: FixiaColors.secondary,
                  onChanged: (value) {
                    setState(() => _isAvailable = value);
                    widget.onAvailabilityChanged?.call(value);
                  },
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const ValueKey('technician-open-availability'),
                onPressed: widget.onOpenAvailability,
                icon: const Icon(Icons.edit_calendar_rounded, size: 17),
                label: const Text('Horario y zona de atención'),
                style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
              ),
            ),
          ],
        ),
      );
}

class _VerificationBanner extends StatelessWidget {
  const _VerificationBanner({required this.status});

  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final isPending = status == VerificationStatus.pending;
    final isValid = status == VerificationStatus.valid;
    final color = isValid
        ? FixiaColors.accent
        : status == VerificationStatus.rejected ||
                status == VerificationStatus.expired
            ? FixiaColors.error
            : const Color(0xFF9A5B00);
    final message = switch (status) {
      VerificationStatus.pending =>
        'Tu cuenta está en proceso de verificación. Los clientes verán este estado al comparar tu propuesta.',
      VerificationStatus.valid =>
        'Tu cuenta está verificada. Ya puedes postularte a nuevas oportunidades.',
      VerificationStatus.rejected =>
        'Tu verificación fue rechazada. Revisa tus documentos para continuar.',
      VerificationStatus.expired =>
        'Tu verificación está vencida. Actualiza tus documentos para postularte.',
    };
    return Container(
      key: const ValueKey('technician-verification-banner'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: switch (status) {
          VerificationStatus.pending => const Color(0xFFFFF4DF),
          VerificationStatus.valid => const Color(0xFFE5F7F3),
          VerificationStatus.rejected ||
          VerificationStatus.expired =>
            const Color(0xFFFDECEA),
        },
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPending
                ? Icons.hourglass_top_rounded
                : Icons.info_outline_rounded,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: FixiaColors.textPrimary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  const _VerificationBadge({required this.status});

  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (status) {
      VerificationStatus.pending => (
          'PENDIENTE',
          const Color(0xFF9A5B00),
          const Color(0xFFFFF4DF)
        ),
      VerificationStatus.valid => (
          'VIGENTE',
          FixiaColors.accent,
          const Color(0xFFE5F7F3)
        ),
      VerificationStatus.rejected => (
          'RECHAZADA',
          FixiaColors.error,
          const Color(0xFFFDECEA)
        ),
      VerificationStatus.expired => (
          'VENCIDA',
          FixiaColors.error,
          const Color(0xFFFDECEA)
        ),
    };
    return Container(
      key: const ValueKey('technician-verification-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({
    required this.id,
    required this.title,
    required this.customer,
    required this.category,
    required this.location,
    required this.posted,
    required this.budget,
    required this.icon,
    required this.onApply,
  });

  final String id;
  final String title;
  final String customer;
  final String category;
  final String location;
  final String posted;
  final String budget;
  final IconData icon;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FixiaColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3EAF4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1001255D),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFEEF5FF),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  category.characters.take(2).toString().toUpperCase(),
                  style: const TextStyle(
                    color: FixiaColors.secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(customer, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              _OpportunityMeta(
                icon: Icons.location_on_outlined,
                label: location,
              ),
              _OpportunityMeta(
                icon: Icons.schedule_rounded,
                label: posted,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'Ubicación aproximada',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
              _OpportunityTag(label: category),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFE7EDF5)),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final budgetSummary = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Presupuesto', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    budget,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: FixiaColors.secondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              );
              final applyButton = FilledButton(
                key: ValueKey('technician-apply-$id'),
                onPressed: onApply,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(112, 46),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: const Text('Postularme'),
              );

              if (constraints.maxWidth < 320) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    budgetSummary,
                    const SizedBox(height: 10),
                    applyButton,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: budgetSummary),
                  const SizedBox(width: 8),
                  applyButton,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TechnicianNavigationBar extends StatelessWidget {
  const _TechnicianNavigationBar({
    required this.onOpenProfile,
    this.onOpenOpportunities,
  });

  final VoidCallback onOpenProfile;
  final VoidCallback? onOpenOpportunities;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: FixiaColors.white,
        border: Border(top: BorderSide(color: FixiaColors.supportBackground)),
      ),
      child: Row(
        children: [
          const _TechnicianNavItem(
            icon: Icons.home_rounded,
            label: 'Inicio',
            selected: true,
          ),
          _TechnicianNavItem(
            icon: Icons.work_outline_rounded,
            label: 'Trabajos',
            onPressed: onOpenOpportunities,
          ),
          _TechnicianNavItem(
            icon: Icons.person_outline_rounded,
            label: 'Perfil',
            onPressed: onOpenProfile,
          ),
        ],
      ),
    );
  }
}

class _TechnicianNavItem extends StatelessWidget {
  const _TechnicianNavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = selected ? FixiaColors.secondary : const Color(0xFF9AAABD);
    return Expanded(
      child: InkWell(
        key: ValueKey('technician-nav-${label.toLowerCase()}'),
        onTap: onPressed ??
            (label == 'Perfil' ? () => _showProfileMessage(context) : _noop),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 21, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? FixiaColors.secondary
                    : FixiaColors.textSecondary,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpportunityTag extends StatelessWidget {
  const _OpportunityTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: FixiaColors.supportBackground,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _OpportunityMeta extends StatelessWidget {
  const _OpportunityMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: FixiaColors.textSecondary, size: 16),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

void _noop() {}

void _showProfileMessage(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'El perfil profesional existe para cuentas autenticadas; esta demo no tiene una sesión activa.',
      ),
    ),
  );
}

String _initials(String? name) {
  final parts = (name ?? '').trim().split(RegExp(r'\s+'))
    ..removeWhere((p) => p.isEmpty);
  if (parts.isEmpty) return 'T';
  return parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
}

/// Contadores reales de «Mis trabajos»; mientras cargan o sin conexión
/// muestran «–», nunca un número inventado.
class _StatsRow extends StatefulWidget {
  const _StatsRow({required this.load});

  final Future<TechnicianWorkStats> Function()? load;

  @override
  State<_StatsRow> createState() => _StatsRowState();
}

class _StatsRowState extends State<_StatsRow> {
  late final Future<TechnicianWorkStats>? _stats = widget.load?.call();

  @override
  Widget build(BuildContext context) => FutureBuilder<TechnicianWorkStats>(
        future: _stats,
        builder: (context, snapshot) {
          final stats = snapshot.hasData ? snapshot.data : null;
          String show(int? value) => value == null ? '–' : '$value';
          return Row(
            children: [
              Expanded(
                child: _TechnicianStat(
                    value: show(stats?.toQuote), label: 'Por cotizar'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TechnicianStat(
                    value: show(stats?.active), label: 'En curso'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TechnicianStat(
                    value: show(stats?.closed), label: 'Cerrados'),
              ),
            ],
          );
        },
      );
}

/// Oportunidades reales compatibles con el técnico. «Postularme» abre la
/// pantalla de oportunidades, donde se envía el precio propuesto.
class _LiveOpportunities extends StatefulWidget {
  const _LiveOpportunities({
    required this.load,
    required this.onOpenOpportunities,
    required this.onApply,
  });

  final Future<List<ServiceOpportunity>> Function()? load;
  final VoidCallback? onOpenOpportunities;
  final ValueChanged<String> onApply;

  @override
  State<_LiveOpportunities> createState() => _LiveOpportunitiesState();
}

class _LiveOpportunitiesState extends State<_LiveOpportunities> {
  late Future<List<ServiceOpportunity>>? _future = widget.load?.call();

  void _reload() => setState(() {
        _future = widget.load?.call();
      });

  @override
  Widget build(BuildContext context) {
    final title = Text(
      'Oportunidades disponibles',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: FixiaColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
    );
    Widget note(String text) => Text(
          text,
          style: const TextStyle(color: FixiaColors.textSecondary),
        );
    final future = _future;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: title),
            TextButton(
              key: const ValueKey('technician-see-opportunities'),
              onPressed: widget.onOpenOpportunities,
              child: const Text('Ver todas'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (future == null)
          note('Las oportunidades aparecerán aquí cuando te conectes a Fixia.')
        else
          FutureBuilder<List<ServiceOpportunity>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Column(
                  children: [
                    note('${snapshot.error}'),
                    TextButton(
                        onPressed: _reload, child: const Text('Reintentar')),
                  ],
                );
              }
              final items = snapshot.data!
                  .take(TechnicianDashboardPage.opportunitiesLimit)
                  .toList();
              if (items.isEmpty) {
                return note(
                    'No hay solicitudes compatibles con tus especialidades y zona en este momento.');
              }
              return Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    _OpportunityCard(
                      id: items[i].id,
                      title: items[i].title,
                      customer: items[i].category.label,
                      category: items[i].category.label,
                      location: items[i].approximateLocation,
                      posted: items[i].postedLabel,
                      budget: items[i].budget,
                      icon: Icons.handyman_rounded,
                      onApply: () => widget.onApply(items[i].id),
                    ),
                    if (i < items.length - 1) const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
      ],
    );
  }
}
