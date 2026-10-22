import 'package:flutter/material.dart';

import '../../../../core/theme/fixia_theme.dart';
import '../../../home/presentation/widgets/dashboard_components.dart';
import '../application/provider_profile_use_cases.dart';
import '../application/service_request_use_cases.dart';
import '../domain/applicant.dart';
import '../domain/provider_public_profile.dart';
import '../domain/service_request.dart';
import '../domain/service_request_exceptions.dart';
import 'provider_public_profile_page.dart';
import 'widgets/provider_widgets.dart';

/// Texto del estado de la postulación tal como lo ve el cliente (GC-349).
String applicantStatusLabel(ApplicationStatus status) => switch (status) {
      ApplicationStatus.applied => 'Pendiente',
      ApplicationStatus.selected => 'Seleccionado',
      ApplicationStatus.rejected => 'Desestimado',
    };

/// Postulantes de una solicitud del cliente (GC-349, RF-016): lista de
/// prestadores con foto, nombre, reputación y estado, y acceso a su perfil
/// público (GC-350) y a la selección.
class ApplicantsPage extends StatefulWidget {
  const ApplicantsPage({
    super.key,
    required this.requestId,
    required this.listApplicants,
    required this.selectProvider,
    required this.getProfile,
    this.onProviderSelected,
    this.onSessionExpired,
    this.onBack,
  });

  final String requestId;
  final ListApplicants listApplicants;
  final SelectProvider selectProvider;
  final GetProviderPublicProfile getProfile;

  /// Se llama cuando el cliente selecciona al prestador.
  final ValueChanged<ServiceRequest>? onProviderSelected;
  final VoidCallback? onSessionExpired;
  final VoidCallback? onBack;

  @override
  State<ApplicantsPage> createState() => _ApplicantsPageState();
}

class _ApplicantsPageState extends State<ApplicantsPage> {
  List<Applicant> _applicants = const [];
  final Map<String, ProviderPublicProfile> _profiles = {};
  bool _loading = true;
  bool _selecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final applicants = await widget.listApplicants(widget.requestId);
      await Future.wait([
        for (final applicant in applicants) _loadProfile(applicant.providerId),
      ]);
      if (!mounted) return;
      setState(() {
        _applicants = applicants;
        _loading = false;
      });
    } on ServiceRequestFailure catch (failure) {
      if (!mounted) return;
      if (failure.isSessionExpired) widget.onSessionExpired?.call();
      setState(() {
        _error = failure.message;
        _loading = false;
      });
    }
  }

  // Si el perfil falla, la tarjeta se muestra sin nombre ni reputación.
  Future<void> _loadProfile(String providerId) async {
    if (_profiles.containsKey(providerId)) return;
    try {
      _profiles[providerId] = await widget.getProfile(providerId);
    } on ServiceRequestFailure {
      return;
    }
  }

  bool get _hasSelection =>
      _applicants.any((a) => a.status == ApplicationStatus.selected);

  Future<void> _openProfile(Applicant applicant) {
    final canSelect = !_hasSelection && !_selecting;
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => ProviderPublicProfilePage(
          providerId: applicant.providerId,
          getProfile: widget.getProfile,
          onSelectProvider: canSelect
              ? () {
                  Navigator.of(context).pop();
                  _select(applicant);
                }
              : null,
        ),
      ),
    );
  }

  Future<void> _select(Applicant applicant) async {
    final name =
        _profiles[applicant.providerId]?.displayName ?? 'este prestador';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('select-provider-dialog'),
        title: const Text('¿Seleccionar prestador?'),
        content: Text(
          'Elegirás a $name. Las demás postulaciones quedarán desestimadas y '
          'el prestador podrá enviarte su cotización.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('select-provider-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Seleccionar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _selecting = true);
    try {
      final request =
          await widget.selectProvider(widget.requestId, applicant.id);
      if (!mounted) return;
      widget.onProviderSelected?.call(request);
      messenger.showSnackBar(
        SnackBar(content: Text('Seleccionaste a $name. Espera su cotización.')),
      );
      await _load();
    } on ServiceRequestFailure catch (failure) {
      if (!mounted) return;
      if (failure.isSessionExpired) widget.onSessionExpired?.call();
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileFeatureShell(
      title: 'Postulantes',
      onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (_applicants.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aún no hay postulantes. Te avisaremos cuando un prestador se '
            'postule.',
            key: ValueKey('applicants-empty'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      key: const ValueKey('applicants-list'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      itemCount: _applicants.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final applicant = _applicants[index];
        return _ApplicantCard(
          applicant: applicant,
          profile: _profiles[applicant.providerId],
          canSelect: !_hasSelection &&
              !_selecting &&
              applicant.status == ApplicationStatus.applied,
          onOpenProfile: () => _openProfile(applicant),
          onSelect: () => _select(applicant),
        );
      },
    );
  }
}

class _ApplicantCard extends StatelessWidget {
  const _ApplicantCard({
    required this.applicant,
    required this.profile,
    required this.canSelect,
    required this.onOpenProfile,
    required this.onSelect,
  });

  final Applicant applicant;
  final ProviderPublicProfile? profile;
  final bool canSelect;
  final VoidCallback onOpenProfile;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = profile?.displayName ?? 'Prestador';
    return DashboardCard(
      child: Column(
        key: ValueKey('applicant-${applicant.id}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: ValueKey('applicant-profile-${applicant.id}'),
            onTap: onOpenProfile,
            borderRadius: BorderRadius.circular(FixiaRadii.input),
            child: Row(
              children: [
                ProviderAvatar(
                  initials: profile?.initials ?? '?',
                  photoUrl: profile?.photoUrl,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.titleMedium),
                      Text(
                        profile?.isCompany == true
                            ? 'Empresa'
                            : 'Técnico independiente',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      RatingStars(
                        rating: profile?.averageRating,
                        ratingCount: profile?.ratingCount,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatusChip(status: applicant.status),
              TextButton(
                key: ValueKey('applicant-view-profile-${applicant.id}'),
                onPressed: onOpenProfile,
                child: const Text('Ver perfil'),
              ),
            ],
          ),
          if (applicant.status != ApplicationStatus.rejected) ...[
            const SizedBox(height: 4),
            FilledButton(
              key: ValueKey('applicant-select-${applicant.id}'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: canSelect ? onSelect : null,
              child: Text(
                applicant.status == ApplicationStatus.selected
                    ? 'Prestador seleccionado'
                    : 'Seleccionar Prestador',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ApplicationStatus.applied => FixiaColors.secondary,
      ApplicationStatus.selected => FixiaColors.accent,
      ApplicationStatus.rejected => FixiaColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        applicantStatusLabel(status),
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
