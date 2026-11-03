import 'package:flutter/material.dart';

import '../../../core/layout/app_shell.dart';
import '../../../core/theme/fixia_theme.dart';
import '../../../core/widgets/fixia_ui.dart';
import '../domain/service_evaluation.dart';
import '../domain/service_history_entry.dart';
import 'widgets/service_evaluations_view.dart';

/// Detalle de un servicio del historial (GC-449): la contratación con sus
/// condiciones, estado e historial de cambios ([contractSection], la misma
/// sección de contrato que ya usan cliente y técnico) y las evaluaciones
/// reales del servicio, consultadas cada vez que se abre.
class ServiceHistoryDetailPage extends StatefulWidget {
  const ServiceHistoryDetailPage({
    super.key,
    required this.entry,
    required this.destination,
    required this.userId,
    required this.contractSection,
    required this.loadEvaluations,
  });

  final ServiceHistoryEntry entry;

  /// Sección del menú que queda marcada: «Mis servicios» del rol.
  final ShellDestination destination;
  final String userId;

  /// Contratación del servicio según el rol, con sus acciones.
  final Widget contractSection;
  final Future<List<ServiceEvaluation>> Function() loadEvaluations;

  @override
  State<ServiceHistoryDetailPage> createState() =>
      _ServiceHistoryDetailPageState();
}

class _ServiceHistoryDetailPageState extends State<ServiceHistoryDetailPage> {
  late Future<List<ServiceEvaluation>> _evaluations = widget.loadEvaluations();

  void _reloadEvaluations() {
    setState(() {
      _evaluations = widget.loadEvaluations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return AppShell(
      destination: widget.destination,
      subpage: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BackLink(label: 'Mis servicios'),
          PageHeader(
            title: entry.category?.label ?? 'Servicio',
            subtitle: '${entry.role.label}: lo acordado, su avance y las '
                'evaluaciones del servicio.',
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  widget.contractSection,
                  const SizedBox(height: 20),
                  ServiceEvaluationsPanel(child: _evaluationsContent(entry)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _evaluationsContent(ServiceHistoryEntry entry) =>
      FutureBuilder<List<ServiceEvaluation>>(
        future: _evaluations,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LinearProgressIndicator(
                key: ValueKey('service-evaluations-loading'));
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
                  key: const ValueKey('service-evaluations-retry'),
                  onPressed: _reloadEvaluations,
                  child: const Text('Reintentar'),
                ),
              ],
            );
          }
          return ServiceEvaluationsView(
            evaluations: snapshot.data!,
            userId: widget.userId,
            stage: entry.stage,
          );
        },
      );
}
