import 'package:flutter/material.dart';

import '../../../core/theme/fixia_theme.dart';
import '../application/contract_use_cases.dart';
import '../domain/service_contract.dart';

/// Botón de una acción del servicio (iniciar, finalizar, cerrar, objetar):
/// pide confirmación, evita el doble envío y, haya funcionado o no, vuelve a
/// consultar el estado al servidor. Nunca muestra un éxito que el servidor
/// no confirmó.
class ServiceActionButton extends StatefulWidget {
  const ServiceActionButton({
    super.key,
    required this.label,
    required this.confirmTitle,
    required this.confirmText,
    required this.successMessage,
    required this.run,
    required this.onDone,
    this.primary = true,
    this.askReason = false,
  });

  final String label;
  final String confirmTitle;
  final String confirmText;
  final String successMessage;

  /// Recibe el motivo cuando [askReason] es verdadero.
  final Future<ServiceContract> Function(String? reason) run;
  final VoidCallback onDone;
  final bool primary;
  final bool askReason;

  @override
  State<ServiceActionButton> createState() => _ServiceActionButtonState();
}

class _ServiceActionButtonState extends State<ServiceActionButton> {
  bool _busy = false;

  Future<String?> _confirm() => showDialog<String>(
        context: context,
        builder: (context) => _ConfirmDialog(
          title: widget.confirmTitle,
          text: widget.confirmText,
          action: widget.label,
          askReason: widget.askReason,
        ),
      );

  Future<void> _press() async {
    if (_busy) return;
    final answer = await _confirm();
    if (answer == null || !mounted) return;
    setState(() => _busy = true);
    String message;
    try {
      await widget.run(widget.askReason ? answer : null);
      message = widget.successMessage;
    } catch (error) {
      message = '$error';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final child = _busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(widget.label);
    return widget.primary
        ? FilledButton(onPressed: _busy ? null : _press, child: child)
        : OutlinedButton(onPressed: _busy ? null : _press, child: child);
  }
}

class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({
    required this.title,
    required this.text,
    required this.action,
    required this.askReason,
  });

  final String title;
  final String text;
  final String action;
  final bool askReason;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _accept() {
    if (!widget.askReason) {
      Navigator.pop(context, '');
      return;
    }
    final text = _reason.text.trim();
    if (text.isEmpty) {
      setState(() => _error = ObjectServiceClosure.missingReasonMessage);
      return;
    }
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.text),
            if (widget.askReason) ...[
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('objection-reason'),
                controller: _reason,
                maxLines: 3,
                maxLength: ObjectServiceClosure.reasonMaxLength,
                decoration: InputDecoration(
                  labelText: '¿Qué falta o qué no quedó bien?',
                  errorText: _error,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Volver'),
          ),
          FilledButton(onPressed: _accept, child: Text(widget.action)),
        ],
      );
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(color: FixiaColors.textSecondary),
      );
}

/// Acciones del técnico según el estado del servicio (GC-442). Iniciar es
/// GC-437/GC-438 y se incluye solo si se entrega [start].
List<Widget> technicianServiceActions({
  required ServiceContract contract,
  required Future<ServiceContract> Function() finish,
  required VoidCallback onDone,
  Future<ServiceContract> Function()? start,
}) {
  switch (contract.serviceStatus) {
    case ServiceRequestStatus.contracted:
      if (start == null) return const [];
      return [
        ServiceActionButton(
          label: 'Iniciar servicio',
          confirmTitle: 'Iniciar servicio',
          confirmText:
              'Avisa al cliente que comenzaste el trabajo acordado en la contratación.',
          successMessage: 'Servicio iniciado.',
          run: (_) => start(),
          onDone: onDone,
        ),
      ];
    case ServiceRequestStatus.inProgress:
      return [
        ServiceActionButton(
          label: 'Declarar trabajo terminado',
          confirmTitle: 'Declarar trabajo terminado',
          confirmText:
              'El cliente revisará el trabajo y confirmará el cierre. El servicio no queda cerrado hasta que él lo confirme.',
          successMessage:
              'Declaraste el trabajo terminado. Falta la confirmación del cliente.',
          run: (_) => finish(),
          onDone: onDone,
        ),
      ];
    case ServiceRequestStatus.technicianFinished:
      return const [_Note('Esperando que el cliente confirme el cierre.')];
    case ServiceRequestStatus.closed:
      return const [_Note('Servicio cerrado. ¡Buen trabajo!')];
    default:
      return const [];
  }
}

/// Acciones del cliente según el estado del servicio (GC-442): confirmar el
/// cierre solo cuando el técnico declaró terminado, u objetar con un motivo.
List<Widget> clientServiceActions({
  required ServiceContract contract,
  required Future<ServiceContract> Function() confirmClosure,
  required Future<ServiceContract> Function(String reason) object,
  required VoidCallback onDone,
}) {
  switch (contract.serviceStatus) {
    case ServiceRequestStatus.contracted:
      return const [
        _Note('El técnico iniciará el servicio en la fecha acordada.')
      ];
    case ServiceRequestStatus.inProgress:
      return const [_Note('El técnico está trabajando en tu servicio.')];
    case ServiceRequestStatus.technicianFinished:
      return [
        const _Note(
            'El técnico declaró el trabajo terminado. Revísalo y confirma el cierre.'),
        ServiceActionButton(
          label: 'Confirmar cierre',
          confirmTitle: 'Confirmar cierre del servicio',
          confirmText:
              'Confirmas que el trabajo quedó como se acordó. El servicio quedará cerrado y no se puede reabrir.',
          successMessage: 'Servicio cerrado. ¡Gracias por usar Fixia!',
          run: (_) => confirmClosure(),
          onDone: onDone,
        ),
        ServiceActionButton(
          label: 'Algo no quedó bien',
          confirmTitle: 'Objetar el cierre',
          confirmText:
              'El servicio vuelve a ejecución y el técnico verá tu motivo.',
          successMessage:
              'Enviamos tu objeción. El servicio volvió a ejecución.',
          primary: false,
          askReason: true,
          run: (reason) => object(reason!),
          onDone: onDone,
        ),
      ];
    case ServiceRequestStatus.closed:
      return const [_Note('Servicio cerrado.')];
    default:
      return const [];
  }
}
