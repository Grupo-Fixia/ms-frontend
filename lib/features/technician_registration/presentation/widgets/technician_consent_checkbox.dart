import 'package:flutter/material.dart';

import '../../../../core/theme/fixia_theme.dart';

class TechnicianConsentCheckbox extends StatelessWidget {
  const TechnicianConsentCheckbox({
    super.key,
    required this.value,
    required this.policyVersion,
    required this.acceptedAt,
    required this.onChanged,
  });

  final bool value;
  final String policyVersion;
  final DateTime? acceptedAt;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final acceptedAt = this.acceptedAt;
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(FixiaRadii.consent),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: FormField<bool>(
          initialValue: value,
          validator: (accepted) => accepted == true
              ? null
              : 'Debes aceptar el tratamiento de datos.',
          builder: (field) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: field.value ?? false,
                onChanged: (checked) {
                  final accepted = checked ?? false;
                  field.didChange(accepted);
                  onChanged(accepted);
                },
                title: const Text(
                  'Autorizo el tratamiento de mis datos personales de acuerdo '
                  'con la política de privacidad.',
                ),
                subtitle: Text(
                  'Política de tratamiento de datos · $policyVersion',
                ),
              ),
              if (field.errorText != null)
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Text(
                    field.errorText!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              if (acceptedAt != null)
                Padding(
                  padding: const EdgeInsets.only(left: 48, bottom: 8),
                  child: Text(
                    'Consentimiento aceptado: '
                    '${acceptedAt.toLocal().toString().substring(0, 16)}',
                    key: const ValueKey('consent-accepted-at'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
