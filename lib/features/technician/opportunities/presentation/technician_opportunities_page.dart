import 'package:flutter/material.dart';

import '../../../../core/constants/service_category.dart';
import '../../../../core/theme/fixia_theme.dart';
import '../../../../core/layout/app_shell.dart';
import '../../../../core/widgets/fixia_ui.dart';
import '../domain/service_opportunity.dart';
import '../infrastructure/mock_service_opportunities.dart';
import '../../applications/domain/proposed_price.dart';
import '../../applications/presentation/application_price_form.dart';

class TechnicianOpportunitiesPage extends StatefulWidget {
  const TechnicianOpportunitiesPage({
    super.key,
    this.onApply,
    this.onBack,
    this.onOpenHome,
    this.onOpenSpecialties,
    this.onOpenProfile,
    this.onOpenWallet,
    this.loadOpportunities,
    this.applyTo,
    this.onOpenMyApplications,
  });

  final ValueChanged<String>? onApply;
  final VoidCallback? onOpenMyApplications;
  final VoidCallback? onBack;
  final VoidCallback? onOpenHome;
  final VoidCallback? onOpenSpecialties;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenWallet;

  /// Consulta las solicitudes compatibles en el servidor (GC-340). Si es
  /// `null`, se muestran solicitudes de ejemplo.
  final Future<List<ServiceOpportunity>> Function()? loadOpportunities;

  /// Envía la postulación al servidor (GC-345). Si es `null`, la postulación
  /// es solo de demostración. Si falla, lanza una excepción con el mensaje
  /// para el usuario.
  final Future<ProposedPrice> Function(
      String opportunityId, ProposedPrice price)? applyTo;

  @override
  State<TechnicianOpportunitiesPage> createState() =>
      _TechnicianOpportunitiesPageState();
}

class _TechnicianOpportunitiesPageState
    extends State<TechnicianOpportunitiesPage> {
  ServiceCategory? _selectedCategory;
  final Set<String> _appliedIds = {};
  List<ServiceOpportunity>? _loaded;
  Object? _loadError;

  bool get _live => widget.loadOpportunities != null;

  bool get _loading => _live && _loaded == null && _loadError == null;

  @override
  void initState() {
    super.initState();
    if (_live) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loaded = null;
      _loadError = null;
    });
    try {
      final items = await widget.loadOpportunities!();
      if (mounted) setState(() => _loaded = items);
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  List<ServiceOpportunity> get _visibleOpportunities => (_live
          ? _loaded ?? const <ServiceOpportunity>[]
          : mockServiceOpportunities)
      .where(
        (opportunity) =>
            _selectedCategory == null ||
            opportunity.category == _selectedCategory,
      )
      .toList();

  void _navigate(ShellDestination destination) {
    final own = switch (destination) {
      ShellDestination.technicianHome => widget.onOpenHome,
      ShellDestination.technicianProfile => widget.onOpenProfile,
      _ => null,
    };
    if (own != null) return own();
    final scope = FixiaShellScope.maybeOf(context);
    if (scope?.onNavigate != null) return scope!.onNavigate!(destination);
    if (destination == ShellDestination.technicianProfile) {
      _showProfileHint(context);
    } else if (destination == ShellDestination.technicianHome) {
      (widget.onBack ?? () => Navigator.of(context).maybePop())();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleOpportunities;
    Widget body;
    if (_loading) {
      body = const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: CircularProgressIndicator(
            key: ValueKey('technician-opportunities-loading'),
          ),
        ),
      );
    } else if (_loadError != null) {
      body = FixiaPanel(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Text(
              '$_loadError',
              key: const ValueKey('technician-opportunities-error'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const ValueKey('technician-opportunities-retry'),
              onPressed: _load,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    } else if (visible.isEmpty) {
      body = EmptyState(
        icon: Icons.search_off_rounded,
        message: _live && _selectedCategory == null
            ? 'Por ahora no hay solicitudes compatibles contigo.'
            : 'No hay solicitudes en esta categoría.',
      );
    } else {
      body = ResponsiveGrid(
        minItemWidth: 320,
        children: [
          for (final opportunity in visible)
            _OpportunityCard(
              opportunity: opportunity,
              applied: _appliedIds.contains(opportunity.id),
              onOpen: () => _showDetails(opportunity),
            ),
        ],
      );
    }
    return AppShell(
      destination: ShellDestination.technicianOpportunities,
      onNavigate: _navigate,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Oportunidades para ti',
            subtitle: _live
                ? 'Solicitudes compatibles con tus especialidades, zona y disponibilidad.'
                : 'Solicitudes de ejemplo para explorar y postularte localmente.',
            actions: [
              if (widget.onOpenMyApplications != null)
                OutlinedButton.icon(
                  key: const ValueKey('open-my-applications'),
                  onPressed: widget.onOpenMyApplications,
                  icon: const Icon(Icons.list_alt, size: 18),
                  label: const Text('Mis postulaciones'),
                ),
              OutlinedButton.icon(
                key: const ValueKey('technician-opportunities-specialties'),
                onPressed: widget.onOpenSpecialties ??
                    () => _showSpecialtiesHint(context),
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Mis especialidades'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            key: const ValueKey('technician-opportunities-filters'),
            spacing: 0,
            runSpacing: 8,
            children: [
              _CategoryFilterChip(
                label: 'Todas',
                selected: _selectedCategory == null,
                onSelected: () => setState(() => _selectedCategory = null),
              ),
              for (final category in ServiceCategory.values)
                _CategoryFilterChip(
                  label: category.label,
                  selected: _selectedCategory == category,
                  onSelected: () =>
                      setState(() => _selectedCategory = category),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${visible.length} solicitudes',
            key: const ValueKey('technician-opportunities-count'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          body,
        ],
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
    Widget sheet(BuildContext context, {required bool dialog}) =>
        _OpportunityDetailsSheet(
          opportunity: opportunity,
          applied: _appliedIds.contains(opportunity.id),
          live: widget.applyTo != null,
          dialog: dialog,
          submitPrice: (price) async =>
              (await _apply(opportunity, price: price))!,
          onApply: () {
            Navigator.of(context).pop();
            _apply(opportunity);
          },
        );
    // En computador el detalle se abre como ventana centrada; en celular,
    // como hoja inferior.
    if (MediaQuery.sizeOf(context).width >= ShellBreakpoints.tablet) {
      await showDialog<void>(
        context: context,
        barrierDismissible: widget.applyTo == null,
        builder: (context) => Dialog(
          backgroundColor: FixiaColors.white,
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: sheet(context, dialog: true),
          ),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: widget.applyTo == null,
      enableDrag: widget.applyTo == null,
      backgroundColor: FixiaColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => sheet(context, dialog: false),
    );
  }

  Future<ProposedPrice?> _apply(ServiceOpportunity opportunity,
      {ProposedPrice? price}) async {
    final applyTo = widget.applyTo;
    final messenger = ScaffoldMessenger.of(context);
    ProposedPrice? confirmedPrice;
    if (applyTo != null) {
      try {
        if (price == null) {
          throw const ApplicationPriceFormFailure(
              'Ingresa el precio que propones en COP.');
        }
        confirmedPrice = await applyTo(opportunity.id, price);
      } catch (error) {
        if (!mounted) return confirmedPrice;
        throw ApplicationPriceFormFailure('$error');
      }
      if (!mounted) return confirmedPrice;
    }
    setState(() => _appliedIds.add(opportunity.id));
    widget.onApply?.call(opportunity.id);
    messenger.showSnackBar(
      SnackBar(
        key: const ValueKey('technician-apply-done'),
        content: Text(
          applyTo != null
              ? 'Postulación enviada. El cliente la verá entre sus postulantes.'
              : 'Postulación enviada en esta demostración.',
        ),
      ),
    );
    return confirmedPrice;
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
    required this.onOpen,
  });

  final ServiceOpportunity opportunity;
  final bool applied;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return FixiaPanel(
      key: ValueKey('technician-opportunity-${opportunity.id}'),
      padding: const EdgeInsets.all(18),
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
                child: Text(applied ? 'Postulada' : 'Ver detalle'),
              ),
            ],
          ),
        ],
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
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
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
    required this.onApply,
    required this.submitPrice,
    this.live = false,
    this.dialog = false,
  });

  /// Se muestra como ventana centrada (computador) en vez de hoja inferior.
  final bool dialog;

  final ServiceOpportunity opportunity;
  final bool applied;
  final VoidCallback onApply;
  final Future<ProposedPrice> Function(ProposedPrice) submitPrice;

  /// La postulación se envía al servidor.
  final bool live;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          dialog ? 28 : 20,
          dialog ? 20 : 12,
          dialog ? 28 : 20,
          (dialog ? 28 : 20) + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            key: ValueKey('opportunity-details-${opportunity.id}'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!dialog) ...[
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
              ],
              if (live || dialog)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Cerrar detalle',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close),
                  ),
                ),
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
              if (live && !applied)
                ApplicationPriceForm(
                  serviceRequestId: opportunity.id,
                  currencyLabel: ProposedPrice.currency,
                  validatePrice: ProposedPrice.validate,
                  submit: (input) =>
                      submitPrice(ProposedPrice.tryParse(input)!),
                )
              else
                FilledButton.icon(
                  key: ValueKey('technician-apply-${opportunity.id}'),
                  onPressed: applied ? null : onApply,
                  icon: Icon(
                    applied ? Icons.check_circle_outline : Icons.send_outlined,
                  ),
                  label: Text(applied ? 'Postulación enviada' : 'Postularse'),
                ),
              if (!live) ...[
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
