import 'package:flutter/material.dart';

import '../../../core/layout/app_shell.dart';
import '../../../core/theme/fixia_theme.dart';
import '../../../core/widgets/fixia_ui.dart';
import '../domain/service_evaluation.dart';
import '../domain/service_history_entry.dart';
import '../domain/service_history_exceptions.dart';
import 'widgets/service_evaluation_form.dart';
import 'widgets/service_evaluations_view.dart';

/// Detalle de un servicio del historial (GC-449): la contratación con sus
/// condiciones, estado e historial de cambios ([contractSection], la misma
/// sección de contrato que ya usan cliente y técnico) y las evaluaciones
/// reales del servicio, consultadas cada vez que se abre. Si el servicio
/// está cerrado y quien consulta aún no calificó, puede hacerlo aquí
/// ([submitEvaluation], GC-445).
class ServiceHistoryDetailPage extends StatefulWidget {
  const ServiceHistoryDetailPage({
    super.key,
    required this.entry,
    required this.destination,
    required this.userId,
    required this.contractSection,
    required this.loadEvaluations,
    this.submitEvaluation,
  });

  final ServiceHistoryEntry entry;

  /// Sección del menú que queda marcada: «Mis servicios» del rol.
  final ShellDestination destination;
  final String userId;

  /// Contratación del servicio según el rol, con sus acciones.
  final Widget contractSection;
  final Future<List<ServiceEvaluation>> Function() loadEvaluations;

  /// Registra la calificación en ms-users; sin él no se ofrece calificar.
  final Future<void> Function(int rating, String? comment)? submitEvaluation;

  static const thanksMessage = '¡Gracias! Tu calificación quedó registrada.';

  @override
  State<ServiceHistoryDetailPage> createState() =>
      _ServiceHistoryDetailPageState();
}

class _ServiceHistoryDetailPageState extends State<ServiceHistoryDetailPage> {
  late Future<List<ServiceEvaluation>> _evaluations = widget.loadEvaluations();

  /// Resultado del último envío (agradecimiento o «ya habías calificado»).
  (String, PillTone)? _notice;

  /// ms-users no admite calificar este servicio; el formulario no vuelve.
  String? _rejection;

  void _reloadEvaluations() {
    setState(() {
      _evaluations = widget.loadEvaluations();
    });
  }

  /// Tras enviar se vuelve a consultar ms-users: lo que se muestra es lo
  /// guardado, no lo que se escribió.
  Future<void> _submit(int rating, String? comment) async {
    try {
      await widget.submitEvaluation!(rating, comment);
      if (!mounted) return;
      _notice = (ServiceHistoryDetailPage.thanksMessage, PillTone.success);
      _reloadEvaluations();
    } on ServiceHistoryFailure catch (failure) {
      if (!mounted) rethrow;
      if (failure.alreadyEvaluated) {
        _notice = (failure.message, PillTone.info);
        _reloadEvaluations();
      } else if (failure.notAllowed) {
        setState(() => _rejection = failure.message);
      } else {
        rethrow;
      }
    }
  }

  bool _canEvaluate(List<ServiceEvaluation> evaluations) =>
      widget.submitEvaluation != null &&
      _rejection == null &&
      widget.entry.stage == HistoryStage.closed &&
      !evaluations.any((e) => e.isBy(widget.userId));

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
          final evaluations = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_notice case (final message, final tone)) ...[
                NoticeBanner(
                  key: const ValueKey('service-evaluation-notice'),
                  message: message,
                  tone: tone,
                  icon: tone == PillTone.success
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                ),
                const SizedBox(height: 12),
              ],
              ServiceEvaluationsView(
                evaluations: evaluations,
                userId: widget.userId,
                stage: entry.stage,
              ),
              if (_rejection != null) ...[
                const SizedBox(height: 12),
                NoticeBanner(
                  key: const ValueKey('service-evaluation-rejected'),
                  message: _rejection!,
                  tone: PillTone.neutral,
                  icon: Icons.info_outline_rounded,
                ),
              ],
              if (_canEvaluate(evaluations)) ...[
                const SizedBox(height: 16),
                ServiceEvaluationForm(
                  title: entry.role == HistoryRole.client
                      ? 'Califica al técnico'
                      : 'Califica al cliente',
                  onSubmit: _submit,
                ),
              ],
            ],
          );
        },
      );
}
