import 'package:flutter/material.dart';

import '../../../../core/theme/fixia_theme.dart';
import '../../../home/presentation/widgets/dashboard_components.dart';
import 'company_technicians_controller.dart';
import 'widgets/associated_technician_tile.dart';

/// «Mis técnicos»: técnicos asociados reales de la empresa autenticada
/// (GC-467). Sin datos de ejemplo: si no hay técnicos lo dice, y si la
/// consulta falla muestra el error con opción de reintentar.
class CompanyTechniciansPage extends StatefulWidget {
  const CompanyTechniciansPage({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onSessionExpired,
  });

  final CompanyTechniciansController controller;
  final VoidCallback onBack;

  /// La sesión venció: la app vuelve al login.
  final VoidCallback onSessionExpired;

  static const emptyMessage =
      'Tu empresa todavía no tiene técnicos asociados. Las asociaciones las '
      'gestiona el equipo de Fixia.';

  @override
  State<CompanyTechniciansPage> createState() => _CompanyTechniciansPageState();
}

class _CompanyTechniciansPageState extends State<CompanyTechniciansPage> {
  bool _sessionExpiryHandled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    // Siempre se consulta al abrir: la lista debe reflejar lo persistido.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.load();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (widget.controller.sessionExpired && !_sessionExpiryHandled) {
      _sessionExpiryHandled = true;
      widget.onSessionExpired();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileFeatureShell(
      title: 'Mis técnicos',
      onBack: widget.onBack,
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => _content(context),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final controller = widget.controller;
    switch (controller.status) {
      case CompanyTechniciansStatus.idle:
      case CompanyTechniciansStatus.loading:
        return const Center(
          child: CircularProgressIndicator(
            key: ValueKey('company-technicians-loading'),
          ),
        );
      case CompanyTechniciansStatus.failure:
        return _Message(
          icon: Icons.cloud_off_outlined,
          text: controller.errorMessage ??
              CompanyTechniciansController.unexpectedErrorMessage,
          action: FilledButton(
            key: const ValueKey('company-technicians-retry'),
            onPressed: controller.load,
            child: const Text('Reintentar'),
          ),
        );
      case CompanyTechniciansStatus.ready:
        if (controller.technicians.isEmpty) {
          return const _Message(
            icon: Icons.groups_outlined,
            text: CompanyTechniciansPage.emptyMessage,
          );
        }
        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            itemCount: controller.technicians.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                final count = controller.technicians.length;
                return DashboardSectionHeading(
                  title: '$count ${count == 1 ? 'técnico' : 'técnicos'}',
                  subtitle: 'Asociados a tu empresa. Al postularte a una '
                      'solicitud propones a uno de ellos.',
                );
              }
              return AssociatedTechnicianTile(
                technician: controller.technicians[index - 1],
              );
            },
          ),
        );
    }
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: FixiaColors.textSecondary),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
