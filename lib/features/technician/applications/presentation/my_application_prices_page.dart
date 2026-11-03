import 'package:flutter/material.dart';
import '../../../../core/layout/app_shell.dart';
import '../../../../core/theme/fixia_theme.dart';
import '../../../../core/widgets/fixia_ui.dart';
import '../domain/service_application.dart';

/// Consulta autorizada del usuario actual. No sustituye historial de servicios.
class MyApplicationPricesPage extends StatefulWidget {
  const MyApplicationPricesPage({super.key, required this.loadApplications});
  final Future<List<ServiceApplication>> Function() loadApplications;
  @override
  State<MyApplicationPricesPage> createState() =>
      _MyApplicationPricesPageState();
}

class _MyApplicationPricesPageState extends State<MyApplicationPricesPage> {
  List<ServiceApplication>? _items;
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.loadApplications();
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) {
        setState(() {
          _items = null;
          _error = error;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const SectionLoading();
    } else if (_error != null) {
      body = EmptyState(
        icon: Icons.error_outline_rounded,
        message: 'No pudimos consultar tus postulaciones.',
        action: FilledButton(onPressed: _load, child: const Text('Reintentar')),
      );
    } else if (_items!.isEmpty) {
      body = const EmptyState(message: 'Todavía no tienes postulaciones.');
    } else {
      body = ResponsiveGrid(
        minItemWidth: 300,
        children: [
          for (final item in _items!)
            FixiaPanel(
              key: ValueKey('application-${item.id}'),
              highlight: item.status == ApplicationStatus.selected
                  ? FixiaColors.secondary
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.serviceRequest.category.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      StatusPill(
                        label: item.status.label,
                        tone: switch (item.status) {
                          ApplicationStatus.selected => PillTone.success,
                          ApplicationStatus.rejected => PillTone.neutral,
                          ApplicationStatus.applied => PillTone.info,
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${item.serviceRequest.city} · ${item.serviceRequest.zone}',
                    style: const TextStyle(color: FixiaColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Precio propuesto',
                    style: TextStyle(
                      fontSize: 12,
                      color: FixiaColors.textSecondary,
                    ),
                  ),
                  Text(
                    item.proposedPrice?.label ?? 'Precio no informado',
                    key: ValueKey('application-price-${item.id}'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: FixiaColors.primary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }
    return AppShell(
      destination: ShellDestination.technicianOpportunities,
      subpage: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BackLink(label: 'Oportunidades'),
          PageHeader(
            title: 'Mis postulaciones',
            subtitle:
                'Las solicitudes a las que te postulaste y el precio que propusiste.',
            actions: [
              OutlinedButton.icon(
                key: const ValueKey('my-applications-refresh'),
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Actualizar'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          body,
        ],
      ),
    );
  }
}
