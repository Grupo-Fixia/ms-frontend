import 'package:flutter/material.dart';

import '../../../../core/layout/app_shell.dart';
import '../../../../core/widgets/fixia_ui.dart';
import '../domain/service_request.dart';
import 'service_request_list.dart';

/// Filtros de «Mis solicitudes».
enum RequestFilter { all, open, inProgress, closed }

bool _matches(RequestFilter filter, ServiceRequestStatus status) =>
    switch (filter) {
      RequestFilter.all => true,
      RequestFilter.open => status == ServiceRequestStatus.published ||
          status == ServiceRequestStatus.providerSelected,
      RequestFilter.inProgress => status == ServiceRequestStatus.contracted ||
          status == ServiceRequestStatus.inProgress ||
          status == ServiceRequestStatus.technicianFinished,
      RequestFilter.closed => status.isTerminal,
    };

/// Todas las solicitudes del cliente, con filtros por estado.
class MyServiceRequestsPage extends StatefulWidget {
  const MyServiceRequestsPage({
    super.key,
    required this.load,
    required this.get,
    this.onOpen,
    this.onPublish,
  });

  final Future<List<ServiceRequest>> Function() load;
  final Future<ServiceRequest> Function(String id) get;

  /// Abre el detalle completo de la solicitud (postulantes, cotización,
  /// contrato y cierre). Al volver se actualiza la lista. Sin él, se muestra
  /// un resumen en un diálogo.
  final Future<void> Function(ServiceRequest request)? onOpen;

  /// Publicar un problema nuevo; si es `null` se usa la acción del marco.
  final VoidCallback? onPublish;

  @override
  State<MyServiceRequestsPage> createState() => _MyServiceRequestsPageState();
}

class _MyServiceRequestsPageState extends State<MyServiceRequestsPage> {
  late Future<List<ServiceRequest>> _requests = widget.load();
  bool _opening = false;
  RequestFilter _filter = RequestFilter.all;

  void _reload() => setState(() {
        _requests = widget.load();
      });

  Future<void> _open(ServiceRequest request) async {
    if (_opening) return;
    final onOpen = widget.onOpen;
    if (onOpen != null) {
      await onOpen(request);
      if (mounted) _reload();
      return;
    }
    setState(() => _opening = true);
    try {
      final saved = await widget.get(request.id);
      if (!mounted) return;
      setState(() => _opening = false);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(saved.category.label),
          content: Text('${saved.description}\n\nPresupuesto orientativo\n'
              '${saved.budget?.label ?? 'Presupuesto no informado'}'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'))
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final publish =
        widget.onPublish ?? FixiaShellScope.maybeOf(context)?.onPrimaryAction;
    return AppShell(
      destination: ShellDestination.clientRequests,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Mis solicitudes',
            subtitle:
                'Todo lo que has publicado: postulantes, cotizaciones, contratos y cierres.',
            actions: [
              OutlinedButton.icon(
                key: const ValueKey('client-requests-refresh'),
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Actualizar'),
              ),
              if (publish != null)
                FilledButton.icon(
                  key: const ValueKey('client-requests-publish'),
                  onPressed: publish,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Publicar un problema'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          FutureBuilder<List<ServiceRequest>>(
            future: _requests,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SectionLoading();
              }
              if (snapshot.hasError) {
                return EmptyState(
                  message: '${snapshot.error}',
                  icon: Icons.error_outline_rounded,
                  action: TextButton(
                    onPressed: _reload,
                    child: const Text('Reintentar'),
                  ),
                );
              }
              final all = snapshot.data!;
              if (all.isEmpty) {
                return EmptyState(
                  message: 'Todavía no tienes solicitudes.',
                  action: publish == null
                      ? null
                      : FilledButton(
                          onPressed: publish,
                          child: const Text('Publicar un problema'),
                        ),
                );
              }
              int count(RequestFilter f) =>
                  all.where((r) => _matches(f, r.status)).length;
              final shown =
                  all.where((r) => _matches(_filter, r.status)).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilterPills<RequestFilter>(
                    keyPrefix: 'client-requests-filter',
                    selected: _filter,
                    onSelected: (f) => setState(() => _filter = f),
                    options: [
                      (RequestFilter.all, 'Todas (${all.length})'),
                      (
                        RequestFilter.open,
                        'Abiertas (${count(RequestFilter.open)})'
                      ),
                      (
                        RequestFilter.inProgress,
                        'En curso (${count(RequestFilter.inProgress)})'
                      ),
                      (
                        RequestFilter.closed,
                        'Finalizadas (${count(RequestFilter.closed)})'
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_opening) const LinearProgressIndicator(),
                  if (shown.isEmpty)
                    const EmptyState(
                      message: 'No hay solicitudes con este filtro.',
                      icon: Icons.filter_alt_off_outlined,
                    )
                  else
                    ServiceRequestList(
                      requests: shown,
                      onOpen: (r) {
                        if (!_opening) _open(r);
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
