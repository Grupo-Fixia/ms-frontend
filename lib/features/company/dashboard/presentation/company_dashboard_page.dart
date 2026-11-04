import 'package:flutter/material.dart';

import '../../../../core/layout/app_shell.dart';
import '../../../../core/theme/fixia_theme.dart';
import '../../../../core/widgets/fixia_ui.dart';

/// Inicio de la cuenta de empresa prestadora (GC-467, GC-469), en el mismo
/// marco del prestador. Muestra el nombre real de la empresa y lleva a sus
/// técnicos asociados y a las oportunidades para postularse.
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

  void _navigate(ShellDestination destination) {
    switch (destination) {
      case ShellDestination.companyTechnicians:
        return widget.onOpenTechnicians();
      case ShellDestination.companyOpportunities:
        final open = widget.onOpenOpportunities;
        if (open != null) return open();
      default:
        break;
    }
    FixiaShellScope.maybeOf(context)?.onNavigate?.call(destination);
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      destination: ShellDestination.companyHome,
      userName: widget.firstName,
      userCaption: 'Empresa',
      onNavigate: _navigate,
      onLogout: widget.onLogout,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(title: 'Hola, ${widget.firstName}'),
          const SizedBox(height: 10),
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
                        style: const TextStyle(color: FixiaColors.error),
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
                      size: 20, color: FixiaColors.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      snapshot.data!,
                      key: const ValueKey('company-name'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: FixiaColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          ResponsiveGrid(
            minItemWidth: 300,
            children: [
              _ActionCard(
                key: const ValueKey('company-open-technicians'),
                icon: Icons.groups_outlined,
                title: 'Mis técnicos',
                subtitle:
                    'Los técnicos asociados a tu empresa, con su verificación y especialidades.',
                action: 'Ver técnicos',
                onTap: widget.onOpenTechnicians,
              ),
              if (widget.onOpenOpportunities != null)
                _ActionCard(
                  key: const ValueKey('company-open-opportunities'),
                  icon: Icons.work_outline_rounded,
                  title: 'Oportunidades',
                  subtitle:
                      'Solicitudes a las que tu empresa puede postular a uno de sus técnicos.',
                  action: 'Ver oportunidades',
                  onTap: widget.onOpenOpportunities!,
                ),
            ],
          ),
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
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: FixiaPanel(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: FixiaColors.supportBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: FixiaColors.secondary),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: FixiaColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(color: FixiaColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    action,
                    style: const TextStyle(
                      color: FixiaColors.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 18, color: FixiaColors.secondary),
                ],
              ),
            ],
          ),
        ),
      );
}
