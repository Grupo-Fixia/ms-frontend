import 'package:flutter/material.dart';

import '../../../../core/theme/fixia_theme.dart';
import '../../../../core/widgets/fixia_ui.dart';
import '../../domain/service_evaluation.dart';
import '../../domain/service_history_entry.dart';

/// Estrellas de una evaluación (1 a 5), legibles por lectores de pantalla.
class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.rating, this.size = 16});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: '$rating de 5 estrellas',
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 1; i <= 5; i++)
                Icon(
                  i <= rating ? Icons.star_rounded : Icons.star_border_rounded,
                  size: size,
                  color: i <= rating
                      ? const Color(0xFFF5A524)
                      : FixiaColors.textSecondary,
                ),
            ],
          ),
        ),
      );
}

/// Evaluaciones de un servicio en el detalle del historial (GC-449). Solo
/// muestra las que existen en ms-users; si no hay, lo dice según la etapa
/// del servicio, sin estrellas ficticias.
class ServiceEvaluationsView extends StatelessWidget {
  const ServiceEvaluationsView({
    super.key,
    required this.evaluations,
    required this.userId,
    required this.stage,
  });

  final List<ServiceEvaluation> evaluations;

  /// Quien consulta, para distinguir la evaluación propia de la recibida.
  final String userId;
  final HistoryStage stage;

  static const notClosedMessage =
      'Las evaluaciones se habilitan cuando el servicio se cierra.';
  static const noneYetMessage = 'Este servicio todavía no tiene evaluaciones.';

  @override
  Widget build(BuildContext context) {
    if (evaluations.isEmpty) {
      return Text(
        stage == HistoryStage.closed ? noneYetMessage : notClosedMessage,
        key: const ValueKey('service-evaluations-empty'),
        style: const TextStyle(color: FixiaColors.textSecondary),
      );
    }
    final received = evaluations.where((e) => e.isFor(userId)).toList();
    final given = evaluations.where((e) => e.isBy(userId)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final evaluation in received)
          _EvaluationTile(
              title: 'Evaluación que recibiste', evaluation: evaluation),
        for (final evaluation in given)
          _EvaluationTile(title: 'Tu evaluación', evaluation: evaluation),
      ],
    );
  }
}

class _EvaluationTile extends StatelessWidget {
  const _EvaluationTile({required this.title, required this.evaluation});

  final String title;
  final ServiceEvaluation evaluation;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                color: FixiaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            RatingStars(rating: evaluation.rating, size: 20),
            if (evaluation.comment != null) ...[
              const SizedBox(height: 4),
              Text(
                '“${evaluation.comment}”',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      );
}

/// Sección «Evaluaciones» del detalle, con el mismo panel de las demás
/// secciones del marco.
class ServiceEvaluationsPanel extends StatelessWidget {
  const ServiceEvaluationsPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => FixiaPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle(title: 'Evaluaciones'),
            child,
          ],
        ),
      );
}
