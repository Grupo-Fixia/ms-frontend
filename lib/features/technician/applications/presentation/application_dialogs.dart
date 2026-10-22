import 'package:flutter/material.dart';

import '../../../../core/theme/fixia_theme.dart';
import '../domain/application_exceptions.dart';

/// Respuesta del técnico en el modal de confirmación de la postulación.
class ApplyConfirmation {
  const ApplyConfirmation({this.guidingMessage});

  /// Mensaje orientativo elegido; `null` si no eligió ninguno. La API de
  /// postulaciones solo recibe la solicitud, así que no se envía.
  final String? guidingMessage;
}

const applyGuidingMessages = <String>[
  'Puedo atender hoy mismo',
  'Cuento con herramientas y materiales',
  'Puedo hacer una visita de diagnóstico',
];

/// Modal de confirmación antes de postularse. Devuelve `null` si cancela.
Future<ApplyConfirmation?> showApplyConfirmationDialog(
  BuildContext context, {
  required String requestTitle,
}) {
  return showDialog<ApplyConfirmation>(
    context: context,
    builder: (context) => _ApplyConfirmationDialog(requestTitle: requestTitle),
  );
}

class _ApplyConfirmationDialog extends StatefulWidget {
  const _ApplyConfirmationDialog({required this.requestTitle});

  final String requestTitle;

  @override
  State<_ApplyConfirmationDialog> createState() =>
      _ApplyConfirmationDialogState();
}

class _ApplyConfirmationDialogState extends State<_ApplyConfirmationDialog> {
  String? _message;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('apply-confirmation-dialog'),
      title: const Text('¿Postularte a esta solicitud?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.requestTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'El cliente verá tu perfil y podrá elegirte como prestador.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: const ValueKey('apply-guiding-message'),
              isExpanded: true,
              value: _message,
              decoration: const InputDecoration(
                labelText: 'Mensaje orientativo (opcional)',
              ),
              items: [
                for (final message in applyGuidingMessages)
                  DropdownMenuItem(value: message, child: Text(message)),
              ],
              onChanged: (value) => setState(() => _message = value),
            ),
            const SizedBox(height: 6),
            Text(
              'Por ahora es solo orientativo y no se envía al cliente.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('apply-cancel-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('apply-confirm-button'),
          onPressed: () => Navigator.of(context)
              .pop(ApplyConfirmation(guidingMessage: _message)),
          child: const Text('Confirmar postulación'),
        ),
      ],
    );
  }
}

/// Diálogo de resultado cuando la postulación no se pudo registrar: explica
/// el motivo (sin verificación, no elegible o rol) y el siguiente paso.
Future<void> showApplicationFailureDialog(
  BuildContext context,
  ApplicationFailure failure,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      key: const ValueKey('apply-failure-dialog'),
      icon: const Icon(Icons.error_outline, color: FixiaColors.error),
      title: Text(failure.message),
      content: failure.isNotEligible
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final reason in failure.reasons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• ${reason.message}'),
                  ),
              ],
            )
          : null,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}
