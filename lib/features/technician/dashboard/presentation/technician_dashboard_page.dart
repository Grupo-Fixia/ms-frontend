import 'package:flutter/material.dart';

import '../../../../core/theme/fixia_theme.dart';
import '../../../../features/home/presentation/widgets/dashboard_components.dart';
import '../../profile/domain/verification_status.dart';

class TechnicianDashboardPage extends StatelessWidget {
  const TechnicianDashboardPage({
    super.key,
    this.firstName,
    this.verificationStatus = VerificationStatus.pending,
    this.onOpenSettings,
    this.onLogout,
    this.onOpenOpportunities,
    this.onOpenSpecialties,
    this.onRecordEvidence,
    this.onMarkFinished,
    this.onRequestWithdrawal,
    this.onApplyToOpportunity,
    this.onAvailabilityChanged,
  });

  final String? firstName;
  final VerificationStatus verificationStatus;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onLogout;
  final VoidCallback? onOpenOpportunities;
  final VoidCallback? onOpenSpecialties;
  final VoidCallback? onRecordEvidence;
  final VoidCallback? onMarkFinished;
  final VoidCallback? onRequestWithdrawal;
  final ValueChanged<String>? onApplyToOpportunity;
  final ValueChanged<bool>? onAvailabilityChanged;

  @override
  Widget build(BuildContext context) {
    final isVerified = verificationStatus == VerificationStatus.valid;
    return DashboardShell(
      contentPadding: EdgeInsets.zero,
      bottomNavigationBar: _TechnicianNavigationBar(
        onOpenProfile: onOpenSettings ?? () => _showProfileMessage(context),
        onOpenOpportunities: onOpenOpportunities,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TechnicianHeader(
            firstName: firstName,
            status: verificationStatus,
            onOpenSettings: onOpenSettings,
            onLogout: onLogout,
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
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Oportunidades Disponibles',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: FixiaColors.primary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const _NewOpportunitiesBadge(),
                  ],
                ),
                const SizedBox(height: 12),
                _OpportunityCard(
                  id: 'plumbing-repair',
                  title: 'Reparar fuga bajo el lavaplatos',
                  customer: 'María López',
                  category: 'Plomería',
                  location: 'Chapinero, Bogotá',
                  posted: 'Hace 5 min',
                  budget: '\$80.000 – \$140.000',
                  icon: Icons.plumbing_rounded,
                  urgent: true,
                  isVerified: isVerified,
                  onApply: () => onApplyToOpportunity?.call('plumbing-repair'),
                ),
                const SizedBox(height: 12),
                _OpportunityCard(
                  id: 'ceiling-fan',
                  title: 'Instalar ventilador de techo',
                  customer: 'Andrés Ruiz',
                  category: 'Electricidad',
                  location: 'Usaquén, Bogotá',
                  posted: 'Hace 18 min',
                  budget: '\$65.000 – \$110.000',
                  icon: Icons.electrical_services_rounded,
                  isVerified: isVerified,
                  onApply: () => onApplyToOpportunity?.call('ceiling-fan'),
                ),
                const SizedBox(height: 12),
                _OpportunityCard(
                  id: 'kitchen-circuit',
                  title: 'Reparación de circuito en cocina',
                  customer: 'Sofía Mora',
                  category: 'Electricidad',
                  location: 'Teusaquillo, Bogotá',
                  posted: 'Hace 32 min',
                  budget: '\$90.000 – \$150.000',
                  icon: Icons.electrical_services_rounded,
                  urgent: true,
                  isVerified: isVerified,
                  onApply: () => onApplyToOpportunity?.call('kitchen-circuit'),
                ),
                const SizedBox(height: 32),
                const DashboardSectionHeading(
                  title: 'Trabajos Asignados / En Curso',
                  subtitle: 'Mantén al cliente al tanto de cada avance.',
                ),
                const SizedBox(height: 14),
                _AssignedJobCard(
                  title: 'Mantenimiento de calentador',
                  client: 'Valentina P. · En curso',
                  onRecordEvidence: onRecordEvidence,
                  onMarkFinished: onMarkFinished,
                ),
                const SizedBox(height: 32),
                _WalletCard(onRequestWithdrawal: onRequestWithdrawal),
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
  });

  final String? firstName;
  final VerificationStatus status;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onLogout;

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
                          ? 'Carlos Mendoza'
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
                  child: const Text(
                    'CM',
                    style: TextStyle(
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
          const Row(
            children: [
              Expanded(
                child: _TechnicianStat(value: '3', label: 'Trabajos hoy'),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _TechnicianStat(value: '4.8', label: 'Rating'),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _TechnicianStat(value: '\$1.2M', label: 'Ingresos mes'),
              ),
            ],
          ),
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
  const _AvailabilityCard({required this.onAvailabilityChanged});

  final ValueChanged<bool>? onAvailabilityChanged;

  @override
  State<_AvailabilityCard> createState() => _AvailabilityCardState();
}

class _AvailabilityCardState extends State<_AvailabilityCard> {
  bool _isAvailable = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: FixiaColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3EAF4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1001255D),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: Color(0x2600B79E),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.circle,
              color: FixiaColors.accent,
              size: 12,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isAvailable ? 'Disponible para trabajos' : 'No disponible',
                  style: const TextStyle(
                    color: FixiaColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isAvailable
                      ? 'Recibes solicitudes nuevas'
                      : 'No recibirás solicitudes nuevas',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
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
    );
  }
}

class _NewOpportunitiesBadge extends StatelessWidget {
  const _NewOpportunitiesBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FixiaColors.supportBackground,
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        child: Text(
          '3 nuevas',
          style: TextStyle(
            color: FixiaColors.secondary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
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
        'Tu cuenta está en proceso de verificación. La opción de postularse se habilitará al ser aprobado.',
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
    this.urgent = false,
    required this.isVerified,
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
  final bool urgent;
  final bool isVerified;
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
                  customer.split(' ').map((part) => part[0]).take(2).join(),
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
              if (urgent) ...[
                const SizedBox(width: 6),
                const _UrgentBadge(),
              ],
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
                key: ValueKey(
                  id == 'plumbing-repair'
                      ? 'technician-apply'
                      : 'technician-apply-$id',
                ),
                onPressed: isVerified ? onApply : null,
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
          const _TechnicianNavItem(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Billetera',
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

class _AssignedJobCard extends StatelessWidget {
  const _AssignedJobCard({
    required this.title,
    required this.client,
    required this.onRecordEvidence,
    required this.onMarkFinished,
  });

  final String title;
  final String client;
  final VoidCallback? onRecordEvidence;
  final VoidCallback? onMarkFinished;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(client, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          const ApproximateLocationLabel(),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('technician-record-evidence'),
                onPressed: onRecordEvidence ?? _noop,
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: const Text('Registrar Avance / Evidencia'),
              ),
              FilledButton.tonal(
                key: const ValueKey('technician-mark-finished'),
                onPressed: onMarkFinished ?? _noop,
                child: const Text('Marcar Finalizado'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.onRequestWithdrawal});

  final VoidCallback? onRequestWithdrawal;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('technician-wallet-summary'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FixiaColors.primary,
        borderRadius: BorderRadius.circular(FixiaRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined,
                  color: FixiaColors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Mi billetera',
                  style: TextStyle(
                    color: FixiaColors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              Expanded(
                child: _WalletBalance(
                  label: 'Saldo disponible',
                  amount: '\$385.000',
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _WalletBalance(
                  label: 'Saldo retenido',
                  amount: '\$120.000',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            key: const ValueKey('technician-request-withdrawal'),
            onPressed: onRequestWithdrawal ?? _noop,
            icon: const Icon(Icons.south_west_rounded, size: 18),
            label: const Text('Solicitar Retiro'),
            style: OutlinedButton.styleFrom(
              foregroundColor: FixiaColors.white,
              side: const BorderSide(color: FixiaColors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletBalance extends StatelessWidget {
  const _WalletBalance({required this.label, required this.amount});

  final String label;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFFDCEBFF), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: const TextStyle(
            color: FixiaColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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

class _UrgentBadge extends StatelessWidget {
  const _UrgentBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFE7E6),
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          'URGENTE',
          style: TextStyle(
            color: FixiaColors.error,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
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
