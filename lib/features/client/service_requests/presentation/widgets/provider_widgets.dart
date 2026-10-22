import 'package:flutter/material.dart';

import '../../../../../core/theme/fixia_theme.dart';

/// Estrellas de reputación (de 0 a 5, con media estrella).
class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.rating,
    this.ratingCount,
    this.size = 18,
  });

  final double? rating;
  final int? ratingCount;
  final double size;

  @override
  Widget build(BuildContext context) {
    final value = rating;
    if (value == null) {
      return Text(
        'Sin calificaciones aún',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: FixiaColors.textSecondary),
      );
    }
    return Semantics(
      label: 'Calificación ${value.toStringAsFixed(1)} de 5',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              value >= i
                  ? Icons.star_rounded
                  : (value >= i - 0.5
                      ? Icons.star_half_rounded
                      : Icons.star_outline_rounded),
              size: size,
              color: const Color(0xFFF5A623),
            ),
          const SizedBox(width: 6),
          Text(
            value.toStringAsFixed(1) +
                (ratingCount == null ? '' : ' ($ratingCount)'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Avatar del prestador: iniciales cuando no hay foto.
class ProviderAvatar extends StatelessWidget {
  const ProviderAvatar({
    super.key,
    required this.initials,
    this.photoUrl,
    this.radius = 26,
  });

  final String initials;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: FixiaColors.supportBackground,
      foregroundImage: url == null ? null : NetworkImage(url),
      child: Text(
        initials,
        style: TextStyle(
          color: FixiaColors.primary,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }
}
