import 'package:flutter/material.dart';

import '../theme/fixia_theme.dart';

/// Casilla obligatoria de consentimiento para el tratamiento de datos
/// (RF-007). Muestra la versión de la política aceptada.
class DataConsentField extends StatelessWidget {
  const DataConsentField({
    super.key,
    required this.value,
    required this.policyVersion,
    required this.enabled,
    required this.onChanged,
    this.checkboxKey = const ValueKey('client-consent-checkbox'),
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
  });

  final bool value;
  final String policyVersion;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final Key checkboxKey;
  final AutovalidateMode autovalidateMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FormField<bool>(
      initialValue: value,
      autovalidateMode: autovalidateMode,
      validator: (accepted) => accepted == true
          ? null
          : 'Debes aceptar el tratamiento de datos para crear la cuenta.',
      builder: (field) => Container(
        decoration: BoxDecoration(
          color: FixiaColors.supportBackground,
          borderRadius: BorderRadius.circular(FixiaRadii.input),
          border: Border.all(
            color:
                field.hasError ? theme.colorScheme.error : Colors.transparent,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                key: checkboxKey,
                value: field.value ?? false,
                enabled: enabled,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: FixiaColors.secondary,
                onChanged: (checked) {
                  final accepted = checked ?? false;
                  field.didChange(accepted);
                  onChanged(accepted);
                },
                title: Text(
                  'Autorizo el tratamiento de mis datos personales según la '
                  'política de privacidad de Fixia.',
                  style: theme.textTheme.bodyMedium,
                ),
                subtitle: Text(
                  'Política de tratamiento de datos · versión $policyVersion',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
            if (field.errorText != null)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  field.errorText!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
