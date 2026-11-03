import 'package:flutter/material.dart';

import '../../../../core/theme/fixia_theme.dart';
import '../../../../core/layout/app_shell.dart';
import '../../../../core/widgets/fixia_ui.dart';
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
    return AppShell(
      destination: ShellDestination.companyTechnicians,
      userCaption: 'Empresa',
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BackLink(onPressed: widget.onBack),
            PageHeader(
              title: 'Mis técnicos',
              subtitle: 'Técnicos asociados a tu empresa. Al postularte a una '
                  'solicitud propones a uno de ellos.',
              actions: [
                OutlinedButton.icon(
                  key: const ValueKey('company-technicians-refresh'),
                  onPressed: widget.controller.status ==
                          CompanyTechniciansStatus.loading
                      ? null
                      : widget.controller.load,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Actualizar'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _content(context),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final controller = widget.controller;
    switch (controller.status) {
      case CompanyTechniciansStatus.idle:
      case CompanyTechniciansStatus.loading:
        return const Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: CircularProgressIndicator(
              key: ValueKey('company-technicians-loading'),
            ),
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
        final count = controller.technicians.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(
              title: '$count ${count == 1 ? 'técnico' : 'técnicos'}',
            ),
            ResponsiveGrid(
              minItemWidth: 320,
              children: [
                for (final technician in controller.technicians)
                  AssociatedTechnicianTile(technician: technician),
              ],
            ),
          ],
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
    return FixiaPanel(
      padding: const EdgeInsets.all(28),
      child: Center(
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
