import 'package:flutter/material.dart';

import '../../../../core/layout/app_shell.dart';
import '../../../../core/theme/fixia_theme.dart';
import '../../../../core/widgets/fixia_ui.dart';
import '../../service_requests/domain/service_request.dart';
import '../../service_requests/presentation/service_request_list.dart';

export '../../service_requests/presentation/service_request_list.dart'
    show pendingActionFor, toneFor;

/// Inicio del cliente. Solo datos reales de ms-services: el resumen de sus
/// solicitudes, lo que le falta hacer en cada una y las más recientes. En
/// escritorio usa el marco con barra lateral; en celular, barra inferior.
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
    this.onOpenChat,
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

  /// Chat prototipo de GC-431. Es una simulación: no toca solicitudes,
  /// cotizaciones ni contratos.
  final VoidCallback? onOpenChat;

  /// Cuántas solicitudes recientes se muestran en el inicio.
  static const recentLimit = 3;

  /// Cuántas acciones pendientes se muestran.
  static const attentionLimit = 4;

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

  /// Navegación con los callbacks de la pantalla; si no los tiene, la del
  /// marco (la que arma `main.dart`).
  void _navigate(ShellDestination destination) {
    final scope = FixiaShellScope.maybeOf(context);
    switch (destination) {
      case ShellDestination.clientRequests:
        final open = widget.onOpenHistory;
        if (open != null) return open();
      case ShellDestination.clientProfile:
        final open = widget.onOpenProfile ?? widget.onOpenSettings;
        if (open != null) return open();
        if (scope?.onNavigate == null) return _showClientProfileUnavailable();
      default:
        break;
    }
    scope?.onNavigate?.call(destination);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.firstName?.trim() ?? '';
    return AppShell(
      destination: ShellDestination.clientHome,
      userName: name.isEmpty ? null : name,
      onNavigate: _navigate,
      onLogout: widget.onLogout,
      onPrimaryAction: widget.onPublishProblem ?? _noop,
      child: FutureBuilder<List<ServiceRequest>>(
        future: _requests,
        builder: (context, snapshot) {
          final loading = _requests != null &&
              snapshot.connectionState != ConnectionState.done;
          final requests = snapshot.hasData ? snapshot.data! : null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: name.isEmpty ? 'Bienvenido a Fixia' : 'Hola, $name',
                titleKey: const ValueKey('client-dashboard-greeting'),
                subtitle: requests == null
                    ? '¿Qué necesitas arreglar hoy?'
                    : _subtitle(requests),
                actions: [
                  if (widget.onOpenChat != null)
                    Tooltip(
                      message: 'Abrir chat',
                      child: OutlinedButton.icon(
                        key: const ValueKey('client-open-chat-prototype'),
                        onPressed: widget.onOpenChat,
                        icon: const Icon(Icons.chat_bubble_outline_rounded,
                            size: 18),
                        label: const Text('Chat de demostración'),
                      ),
                    ),
                  FilledButton.icon(
                    key: const ValueKey('client-dashboard-publish'),
                    onPressed: widget.onPublishProblem ?? _noop,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Publicar un problema'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              StatGrid(
                children: [
                  StatCard(
                    label: 'Abiertas',
                    value: _count(requests, _isOpen),
                    caption: 'Publicadas o con prestador elegido',
                  ),
                  StatCard(
                    label: 'En curso',
                    value: _count(requests, _isInProgress),
                    caption: 'Contratadas o en ejecución',
                  ),
                  StatCard(
                    label: 'Cerradas',
                    value: _count(requests, _isClosed),
                    caption: 'Servicios terminados',
                  ),
                ],
              ),
              const SizedBox(height: 28),
              TwoColumns(
                main: _main(loading, snapshot),
                side: const _HowItWorks(),
              ),
            ],
          );
        },
      ),
    );
  }

  String _subtitle(List<ServiceRequest> requests) {
    if (requests.isEmpty) return '¿Qué necesitas arreglar hoy?';
    final pending = requests.where(_needsClient).length;
    if (pending == 0) return 'Todo al día con tus solicitudes.';
    return pending == 1
        ? 'Tienes 1 solicitud que requiere tu atención.'
        : 'Tienes $pending solicitudes que requieren tu atención.';
  }

  Widget _main(bool loading, AsyncSnapshot<List<ServiceRequest>> snapshot) {
    if (_requests == null) {
      return const EmptyState(
        message: 'Tus solicitudes aparecerán aquí cuando te conectes a Fixia.',
        icon: Icons.cloud_off_outlined,
      );
    }
    if (loading) return const SectionLoading();
    if (snapshot.hasError) {
      return EmptyState(
        message: '${snapshot.error}',
        icon: Icons.error_outline_rounded,
        action: TextButton(onPressed: _reload, child: const Text('Reintentar')),
      );
    }
    final requests = snapshot.data!;
    if (requests.isEmpty) {
      return EmptyState(
        message:
            'Todavía no has publicado solicitudes. Publica tu primer problema para recibir propuestas.',
        icon: Icons.home_repair_service_outlined,
        action: FilledButton(
          onPressed: widget.onPublishProblem ?? _noop,
          child: const Text('Publicar un problema'),
        ),
      );
    }
    final attention = requests
        .where(_needsClient)
        .take(ClientDashboardPage.attentionLimit)
        .toList();
    final recent = requests.take(ClientDashboardPage.recentLimit).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (attention.isNotEmpty) ...[
          const SectionTitle(title: 'Requiere tu atención'),
          for (final r in attention) ...[
            _AttentionCard(request: r, onOpen: () => _open(r)),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 16),
        ],
        SectionTitle(
          title: 'Solicitudes recientes',
          action: TextButton(
            onPressed: widget.onOpenHistory ?? _noop,
            child: const Text('Ver todas'),
          ),
        ),
        ServiceRequestList(requests: recent, onOpen: _open),
      ],
    );
  }
}

/// Solo lo que espera una decisión del cliente: la cotización recibida o la
/// confirmación del cierre. «Revisa los postulantes» se ve en la lista.
bool _needsClient(ServiceRequest r) =>
    r.status == ServiceRequestStatus.providerSelected ||
    r.status == ServiceRequestStatus.technicianFinished;

bool _isOpen(ServiceRequest r) =>
    r.status == ServiceRequestStatus.published ||
    r.status == ServiceRequestStatus.providerSelected;

bool _isInProgress(ServiceRequest r) =>
    r.status == ServiceRequestStatus.contracted ||
    r.status == ServiceRequestStatus.inProgress ||
    r.status == ServiceRequestStatus.technicianFinished;

bool _isClosed(ServiceRequest r) => r.status == ServiceRequestStatus.closed;

String _count(
        List<ServiceRequest>? requests, bool Function(ServiceRequest) test) =>
    requests == null ? '–' : '${requests.where(test).length}';

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.request, required this.onOpen});

  final ServiceRequest request;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final finished = request.status == ServiceRequestStatus.technicianFinished;
    final action = pendingActionFor(request.status)!;
    return FixiaPanel(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: finished
                        ? const Color(0xFFDCF5EF)
                        : FixiaColors.supportBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    finished
                        ? Icons.task_alt_rounded
                        : Icons.request_quote_outlined,
                    color: finished
                        ? const Color(0xFF00745F)
                        : FixiaColors.secondary,
                  ),
                ),
                const SizedBox(width: 14),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${request.category.label} · ${request.approximateLocation.zone}, ${request.approximateLocation.city}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: FixiaColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusPill(
                label: request.status.label,
                tone: toneFor(request.status),
              ),
              FilledButton(
                key: ValueKey('client-request-${request.id}'),
                onPressed: onOpen,
                child: Text(action),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const _steps = [
    ('Publica tu problema', 'Con presupuesto y ubicación aproximada.'),
    ('Compara y elige', 'Precio, experiencia y verificación de cada técnico.'),
    ('Acepta la cotización', 'Queda un contrato con lo acordado.'),
    ('Confirma el cierre', 'Solo cuando el trabajo quedó bien.'),
  ];

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: FixiaColors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cómo funciona Fixia',
              style: TextStyle(
                color: FixiaColors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            for (var i = 0; i < _steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == _steps.length - 1
                            ? FixiaColors.accent
                            : FixiaColors.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: FixiaColors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _steps[i].$1,
                            style: const TextStyle(
                              color: FixiaColors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _steps[i].$2,
                            style: const TextStyle(
                              color: Color(0xFFB7CCE8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}

void _noop() {}
