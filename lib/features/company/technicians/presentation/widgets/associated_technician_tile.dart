import 'package:flutter/material.dart';

import '../../../../../core/theme/fixia_theme.dart';
import '../../domain/associated_technician.dart';

/// Datos públicos de un técnico de la empresa (GC-467). Lo usan «Mis
/// técnicos» y el selector de la postulación empresarial (GC-469); con
/// [selected] y [onTap] sirve como opción seleccionable.
class AssociatedTechnicianTile extends StatelessWidget {
  const AssociatedTechnicianTile({
    super.key,
    required this.technician,
    this.selected = false,
    this.onTap,
  });

  final AssociatedTechnician technician;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = <String>[
      if (technician.categories.isNotEmpty)
        technician.categories.map((category) => category.label).join(' · '),
      if (technician.city != null) technician.city!,
      if (technician.yearsOfExperience != null)
        '${technician.yearsOfExperience} '
            '${technician.yearsOfExperience == 1 ? 'año' : 'años'} de experiencia',
    ];
    return Material(
      color: selected ? FixiaColors.supportBackground : FixiaColors.white,
      borderRadius: BorderRadius.circular(FixiaRadii.card),
      child: InkWell(
        key: ValueKey('associated-technician-${technician.userId}'),
        borderRadius: BorderRadius.circular(FixiaRadii.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FixiaRadii.card),
            border: Border.all(
              color: selected ? FixiaColors.secondary : const Color(0xFFE3EAF4),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: FixiaColors.supportBackground,
                foregroundColor: FixiaColors.primary,
                child: Text(_initials(technician.name)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(technician.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    _VerificationLabel(status: technician.verificationStatus),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(details.join(' · '),
                          style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: FixiaColors.secondary),
            ],
          ),
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase());
    return parts.isEmpty ? '?' : parts.join();
  }
}

class _VerificationLabel extends StatelessWidget {
  const _VerificationLabel({required this.status});

  final VerificationStatus? status;

  @override
  Widget build(BuildContext context) {
    final verified = status == VerificationStatus.valid;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          verified ? Icons.verified_outlined : Icons.info_outline,
          size: 16,
          color: verified ? FixiaColors.accent : FixiaColors.textSecondary,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            status?.label ?? 'Verificación no informada',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
