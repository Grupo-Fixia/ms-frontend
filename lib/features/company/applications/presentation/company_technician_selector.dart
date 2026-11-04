import 'package:flutter/material.dart';

/// Opción de presentación, obtenida del listado autorizado de GC-467.
/// No es un DTO HTTP ni calcula elegibilidad en el dispositivo.
class CompanyTechnicianOption {
  const CompanyTechnicianOption({
    required this.id,
    required this.name,
    required this.eligible,
  });
  final String id;
  final String name;

  /// null: Backend todavía no informó la elegibilidad para esta solicitud.
  final bool? eligible;
}

/// Recibe el mismo estado/listado que GC-467, sin otra API ni datos de ejemplo.
/// La asociación y elegibilidad se vuelven a validar en GC-468 al postular.
class CompanyTechnicianSelector extends StatefulWidget {
  const CompanyTechnicianSelector({
    super.key,
    required this.technicians,
    required this.loading,
    required this.onChanged,
    required this.onRetry,
    this.error,
    this.enabled = true,
  });
  final List<CompanyTechnicianOption> technicians;
  final bool loading;
  final String? error;
  final bool enabled;
  final ValueChanged<String?> onChanged;
  final VoidCallback onRetry;

  @override
  State<CompanyTechnicianSelector> createState() =>
      _CompanyTechnicianSelectorState();
}

class _CompanyTechnicianSelectorState extends State<CompanyTechnicianSelector> {
  String? _selected;

  bool get _invalidList {
    final ids = widget.technicians.map((item) => item.id).toSet();
    return ids.length != widget.technicians.length ||
        ids.any((id) => id.trim().isEmpty);
  }

  List<CompanyTechnicianOption> get _eligible => _invalidList
      ? []
      : widget.technicians.where((item) => item.eligible != false).toList();

  @override
  void didUpdateWidget(covariant CompanyTechnicianSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selected != null &&
        (widget.loading ||
            widget.error != null ||
            !_eligible.any((item) => item.id == _selected))) {
      _selected = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onChanged(null);
      });
    }
  }

  @override
  Widget build(BuildContext context) => FormField<String>(
        validator: (_) => widget.loading ||
                widget.error != null ||
                _invalidList ||
                !_eligible.any((item) => item.id == _selected)
            ? 'Selecciona un técnico asociado.'
            : null,
        builder: (field) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSelector(context),
            if (field.hasError)
              Text(field.errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      );

  Widget _buildSelector(BuildContext context) {
    if (widget.loading) {
      return const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
                key: ValueKey('company-technicians-loading')),
            Text('Consultando técnicos asociados…'),
          ]);
    }
    if (widget.error != null || _invalidList) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.error ?? 'No pudimos verificar el listado de técnicos.'),
        TextButton(
          key: const ValueKey('company-technicians-retry'),
          onPressed: widget.enabled ? widget.onRetry : null,
          child: const Text('Reintentar'),
        ),
      ]);
    }
    if (widget.technicians.isEmpty) {
      return const Text('Tu empresa todavía no tiene técnicos asociados.');
    }
    if (_eligible.isEmpty) {
      return Text(widget.technicians.any((item) => item.eligible == null)
          ? 'No se ha confirmado qué técnicos pueden postularse a esta solicitud.'
          : 'No hay técnicos asociados elegibles para esta solicitud.');
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      DropdownButtonFormField<String>(
        key: const ValueKey('company-technician-selector'),
        value: _selected,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Técnico ejecutor *'),
        items: [
          for (final technician in _eligible)
            DropdownMenuItem(
              value: technician.id,
              child: Text(technician.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: widget.enabled
            ? (value) {
                setState(() => _selected = value);
                widget.onChanged(value);
              }
            : null,
      ),
      const SizedBox(height: 8),
      const Text(
          'Fixia verificará la asociación, cobertura, disponibilidad y elegibilidad al enviar.'),
      const Text(
          'El técnico se propone con esta postulación. No podrá reasignarse después.'),
    ]);
  }
}
