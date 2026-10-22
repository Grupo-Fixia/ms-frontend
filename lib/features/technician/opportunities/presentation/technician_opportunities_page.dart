import 'package:flutter/material.dart';

import '../../../../core/constants/service_category.dart';
import '../../../../core/theme/fixia_theme.dart';
import '../../../home/presentation/widgets/dashboard_components.dart';
import '../../applications/application/application_use_cases.dart';
import '../../applications/domain/application_exceptions.dart';
import '../../applications/presentation/application_dialogs.dart';
import '../application/list_compatible_opportunities.dart';
import '../domain/opportunity_exceptions.dart';
import '../domain/service_opportunity.dart';
import '../infrastructure/mock_service_opportunities.dart';

/// Estado del técnico respecto a las solicitudes: en cuáles se postuló y en
/// cuáles el cliente ya lo seleccionó (puede enviar cotización).
class OpportunityFlowState {
  const OpportunityFlowState({
    this.applied = const {},
    this.selected = const {},
  });

  final Set<String> applied;
  final Set<String> selected;
}

class TechnicianOpportunitiesPage extends StatefulWidget {
  const TechnicianOpportunitiesPage({
    super.key,
    this.listOpportunities,
    this.applyToServiceRequest,
    this.onSessionExpired,
    this.demoApplyToServiceRequest,
    this.loadFlowState,
    this.onSendQuotation,
    this.onApply,
    this.onBack,
    this.onOpenHome,
    this.onOpenSpecialties,
    this.onOpenProfile,
    this.onOpenWallet,
  });

  /// Solicitudes compatibles reales (ms-services). Si es `null` se muestran
  /// las de ejemplo.
  final ListCompatibleOpportunities? listOpportunities;

  /// Postulación real contra ms-services. Si es `null` la postulación es
  /// solo local (demostración sin red).
  final ApplyToServiceRequest? applyToServiceRequest;
  final VoidCallback? onSessionExpired;

  /// Postulación simulada que se usa cuando el backend no devuelve solicitudes
  /// y se muestran las de ejemplo.
  final ApplyToServiceRequest? demoApplyToServiceRequest;

  /// Consulta en qué solicitudes ya se postuló o fue seleccionado el técnico.
  final Future<OpportunityFlowState> Function()? loadFlowState;

  /// Abre el formulario de cotización de la solicitud en la que fue seleccionado.
  final ValueChanged<String>? onSendQuotation;
  final ValueChanged<String>? onApply;
  final VoidCallback? onBack;
  final VoidCallback? onOpenHome;
  final VoidCallback? onOpenSpecialties;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenWallet;

  @override
  State<TechnicianOpportunitiesPage> createState() =>
      _TechnicianOpportunitiesPageState();
}

class _TechnicianOpportunitiesPageState
    extends State<TechnicianOpportunitiesPage> {
  ServiceCategory? _selectedCategory;
  final Set<String> _appliedIds = {};
  final Set<String> _selectedIds = {};

  List<ServiceOpportunity>? _remote;
  bool _loading = false;
  String? _loadError;

  /// Sin solicitudes reales publicadas se muestran las de ejemplo y la
  /// postulación es local, para poder probar el flujo mientras no haya datos.
  bool _demoFallback = false;

  bool get _localApply => _demoFallback || widget.applyToServiceRequest == null;

  ApplyToServiceRequest? get _apply => _localApply
      ? widget.demoApplyToServiceRequest
      : widget.applyToServiceRequest;

  @override
  void initState() {
    super.initState();
    if (widget.listOpportunities != null) _load();
    _refreshFlowState();
  }

  Future<void> _refreshFlowState() async {
    final load = widget.loadFlowState;
    if (load == null) return;
    final state = await load();
    if (!mounted) return;
    setState(() {
      _appliedIds.addAll(state.applied);
      _selectedIds
        ..clear()
        ..addAll(state.selected);
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final page = await widget.listOpportunities!();
      if (!mounted) return;
      setState(() {
        _remote = page.items.map(ServiceOpportunity.fromOpportunity).toList();
        _demoFallback = _remote!.isEmpty;
        _loading = false;
      });
    } on OpportunityFailure catch (failure) {
      if (!mounted) return;
      if (failure.isSessionExpired) widget.onSessionExpired?.call();
      setState(() {
        _loadError = failure.message;
        _loading = false;
      });
    }
  }

  List<ServiceOpportunity> get _visibleOpportunities => (_demoFallback
          ? mockServiceOpportunities
          : _remote ??
              (widget.listOpportunities == null
                  ? mockServiceOpportunities
                  : const <ServiceOpportunity>[]))
      .where(
        (opportunity) =>
            _selectedCategory == null ||
            opportunity.category == _selectedCategory,
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    return MobileFeatureShell(
      title: 'Oportunidades',
      onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
      bottomNavigationItems: _buildNavigationItems(context),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Oportunidades para ti',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Solicitudes de ejemplo para explorar y postularte localmente.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: FixiaColors.textSecondary),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: const ValueKey(
                        'technician-opportunities-specialties',
                      ),
                      onPressed: widget.onOpenSpecialties ??
                          () => _showSpecialtiesHint(context),
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text('Mis especialidades'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 42,
                    child: ScrollConfiguration(
                      behavior: const DragScrollBehavior(),
                      child: ListView(
                        key: const ValueKey(
                          'technician-opportunities-filters',
                        ),
                        scrollDirection: Axis.horizontal,
                        children: [
                          _CategoryFilterChip(
                            label: 'Todas',
                            selected: _selectedCategory == null,
                            onSelected: () =>
                                setState(() => _selectedCategory = null),
                          ),
                          for (final category in ServiceCategory.values)
                            _CategoryFilterChip(
                              label: category.label,
                              selected: _selectedCategory == category,
                              onSelected: () => setState(
                                () => _selectedCategory = category,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_visibleOpportunities.length} solicitudes',
                    key: const ValueKey('technician-opportunities-count'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_loadError != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_loadError!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _load,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          else if (_visibleOpportunities.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child:
                  Center(child: Text('No hay solicitudes en esta categoría.')),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final opportunity = _visibleOpportunities[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _OpportunityCard(
                        opportunity: opportunity,
                        applied: _appliedIds.contains(opportunity.id),
                        selected: _selectedIds.contains(opportunity.id),
                        onOpen: () => _showDetails(opportunity),
                      ),
                    );
                  },
                  childCount: _visibleOpportunities.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<MobileNavigationItem> _buildNavigationItems(BuildContext context) => [
        MobileNavigationItem(
          icon: Icons.home_rounded,
          label: 'Inicio',
          onPressed:
              widget.onOpenHome ?? () => Navigator.of(context).maybePop(),
        ),
        MobileNavigationItem(
          icon: Icons.work_outline_rounded,
          label: 'Trabajos',
          selected: true,
          onPressed: () {},
        ),
        MobileNavigationItem(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Billetera',
          onPressed: widget.onOpenWallet ?? () => _showWalletHint(context),
        ),
        MobileNavigationItem(
          icon: Icons.person_outline_rounded,
          label: 'Perfil',
          onPressed: widget.onOpenProfile ?? () => _showProfileHint(context),
        ),
      ];

  void _showWalletHint(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('El resumen de billetera está disponible en Inicio.'),
      ),
    );
  }

  void _showProfileHint(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Abre tu perfil desde la pantalla de Inicio.'),
      ),
    );
  }

  void _showSpecialtiesHint(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Puedes editar tus especialidades desde Inicio.'),
      ),
    );
  }

  Future<void> _showDetails(ServiceOpportunity opportunity) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 440),
      backgroundColor: FixiaColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _OpportunityDetailsSheet(
        opportunity: opportunity,
        applied: _appliedIds.contains(opportunity.id),
        selected: _selectedIds.contains(opportunity.id) &&
            widget.onSendQuotation != null,
        demo: _localApply,
        onSendQuotation: () {
          Navigator.of(context).pop();
          widget.onSendQuotation?.call(opportunity.id);
        },
        onApply: () async {
          final confirmation = await showApplyConfirmationDialog(
            context,
            requestTitle: opportunity.title,
          );
          if (confirmation == null || !context.mounted) return;
          Navigator.of(context).pop();
          await _submitApplication(opportunity);
        },
      ),
    );
  }

  Future<void> _submitApplication(ServiceOpportunity opportunity) async {
    final messenger = ScaffoldMessenger.of(context);
    final apply = _apply;
    if (apply == null) {
      setState(() => _appliedIds.add(opportunity.id));
      widget.onApply?.call(opportunity.id);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Postulación enviada en esta demostración.'),
        ),
      );
      return;
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Enviando tu postulación…')),
    );
    try {
      await apply(opportunity.id);
      if (!mounted) return;
      setState(() => _appliedIds.add(opportunity.id));
      widget.onApply?.call(opportunity.id);
      _refreshFlowState();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content:
                Text('Postulación enviada. El cliente revisará tu perfil.'),
          ),
        );
    } on ApplicationFailure catch (failure) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      if (failure.isSessionExpired) {
        widget.onSessionExpired?.call();
      } else if (failure.isDuplicate) {
        setState(() => _appliedIds.add(opportunity.id));
        messenger.showSnackBar(SnackBar(content: Text(failure.message)));
      } else if (failure.isNotEligible) {
        await showApplicationFailureDialog(context, failure);
      } else {
        messenger.showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }
}

class _CategoryFilterChip extends StatelessWidget {
  const _CategoryFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onSelected(),
          selectedColor: FixiaColors.supportBackground,
          labelStyle: TextStyle(
            color: selected ? FixiaColors.primary : FixiaColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
          side: BorderSide(
            color: selected ? FixiaColors.secondary : const Color(0xFFDCE5F0),
          ),
        ),
      );
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({
    required this.opportunity,
    required this.applied,
    required this.selected,
    required this.onOpen,
  });

  final ServiceOpportunity opportunity;
  final bool applied;
  final bool selected;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('technician-opportunity-${opportunity.id}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.handyman_outlined,
                  color: FixiaColors.secondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    opportunity.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _MetaLabel(
                  icon: Icons.category_outlined,
                  label: opportunity.category.label,
                ),
                _MetaLabel(
                  icon: Icons.schedule_outlined,
                  label: opportunity.postedLabel,
                ),
              ],
            ),
            const SizedBox(height: 10),
            _MetaLabel(
              icon: Icons.location_on_outlined,
              label: opportunity.approximateLocation,
            ),
            const SizedBox(height: 4),
            Text(
              'Ubicación aproximada',
              key: ValueKey('approximate-location-${opportunity.id}'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: FixiaColors.textSecondary,
                    fontSize: 11,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Presupuesto orientativo',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        opportunity.budget,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: FixiaColors.secondary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  key: ValueKey(
                    'technician-opportunity-detail-${opportunity.id}',
                  ),
                  onPressed: onOpen,
                  child: Text(
                    selected
                        ? 'Cotizar'
                        : applied
                            ? 'Postulada'
                            : 'Ver detalle',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaLabel extends StatelessWidget {
  const _MetaLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: FixiaColors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}

class _DetailLocationLabel extends StatelessWidget {
  const _DetailLocationLabel({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 16,
            color: FixiaColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '$location · Ubicación aproximada',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      );
}

class _OpportunityDetailsSheet extends StatelessWidget {
  const _OpportunityDetailsSheet({
    required this.opportunity,
    required this.applied,
    required this.selected,
    required this.demo,
    required this.onApply,
    required this.onSendQuotation,
  });

  final ServiceOpportunity opportunity;
  final bool applied;
  final bool selected;
  final bool demo;
  final VoidCallback onApply;
  final VoidCallback onSendQuotation;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            key: ValueKey('opportunity-details-${opportunity.id}'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCE5F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                opportunity.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 14),
              _MetaLabel(
                icon: Icons.category_outlined,
                label: opportunity.category.label,
              ),
              const SizedBox(height: 10),
              _DetailLocationLabel(
                location: opportunity.approximateLocation,
              ),
              const SizedBox(height: 10),
              _MetaLabel(
                icon: Icons.calendar_today_outlined,
                label: 'Publicado ${opportunity.postedLabel}',
              ),
              const SizedBox(height: 18),
              Text(
                'Descripción',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 5),
              Text(opportunity.description),
              const SizedBox(height: 16),
              Text(
                'Momento esperado',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 5),
              Text(opportunity.expectedMoment),
              const SizedBox(height: 16),
              Text(
                'Presupuesto orientativo',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                opportunity.budget,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: FixiaColors.secondary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 22),
              if (selected) ...[
                Text(
                  'El cliente te seleccionó para esta solicitud. Envía tu '
                  'cotización para continuar.',
                  key: ValueKey('technician-selected-${opportunity.id}'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  key: ValueKey('technician-quote-${opportunity.id}'),
                  onPressed: onSendQuotation,
                  icon: const Icon(Icons.request_quote_outlined),
                  label: const Text('Enviar cotización'),
                ),
              ] else
                FilledButton.icon(
                  key: ValueKey('technician-apply-${opportunity.id}'),
                  onPressed: applied ? null : onApply,
                  icon: Icon(
                    applied ? Icons.check_circle_outline : Icons.send_outlined,
                  ),
                  label: Text(applied ? 'Postulación enviada' : 'Postularse'),
                ),
              if (demo) ...[
                const SizedBox(height: 5),
                Text(
                  'Demostración local: la postulación no se envía a un servidor.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
