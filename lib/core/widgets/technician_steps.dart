import 'package:flutter/material.dart';

import '../theme/fixia_theme.dart';

/// Pasos para que un técnico empiece a trabajar en Fixia: crear la cuenta
/// (GC-235), completar el perfil profesional (GC-237) y la verificación.
///
/// Refleja lo que hace ms-users: la cuenta se crea con verificación pendiente
/// y el perfil se completa después. Los pasos anteriores a [currentStep]
/// aparecen como completados.
class TechnicianSteps extends StatelessWidget {
  const TechnicianSteps({super.key, this.currentStep = 1})
      : assert(currentStep >= 1 && currentStep <= 3);

  /// Paso en curso (1 a 3).
  final int currentStep;

  static const labels = [
    'Crea tu cuenta',
    'Completa tu perfil profesional',
    'Verificación de Fixia',
  ];

  _StepState _stateOf(int step) {
    if (step < currentStep) return _StepState.done;
    return step == currentStep ? _StepState.current : _StepState.next;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('technician-steps'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: _Step(
              number: i + 1,
              label: labels[i],
              state: _stateOf(i + 1),
              showLineBefore: i > 0,
              showLineAfter: i < labels.length - 1,
            ),
          ),
      ],
    );
  }
}

enum _StepState { done, current, next }

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.label,
    required this.state,
    required this.showLineBefore,
    required this.showLineAfter,
  });

  final int number;
  final String label;
  final _StepState state;
  final bool showLineBefore;
  final bool showLineAfter;

  static const _lineColor = Color(0xFFC9D6E8);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget line(bool visible) => Expanded(
          child: Container(
            height: 2,
            color: visible ? _lineColor : Colors.transparent,
          ),
        );
    final isCurrent = state == _StepState.current;
    final isDone = state == _StepState.done;
    final highlighted = isCurrent || isDone;
    final status = switch (state) {
      _StepState.done => ' (completado)',
      _StepState.current => ' (actual)',
      _StepState.next => '',
    };
    return Semantics(
      label: 'Paso $number: $label$status',
      excludeSemantics: true,
      child: Column(
        children: [
          Row(
            children: [
              line(showLineBefore),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? FixiaColors.accent
                      : (isCurrent ? FixiaColors.secondary : FixiaColors.white),
                  border: Border.all(
                    color: isDone
                        ? FixiaColors.accent
                        : (isCurrent ? FixiaColors.secondary : _lineColor),
                    width: 2,
                  ),
                ),
                child: isDone
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: FixiaColors.white,
                      )
                    : Text(
                        '$number',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: isCurrent
                              ? FixiaColors.white
                              : FixiaColors.textSecondary,
                        ),
                      ),
              ),
              line(showLineAfter),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: highlighted ? FixiaColors.primary : null,
                fontWeight: isCurrent ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
