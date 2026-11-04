import 'package:flutter/material.dart';

import '../../../../core/theme/fixia_theme.dart';
import '../../domain/service_evaluation.dart';

/// Formulario para calificar a la contraparte de un servicio cerrado
/// (GC-445): de 1 a 5 estrellas y un comentario opcional. Mientras se envía
/// no se puede volver a enviar; el error del servidor se muestra tal cual.
class ServiceEvaluationForm extends StatefulWidget {
  const ServiceEvaluationForm({
    super.key,
    required this.title,
    required this.onSubmit,
  });

  /// «Califica al técnico» o «Califica al cliente».
  final String title;

  /// Envía la calificación; si falla, lanza el error que se muestra.
  final Future<void> Function(int rating, String? comment) onSubmit;

  @override
  State<ServiceEvaluationForm> createState() => _ServiceEvaluationFormState();
}

class _ServiceEvaluationFormState extends State<ServiceEvaluationForm> {
  final _comment = TextEditingController();
  int _rating = 0;
  bool _sending = false;
  String? _error;

  static const _ratingLabels = {
    1: 'Muy malo',
    2: 'Malo',
    3: 'Regular',
    4: 'Bueno',
    5: 'Excelente',
  };

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0 || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_rating, _comment.text);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        key: const ValueKey('service-evaluation-form'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tu calificación queda registrada y no se puede cambiar después.',
            style: TextStyle(fontSize: 13, color: FixiaColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = NewServiceEvaluation.minRating;
                  i <= NewServiceEvaluation.maxRating;
                  i++)
                IconButton(
                  key: ValueKey('service-evaluation-star-$i'),
                  tooltip: '$i de 5 estrellas',
                  onPressed:
                      _sending ? null : () => setState(() => _rating = i),
                  icon: Icon(
                    i <= _rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 32,
                    color: i <= _rating
                        ? const Color(0xFFF5A524)
                        : FixiaColors.textSecondary,
                  ),
                ),
              if (_rating > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    _ratingLabels[_rating]!,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('service-evaluation-comment'),
            controller: _comment,
            enabled: !_sending,
            maxLength: NewServiceEvaluation.maxCommentLength,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Comentario (opcional)',
              helperText: 'Solo lo verán tú y tu contraparte.',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              key: const ValueKey('service-evaluation-error'),
              style: const TextStyle(color: FixiaColors.error),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('service-evaluation-submit'),
            onPressed: _rating == 0 || _sending ? null : _submit,
            child: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: FixiaColors.white),
                  )
                : const Text('Enviar calificación'),
          ),
        ],
      );
}
