import 'package:flutter/material.dart';

import '../../../../core/theme/fixia_theme.dart';
import '../../../home/presentation/widgets/dashboard_components.dart';
import '../application/provider_profile_use_cases.dart';
import '../domain/provider_public_profile.dart';
import '../domain/service_request_exceptions.dart';
import 'widgets/provider_widgets.dart';

/// Perfil público del prestador postulado (GC-350, RNF-014): especialidades
/// verificadas, trabajos realizados, reputación y reseñas. Solo muestra la
/// zona aproximada del prestador.
class ProviderPublicProfilePage extends StatefulWidget {
  const ProviderPublicProfilePage({
    super.key,
    required this.providerId,
    required this.getProfile,
    this.onSelectProvider,
    this.onBack,
  });

  final String providerId;
  final GetProviderPublicProfile getProfile;

  /// Si se indica, muestra el botón para seleccionar al prestador.
  final VoidCallback? onSelectProvider;
  final VoidCallback? onBack;

  @override
  State<ProviderPublicProfilePage> createState() =>
      _ProviderPublicProfilePageState();
}

class _ProviderPublicProfilePageState extends State<ProviderPublicProfilePage> {
  late Future<ProviderPublicProfile> _future =
      widget.getProfile(widget.providerId);

  void _retry() =>
      setState(() => _future = widget.getProfile(widget.providerId));

  @override
  Widget build(BuildContext context) {
    return MobileFeatureShell(
      title: 'Perfil del prestador',
      onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
      child: FutureBuilder<ProviderPublicProfile>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = snapshot.data;
          if (profile == null) {
            final error = snapshot.error;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      error is ServiceRequestFailure
                          ? error.message
                          : 'No pudimos cargar el perfil.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _retry,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }
          return _ProfileBody(
            profile: profile,
            onSelectProvider: widget.onSelectProvider,
          );
        },
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.profile, this.onSelectProvider});

  final ProviderPublicProfile profile;
  final VoidCallback? onSelectProvider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      key: const ValueKey('provider-profile-body'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProviderAvatar(
                initials: profile.initials,
                photoUrl: profile.photoUrl,
                radius: 34,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.displayName,
                        style: theme.textTheme.titleLarge),
                    Text(
                      profile.isCompany ? 'Empresa' : 'Técnico independiente',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    RatingStars(
                      rating: profile.averageRating,
                      ratingCount: profile.ratingCount,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _VerificationBadge(profile: profile),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 18, color: FixiaColors.secondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Zona aproximada: ${profile.approximateZone}',
                  key: const ValueKey('provider-profile-zone'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Por tu seguridad, la ubicación exacta del prestador no se comparte.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: FixiaColors.textSecondary),
          ),
          if (profile.description != null) ...[
            const SizedBox(height: 18),
            Text('Sobre el prestador', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(profile.description!),
          ],
          if (profile.yearsOfExperience != null) ...[
            const SizedBox(height: 10),
            Text('${profile.yearsOfExperience} años de experiencia'),
          ],
          const SizedBox(height: 18),
          Text('Especialidades verificadas', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (profile.verifiedCategories.isEmpty)
            const Text('Aún no tiene especialidades verificadas.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in profile.verifiedCategories)
                  Chip(
                    avatar: const Icon(Icons.verified_outlined, size: 16),
                    label: Text(category.label),
                  ),
              ],
            ),
          const SizedBox(height: 18),
          Text('Trabajos realizados', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (profile.completedJobs.isEmpty)
            const Text('Todavía no registra trabajos en Fixia.')
          else
            for (final job in profile.completedJobs)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.task_alt_rounded,
                    color: FixiaColors.accent),
                title: Text(job.title),
                subtitle: Text('${job.category.label} · ${job.dateLabel}'),
              ),
          const SizedBox(height: 18),
          Text('Reseñas de otros clientes', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (profile.reviews.isEmpty)
            const Text('Aún no tiene reseñas.')
          else
            for (final review in profile.reviews) _ReviewTile(review: review),
          if (onSelectProvider != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('provider-profile-select'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              onPressed: onSelectProvider,
              icon: const Icon(Icons.how_to_reg_outlined),
              label: const Text('Seleccionar prestador'),
            ),
          ],
        ],
      ),
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  const _VerificationBadge({required this.profile});

  final ProviderPublicProfile profile;

  @override
  Widget build(BuildContext context) {
    final verified = profile.isVerified;
    final color = verified ? FixiaColors.accent : FixiaColors.textSecondary;
    return Container(
      key: const ValueKey('provider-profile-verification'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(FixiaRadii.input),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.verified_rounded : Icons.hourglass_top_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              profile.verificationStatus?.label ?? 'Verificación no disponible',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final ProviderReview review;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DashboardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    review.authorName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(review.dateLabel,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 4),
            RatingStars(rating: review.rating.toDouble(), size: 16),
            const SizedBox(height: 6),
            Text(review.comment),
          ],
        ),
      ),
    );
  }
}
