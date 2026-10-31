import 'package:flutter/material.dart';

import '../../../../core/theme/fixia_theme.dart';
import '../../../home/presentation/widgets/dashboard_components.dart';

/// Inicio de la cuenta de empresa prestadora (GC-467): navegación mínima,
/// sin panel administrativo. Muestra el nombre real de la empresa y lleva a
/// sus técnicos asociados y, cuando exista (GC-469), a las oportunidades
/// para postularse.
class CompanyDashboardPage extends StatefulWidget {
  const CompanyDashboardPage({
    super.key,
    required this.firstName,
    required this.loadCompanyName,
    required this.onOpenTechnicians,
    required this.onLogout,
    this.onOpenOpportunities,
  });

  /// Nombre del administrador (sale de la sesión).
  final String firstName;

  /// Nombre comercial de la empresa, consultado en el backend. Si falla,
  /// el error se muestra con su mensaje y se puede reintentar.
  final Future<String> Function() loadCompanyName;

  final VoidCallback onOpenTechnicians;
  final VoidCallback onLogout;

  /// Oportunidades para postular a la empresa (GC-469). Mientras sea `null`
  /// la acción no se muestra: no hay pantalla simulada.
  final VoidCallback? onOpenOpportunities;

  @override
  State<CompanyDashboardPage> createState() => _CompanyDashboardPageState();
}

class _CompanyDashboardPageState extends State<CompanyDashboardPage> {
  late Future<String> _companyName = widget.loadCompanyName();

  void _retry() {
    setState(() {
      _companyName = widget.loadCompanyName();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DashboardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Hola, ${widget.firstName}',
                  style: theme.textTheme.headlineMedium,
                ),
              ),
              IconButton(
                key: const ValueKey('company-logout'),
                tooltip: 'Cerrar sesión',
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FutureBuilder<String>(
            future: _companyName,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator(
                  key: ValueKey('company-name-loading'),
                );
              }
              if (snapshot.hasError) {
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        snapshot.error.toString(),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: FixiaColors.error),
                      ),
                    ),
                    TextButton(
                      key: const ValueKey('company-name-retry'),
                      onPressed: _retry,
                      child: const Text('Reintentar'),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  const Icon(Icons.apartment_rounded,
                      size: 18, color: FixiaColors.secondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      snapshot.data!,
                      key: const ValueKey('company-name'),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          _ActionCard(
            key: const ValueKey('company-open-technicians'),
            icon: Icons.groups_outlined,
            title: 'Mis técnicos',
            subtitle: 'Técnicos asociados a tu empresa.',
            onTap: widget.onOpenTechnicians,
          ),
          if (widget.onOpenOpportunities != null) ...[
            const SizedBox(height: 12),
            _ActionCard(
              key: const ValueKey('company-open-opportunities'),
              icon: Icons.work_outline_rounded,
              title: 'Oportunidades',
              subtitle: 'Solicitudes a las que tu empresa puede postularse.',
              onTap: widget.onOpenOpportunities!,
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(FixiaRadii.card),
      onTap: onTap,
      child: DashboardCard(
        child: Row(
          children: [
            Icon(icon, color: FixiaColors.secondary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
