import 'package:flutter/material.dart';

import '../../../../core/theme/fixia_theme.dart';
import '../../../home/presentation/widgets/dashboard_components.dart';
import '../../service_requests/domain/service_request.dart';

/// Inicio del cliente. Muestra solo datos reales de ms-services: sus
/// solicitudes y lo que tiene pendiente en cada una (revisar postulantes o
/// cotización, confirmar el cierre). No hay técnicos, precios ni
/// calificaciones de ejemplo.
class ClientDashboardPage extends StatefulWidget {
  const ClientDashboardPage({
    super.key,
    this.firstName,
    this.onPublishProblem,
    this.onOpenSettings,
    this.onOpenHistory,
    this.onOpenProfile,
    this.onLogout,
    this.loadRequests,
    this.onOpenRequest,
  });

  final String? firstName;
  final VoidCallback? onPublishProblem;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onLogout;

  /// Solicitudes del cliente, la más reciente primero. Sin conexión con
  /// Fixia es `null` y la sección lo dice en lugar de inventar datos.
  final Future<List<ServiceRequest>> Function()? loadRequests;

  /// Abre el detalle de una solicitud; al volver se actualiza el inicio.
  final Future<void> Function(ServiceRequest request)? onOpenRequest;

  /// Cuántas solicitudes recientes se muestran en el inicio.
  static const recentLimit = 3;

  @override
  State<ClientDashboardPage> createState() => _ClientDashboardPageState();
}

class _ClientDashboardPageState extends State<ClientDashboardPage> {
  Future<List<ServiceRequest>>? _requests;

  @override
  void initState() {
    super.initState();
    _requests = widget.loadRequests?.call();
  }

  void _reload() => setState(() {
        _requests = widget.loadRequests?.call();
      });

  Future<void> _open(ServiceRequest request) async {
    final open = widget.onOpenRequest;
    if (open == null) return;
    await open(request);
    if (mounted) _reload();
  }

  void _showClientProfileUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Inicia sesión como cliente para consultar y editar tu perfil.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      bottomNavigationBar: _ClientNavigationBar(
        onOpenHistory: widget.onOpenHistory,
        onPublishProblem: widget.onPublishProblem,
        onOpenProfile: widget.onOpenProfile ??
            widget.onOpenSettings ??
            _showClientProfileUnavailable,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ClientHeader(onLogout: widget.onLogout),
          const SizedBox(height: 22),
          Text(
            widget.firstName == null || widget.firstName!.trim().isEmpty
                ? 'Bienvenido a Fixia'
                : 'Hola, ${widget.firstName}',
            key: const ValueKey('client-dashboard-greeting'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 26,
                  height: 1.2,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            '¿Qué necesitas arreglar hoy?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: FixiaColors.textSecondary,
                ),
          ),
          const SizedBox(height: 16),
          _PublishCard(onPublish: widget.onPublishProblem),
          const SizedBox(height: 26),
          DashboardSectionHeading(
            title: 'Mis solicitudes',
            trailing: TextButton(
              onPressed: widget.onOpenHistory ?? _noop,
              child: const Text('Ver todas'),
            ),
          ),
          const SizedBox(height: 12),
          _RequestsSection(
            future: _requests,
            onRetry: _reload,
            onOpen: _open,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Qué le toca hacer al cliente en cada estado, para destacarlo.
String? pendingActionFor(ServiceRequestStatus status) => switch (status) {
      ServiceRequestStatus.published => 'Revisa los postulantes',
      ServiceRequestStatus.providerSelected => 'Revisa la cotización',
      ServiceRequestStatus.technicianFinished => 'Confirma el cierre',
      _ => null,
    };

class _PublishCard extends StatelessWidget {
  const _PublishCard({required this.onPublish});

  final VoidCallback? onPublish;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(
                Icons.home_repair_service_outlined,
                color: FixiaColors.secondary,
                size: 28,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Publica tu problema y recibe propuestas de técnicos.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('client-dashboard-publish'),
            onPressed: onPublish ?? _noop,
            child: const Text('Publicar un problema'),
          ),
        ],
      ),
    );
  }
}

class _RequestsSection extends StatelessWidget {
  const _RequestsSection({
    required this.future,
    required this.onRetry,
    required this.onOpen,
  });

  final Future<List<ServiceRequest>>? future;
  final VoidCallback onRetry;
  final ValueChanged<ServiceRequest> onOpen;

  @override
  Widget build(BuildContext context) {
    final pending = future;
    if (pending == null) {
      return const _Message(
          'Tus solicitudes aparecerán aquí cuando te conectes a Fixia.');
    }
    return FutureBuilder<List<ServiceRequest>>(
      future: pending,
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
              _Message('${snapshot.error}'),
              TextButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          );
        }
        final requests = snapshot.data!;
        if (requests.isEmpty) {
          return const _Message(
              'Todavía no has publicado solicitudes. Publica tu primer problema para recibir propuestas.');
        }
        final recent = requests.take(ClientDashboardPage.recentLimit).toList();
        return Column(
          children: [
            for (var i = 0; i < recent.length; i++) ...[
              _RequestCard(request: recent[i], onOpen: () => onOpen(recent[i])),
              if (i < recent.length - 1) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onOpen});

  final ServiceRequest request;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final action = pendingActionFor(request.status);
    return InkWell(
      key: ValueKey('client-request-${request.id}'),
      onTap: onOpen,
      borderRadius: BorderRadius.circular(FixiaRadii.card),
      child: DashboardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              request.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _CategoryBadge(label: request.category.label),
                Text(request.status.label),
                Text(
                  '${request.approximateLocation.zone}, ${request.approximateLocation.city}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (action != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: FixiaColors.secondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    action,
                    style: const TextStyle(
                      color: FixiaColors.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(color: FixiaColors.textSecondary),
      );
}

class _ClientHeader extends StatelessWidget {
  const _ClientHeader({this.onLogout});

  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          'assets/brand/fixia_logo.png',
          width: 90,
          height: 34,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          semanticLabel: 'Fixia',
        ),
        const Spacer(),
        if (onLogout != null)
          IconButton(
            key: const ValueKey('client-dashboard-logout'),
            tooltip: 'Cerrar sesión',
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
            style: IconButton.styleFrom(
              backgroundColor: FixiaColors.supportBackground,
              foregroundColor: FixiaColors.primary,
            ),
          ),
      ],
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: FixiaColors.supportBackground,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: FixiaColors.secondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ClientNavigationBar extends StatelessWidget {
  const _ClientNavigationBar({
    required this.onOpenHistory,
    required this.onPublishProblem,
    required this.onOpenProfile,
  });

  final VoidCallback? onOpenHistory;
  final VoidCallback? onPublishProblem;
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return MobileNavigationBar(
      items: [
        const MobileNavigationItem(
          itemKey: ValueKey('client-nav-inicio'),
          icon: Icons.home_rounded,
          label: 'Inicio',
          selected: true,
          onPressed: _noop,
        ),
        MobileNavigationItem(
          itemKey: const ValueKey('client-nav-historial'),
          icon: Icons.history_rounded,
          label: 'Historial',
          onPressed: onOpenHistory ?? _noop,
        ),
        MobileNavigationItem(
          itemKey: const ValueKey('client-publish-problem'),
          icon: Icons.add_rounded,
          label: 'Publicar',
          isAction: true,
          onPressed: onPublishProblem ?? _noop,
        ),
        MobileNavigationItem(
          itemKey: const ValueKey('client-nav-perfil'),
          icon: Icons.person_outline_rounded,
          label: 'Perfil',
          onPressed: onOpenProfile ?? _noop,
        ),
      ],
    );
  }
}

void _noop() {}
