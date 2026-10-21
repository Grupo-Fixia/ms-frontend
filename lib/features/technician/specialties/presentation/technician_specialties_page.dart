import 'package:flutter/material.dart';

import '../../../../core/constants/service_category.dart';
import '../../../../core/theme/fixia_theme.dart';
import '../../../home/presentation/widgets/dashboard_components.dart';
import '../domain/specialty_options.dart';

class TechnicianSpecialtiesPage extends StatefulWidget {
  const TechnicianSpecialtiesPage({
    super.key,
    this.onSaved,
    this.onCancel,
    this.onOpenHome,
    this.onOpenOpportunities,
    this.onOpenProfile,
    this.onOpenWallet,
  });

  final ValueChanged<Map<ServiceCategory, Set<String>>>? onSaved;
  final VoidCallback? onCancel;
  final VoidCallback? onOpenHome;
  final VoidCallback? onOpenOpportunities;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenWallet;

  @override
  State<TechnicianSpecialtiesPage> createState() =>
      _TechnicianSpecialtiesPageState();
}

class _TechnicianSpecialtiesPageState extends State<TechnicianSpecialtiesPage> {
  static const _initialSelection = <ServiceCategory, Set<String>>{
    ServiceCategory.plumbing: {
      'Reparación de fugas',
      'Instalación de grifería',
    },
    ServiceCategory.electrical: {'Instalación de luminarias'},
  };

  late Map<ServiceCategory, Set<String>> _savedSelection;
  late Map<ServiceCategory, Set<String>> _selection;

  @override
  void initState() {
    super.initState();
    _savedSelection = _copySelection(_initialSelection);
    _selection = _copySelection(_savedSelection);
  }

  Map<ServiceCategory, Set<String>> _copySelection(
    Map<ServiceCategory, Set<String>> source,
  ) =>
      {
        for (final entry in source.entries) entry.key: {...entry.value},
      };

  void _toggleCategory(ServiceCategory category, bool selected) {
    setState(() {
      if (selected) {
        _selection.putIfAbsent(category, () => <String>{});
      } else {
        _selection.remove(category);
      }
    });
  }

  void _toggleSubservice(ServiceCategory category, String service) {
    setState(() {
      final selected = _selection.putIfAbsent(category, () => <String>{});
      if (!selected.add(service)) selected.remove(service);
      if (selected.isEmpty) _selection.remove(category);
    });
  }

  void _save() {
    _savedSelection = _copySelection(_selection);
    widget.onSaved?.call(_copySelection(_savedSelection));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        key: ValueKey('technician-specialties-saved'),
        content: Text('Especialidades guardadas en esta demostración.'),
      ),
    );
  }

  void _cancel() {
    setState(() => _selection = _copySelection(_savedSelection));
    widget.onCancel?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Se descartaron los cambios sin guardar.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _selection.values.fold<int>(
      0,
      (count, services) => count + services.length,
    );
    return MobileFeatureShell(
      title: 'Mis especialidades',
      onBack: widget.onCancel ?? () => Navigator.of(context).maybePop(),
      bottomNavigationItems: _buildNavigationItems(context),
      child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Text(
                'Elige los trabajos que realizas',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Activa una o más categorías y marca los servicios que ofreces.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: FixiaColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Container(
                key: const ValueKey('technician-specialties-summary'),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: FixiaColors.supportBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_outlined,
                        color: FixiaColors.secondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$activeCount servicios activos',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Text('Demo local'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              for (final category in ServiceCategory.values)
                _SpecialtyCategoryCard(
                  category: category,
                  options: specialtyOptions[category]!,
                  selected: _selection[category] ?? const <String>{},
                  enabled: _selection.containsKey(category),
                  onCategoryChanged: (selected) =>
                      _toggleCategory(category, selected),
                  onSubserviceChanged: (service) =>
                      _toggleSubservice(category, service),
                ),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey('technician-specialties-save'),
                onPressed: _selection.values.every((services) => services.isEmpty)
                    ? null
                    : _save,
                child: const Text('Guardar Cambios'),
              ),
              TextButton(
                key: const ValueKey('technician-specialties-cancel'),
                onPressed: _cancel,
                child: const Text('Cancelar'),
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
          onPressed: widget.onOpenOpportunities ??
              () => _showNavigationHint(context, 'Trabajos'),
        ),
        MobileNavigationItem(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Billetera',
          onPressed: widget.onOpenWallet ??
              () => _showNavigationHint(context, 'Billetera'),
        ),
        MobileNavigationItem(
          icon: Icons.person_outline_rounded,
          label: 'Perfil',
          selected: true,
          onPressed: widget.onOpenProfile ??
              () => _showNavigationHint(context, 'Perfil'),
        ),
      ];

  void _showNavigationHint(BuildContext context, String section) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$section está disponible desde la pantalla de Inicio.'),
      ),
    );
  }
}

class _SpecialtyCategoryCard extends StatelessWidget {
  const _SpecialtyCategoryCard({
    required this.category,
    required this.options,
    required this.selected,
    required this.enabled,
    required this.onCategoryChanged,
    required this.onSubserviceChanged,
  });

  final ServiceCategory category;
  final List<String> options;
  final Set<String> selected;
  final bool enabled;
  final ValueChanged<bool> onCategoryChanged;
  final ValueChanged<String> onSubserviceChanged;

  @override
  Widget build(BuildContext context) {
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: shape,
        collapsedShape: shape,
        clipBehavior: Clip.antiAlias,
        key: ValueKey('technician-specialty-${category.apiValue}'),
        initiallyExpanded: enabled,
        leading: Checkbox(
          key: ValueKey('technician-specialty-toggle-${category.apiValue}'),
          value: enabled,
          onChanged: (value) => onCategoryChanged(value ?? false),
        ),
        title: Text(
          category.label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          enabled ? '${selected.length} servicios activos' : 'Sin activar',
        ),
        children: [
          for (final option in options)
            CheckboxListTile(
              key: ValueKey(
                'technician-subservice-${category.apiValue}-$option',
              ),
              value: selected.contains(option),
              title: Text(option),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: enabled ? (_) => onSubserviceChanged(option) : null,
            ),
        ],
      ),
    );
  }
}
