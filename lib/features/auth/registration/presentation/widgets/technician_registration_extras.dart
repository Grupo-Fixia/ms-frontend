import 'package:flutter/material.dart';

import '../../../../../core/theme/fixia_theme.dart';

/// Etiqueta "Cuenta de técnico" sobre el título del registro de técnico.
class TechnicianBadge extends StatelessWidget {
  const TechnicianBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('technician-badge'),
      decoration: BoxDecoration(
        color: FixiaColors.supportBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.handyman_outlined,
              size: 18,
              color: FixiaColors.secondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Cuenta de técnico',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: FixiaColors.secondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Razones para registrarse como técnico. En pantalla ancha va al lado del
/// formulario; en celular, arriba y en versión corta ([compact]).
class TechnicianBenefits extends StatelessWidget {
  const TechnicianBenefits({super.key, this.compact = false});

  final bool compact;

  static const reasons = [
    (
      icon: Icons.near_me_outlined,
      title: 'Solicitudes cerca de ti',
      text: 'Recibe pedidos de clientes que están en tu zona.',
    ),
    (
      icon: Icons.category_outlined,
      title: 'Tú eliges qué ofreces',
      text: 'Define tus categorías: plomería, electricidad, pintura y más.',
    ),
    (
      icon: Icons.star_outline_rounded,
      title: 'Construye tu reputación',
      text: 'Cada servicio calificado te ayuda a conseguir más clientes.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      key: const ValueKey('technician-benefits'),
      decoration: BoxDecoration(
        color: FixiaColors.primary,
        borderRadius: BorderRadius.circular(FixiaRadii.card),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 20 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Por qué unirte a Fixia?',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: FixiaColors.white,
                fontSize: compact ? 20 : null,
              ),
            ),
            SizedBox(height: compact ? 14 : 20),
            for (var i = 0; i < reasons.length; i++) ...[
              if (i > 0) SizedBox(height: compact ? 10 : 18),
              _Reason(
                icon: reasons[i].icon,
                title: reasons[i].title,
                text: compact ? null : reasons[i].text,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Reason extends StatelessWidget {
  const _Reason({required this.icon, required this.title, this.text});

  final IconData icon;
  final String title;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = this.text;
    return Row(
      crossAxisAlignment:
          text == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            // Blanco al 12 % sobre el azul oscuro de la marca.
            color: const Color(0x1FFFFFFF),
            borderRadius: BorderRadius.circular(FixiaRadii.input),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: FixiaColors.accent, size: 20),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: FixiaColors.white),
              ),
              if (text != null) ...[
                const SizedBox(height: 4),
                Text(
                  text,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: FixiaColors.supportBackground),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
