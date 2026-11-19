import 'package:flutter/material.dart';

import '../domain/reputation.dart';
import '../theme/fixia_theme.dart';

/// Estrella con el promedio y el número de calificaciones (GC-447). Sin
/// calificaciones lo dice, en vez de mostrar estrellas inventadas.
class ReputationBadge extends StatelessWidget {
  const ReputationBadge(
      {super.key, required this.reputation, this.large = false});

  final Reputation? reputation;

  /// Versión grande para el perfil propio.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final value = reputation;
    final size = large ? 22.0 : 16.0;
    if (value == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_border_rounded,
              size: size, color: FixiaColors.textSecondary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Sin calificaciones aún',
              style: TextStyle(
                fontSize: large ? 14 : 12.5,
                color: FixiaColors.textSecondary,
              ),
            ),
          ),
        ],
      );
    }
    return Semantics(
      label: '${value.averageLabel} de 5, ${value.countLabel}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: size, color: const Color(0xFFF5A524)),
          const SizedBox(width: 4),
          Text(
            value.averageLabel,
            style: TextStyle(
              fontSize: large ? 20 : 14,
              fontWeight: FontWeight.w700,
              color: FixiaColors.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '(${value.countLabel})',
              style: TextStyle(
                fontSize: large ? 14 : 12.5,
                color: FixiaColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
