import 'package:flutter/material.dart';

import '../../../../core/constants/service_category.dart';
import '../../../../core/theme/fixia_theme.dart';
import '../../../../core/layout/app_shell.dart';
import '../../../../core/widgets/fixia_ui.dart';
import '../application/get_service_catalog.dart';
import '../application/get_technician_specialties.dart';
import '../application/update_technician_specialties.dart';
import '../domain/technician_specialties.dart';
import '../domain/technician_specialties_exceptions.dart';

/// Especialidades del técnico (GC-324). Usa los casos de uso de GC-325, así
/// que muestra el catálogo y la selección que entrega el repositorio.
class TechnicianSpecialtiesPage extends StatefulWidget {
  const TechnicianSpecialtiesPage({
    super.key,
    required this.getCatalog,
    required this.getSpecialties,
    required this.updateSpecialties,
    this.onSessionExpired,
    this.onCancel,
    this.onOpenHome,
    this.onOpenOpportunities,
    this.onOpenProfile,
    this.onOpenWallet,
  });

  final GetServiceCatalog getCatalog;
  final GetTechnicianSpecialties getSpecialties;
  final UpdateTechnicianSpecialties updateSpecialties;
  final VoidCallback? onSessionExpired;
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
  List<ServiceCategoryOption> _catalog = const [];
  Set<ServiceCategory> _saved = {};
  Set<ServiceCategory> _selection = {};
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final catalog = await widget.getCatalog();
      final specialties = await widget.getSpecialties();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _saved = {...specialties.categories};
        _selection = {...specialties.categories};
        _loading = false;
      });
    } on TechnicianSpecialtiesFailure catch (failure) {
      if (!mounted) return;
      if (failure.isSessionExpired) return _expire();
      setState(() {
        _loading = false;
        _loadError = failure.message;
      });
    }
  }

  void _expire() => widget.onSessionExpired?.call();

  void _toggle(ServiceCategory category, bool selected) {
    setState(() {
      selected ? _selection.add(category) : _selection.remove(category);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await widget.updateSpecialties(_selection);
      if (!mounted) return;
      setState(() {
        _saved = {...result.categories};
        _selection = {...result.categories};
        _saving = false;
      });
      messenger.showSnackBar(
        const SnackBar(
          key: ValueKey('technician-specialties-saved'),
          content: Text('Especialidades guardadas.'),
        ),
      );
    } on TechnicianSpecialtiesFailure catch (failure) {
      if (!mounted) return;
      setState(() => _saving = false);
      if (failure.isSessionExpired) return _expire();
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  void _cancel() {
    setState(() => _selection = {..._saved});
    widget.onCancel?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Se descartaron los cambios sin guardar.')),
    );
  }

  void _navigate(ShellDestination destination) {
    final own = switch (destination) {
      ShellDestination.technicianHome => widget.onOpenHome,
      ShellDestination.technicianOpportunities => widget.onOpenOpportunities,
      ShellDestination.technicianProfile => widget.onOpenProfile,
      _ => null,
    };
    if (own != null) return own();
    final scope = FixiaShellScope.maybeOf(context);
    if (scope?.onNavigate != null) return scope!.onNavigate!(destination);
    _showNavigationHint(context, destination.label);
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      destination: ShellDestination.technicianProfile,
      subpage: true,
      onNavigate: _navigate,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BackLink(onPressed: widget.onCancel),
          const PageHeader(
            title: 'Mis especialidades',
            subtitle:
                'Activa una o más categorías para recibir solicitudes compatibles.',
          ),
          const SizedBox(height: 24),
          if (_loading)
            const SectionLoading()
          else if (_loadError != null)
            _LoadError(message: _loadError!, onRetry: _load)
          else
            _buildContent(context),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final hasChanges =
        !(_selection.length == _saved.length && _selection.containsAll(_saved));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                  '${_selection.length} especialidades activas',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          minItemWidth: 260,
          spacing: 12,
          children: [
            for (final option in _catalog)
              _SpecialtyCard(
                option: option,
                selected: _selection.contains(option.category),
                onChanged: (value) => _toggle(option.category, value),
              ),
          ],
        ),
        const SizedBox(height: 20),
        ActionBar(actions: [
          TextButton(
            key: const ValueKey('technician-specialties-cancel'),
            onPressed: _saving ? null : _cancel,
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('technician-specialties-save'),
            onPressed: _saving || !hasChanges ? null : _save,
            child: Text(_saving ? 'Guardando...' : 'Guardar cambios'),
          ),
        ]),
      ],
    );
  }

  void _showNavigationHint(BuildContext context, String section) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$section está disponible desde la pantalla de Inicio.'),
      ),
    );
  }
}

class _SpecialtyCard extends StatelessWidget {
  const _SpecialtyCard({
    required this.option,
    required this.selected,
    required this.onChanged,
  });

  final ServiceCategoryOption option;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final category = option.category;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: selected ? FixiaColors.supportBackground : FixiaColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? FixiaColors.secondary : const Color(0xFFDCE5F0),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: CheckboxListTile(
        key: ValueKey('technician-specialty-toggle-${category.apiValue}'),
        value: selected,
        onChanged: (value) => onChanged(value ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          option.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 48, color: FixiaColors.textSecondary),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const ValueKey('technician-specialties-retry'),
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
