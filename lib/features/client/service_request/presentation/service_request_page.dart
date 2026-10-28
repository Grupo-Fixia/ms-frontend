import 'package:flutter/material.dart';

import '../../../../core/constants/service_category.dart';
import '../../../../core/domain/service_budget.dart';
import '../../../../core/theme/fixia_theme.dart';
import '../../../home/presentation/widgets/dashboard_components.dart';
import '../domain/service_request_draft.dart';

class ServiceRequestPage extends StatefulWidget {
  const ServiceRequestPage({
    super.key,
    this.onSubmitted,
    this.onBack,
    this.onOpenHome,
    this.onOpenHistory,
    this.onOpenProfile,
    this.publish,
  });

  final ValueChanged<ServiceRequestDraft>? onSubmitted;

  /// Publica la solicitud en el servidor (GC-335). Si es `null`, la
  /// confirmación es solo de demostración. Si falla, lanza una excepción con
  /// el mensaje para el usuario.
  final Future<void> Function(ServiceRequestDraft draft)? publish;
  final VoidCallback? onBack;
  final VoidCallback? onOpenHome;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenProfile;

  @override
  State<ServiceRequestPage> createState() => _ServiceRequestPageState();
}

class _ServiceRequestPageState extends State<ServiceRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();
  ServiceCategory? _category;
  DateTime? _expectedAt;
  final List<int> _photos = [];
  String _city = '';
  String _zone = '';
  bool _submitting = false;

  bool get _publishes => widget.publish != null;

  bool get _hasLocation => _city.isNotEmpty && _zone.isNotEmpty;

  bool get _canSubmit =>
      !_submitting &&
      _category != null &&
      _descriptionController.text.trim().isNotEmpty &&
      ServiceBudget.tryParse(_budgetController.text) != null &&
      _expectedAt != null &&
      (!_publishes || _hasLocation);

  @override
  void dispose() {
    _descriptionController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _pickExpectedMoment() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _expectedAt ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      helpText: 'Selecciona el día esperado',
      cancelText: 'Cancelar',
      confirmText: 'Continuar',
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _expectedAt == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(_expectedAt!),
      helpText: 'Selecciona la hora aproximada',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (!mounted || time == null) return;
    setState(() {
      _expectedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _addPhoto() {
    if (_photos.length >= 3) return;
    setState(() => _photos.add(_photos.length + 1));
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate() ||
        _category == null ||
        _expectedAt == null) {
      return;
    }
    final draft = ServiceRequestDraft(
      category: _category!,
      description: _descriptionController.text.trim(),
      expectedAt: _expectedAt!,
      photoCount: _photos.length,
      city: _city,
      zone: _zone,
      budget: ServiceBudget.tryParse(_budgetController.text),
    );
    final publish = widget.publish;
    if (publish != null) {
      setState(() => _submitting = true);
      try {
        await publish(draft);
      } catch (error) {
        if (!mounted) return;
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: const ValueKey('client-request-error'),
            content: Text('$error'),
          ),
        );
        return;
      }
      if (!mounted) return;
      setState(() => _submitting = false);
    }
    widget.onSubmitted?.call(draft);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('client-request-confirmation'),
        icon: const Icon(
          Icons.check_circle_outline_rounded,
          color: FixiaColors.accent,
          size: 42,
        ),
        title:
            Text(publish != null ? 'Solicitud publicada' : 'Solicitud lista'),
        content: Text(
          publish != null
              ? 'Los técnicos compatibles de tu zona ya pueden verla y postularse.'
              : 'Esta es una confirmación de demostración. No se envió información a ningún servidor.',
        ),
        actions: [
          FilledButton(
            key: const ValueKey('client-request-confirmation-close'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
    // Tras publicar se vuelve al inicio del cliente.
    if (!mounted) return;
    widget.onOpenHome?.call();
  }

  @override
  Widget build(BuildContext context) {
    return MobileFeatureShell(
      title: 'Publicar un problema',
      onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
      maxWidth: 440,
      bottomNavigationItems: _buildNavigationItems(context),
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              'Cuéntanos qué necesitas',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Completa los datos para que profesionales puedan evaluar tu solicitud.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: FixiaColors.textSecondary),
            ),
            const SizedBox(height: 22),
            DropdownButtonFormField<ServiceCategory>(
              key: const ValueKey('client-request-category'),
              // Flutter 3.22 needs `value`; `initialValue` was added later.
              // ignore: deprecated_member_use
              value: _category,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Categoría',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              items: [
                for (final category in ServiceCategory.values)
                  DropdownMenuItem(
                    value: category,
                    child: Text(category.label),
                  ),
              ],
              onChanged: (value) => setState(() => _category = value),
              validator: (value) =>
                  value == null ? 'Selecciona una categoría.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('client-request-description'),
              controller: _descriptionController,
              minLines: 4,
              maxLines: 7,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: const InputDecoration(
                labelText: 'Descripción del problema',
                hintText: 'Describe qué sucede y qué necesitas reparar.',
                alignLabelWithHint: true,
              ),
              onChanged: (_) => setState(() {}),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'La descripción es obligatoria.'
                  : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const ValueKey('client-request-budget'),
              controller: _budgetController,
              enabled: !_submitting,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: const InputDecoration(
                labelText: 'Presupuesto aproximado *',
                prefixText: 'COP ',
                hintText: 'Ej. 150000',
                helperText:
                    'Máximo 10 dígitos enteros y 2 decimales. Sin separadores de miles.',
                helperMaxLines: 2,
                errorMaxLines: 3,
              ),
              onChanged: (_) => setState(() {}),
              validator: ServiceBudget.validate,
            ),
            const SizedBox(height: 8),
            Text(
              'Es orientativo: no es un pago ni un precio acordado. '
              'El técnico podrá proponer un precio diferente.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _LocationPrivacyCard(
              location: !_publishes
                  ? 'Chapinero, Bogotá'
                  : _hasLocation
                      ? '$_zone, $_city'
                      : null,
              onChangeLocation:
                  _publishes ? _pickLocation : () => _showLocationDemo(context),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              key: const ValueKey('client-request-expected-at'),
              onPressed: _pickExpectedMoment,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(
                _expectedAt == null
                    ? 'Elegir momento esperado *'
                    : 'Atención: ${_formatDateTime(_expectedAt!)}',
              ),
            ),
            if (_expectedAt == null)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 6),
                child: Text(
                  'Selecciona una fecha y hora aproximadas.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: FixiaColors.textSecondary),
                ),
              ),
            const SizedBox(height: 22),
            _PhotoPicker(
              photos: _photos,
              onAdd: _addPhoto,
              onRemove: (index) => setState(() => _photos.removeAt(index)),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const ValueKey('client-request-submit'),
              onPressed: _canSubmit ? _submit : null,
              icon: const Icon(Icons.send_rounded),
              label: Text(_submitting ? 'Enviando…' : 'Enviar solicitud'),
            ),
            const SizedBox(height: 8),
            Text(
              'Los campos marcados con * son obligatorios.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
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
          icon: Icons.history_rounded,
          label: 'Historial',
          onPressed: widget.onOpenHistory ?? () => _showHistoryHint(context),
        ),
        MobileNavigationItem(
          icon: Icons.add_rounded,
          label: 'Publicar',
          isAction: true,
          selected: true,
          onPressed: () {},
        ),
        MobileNavigationItem(
          icon: Icons.person_outline_rounded,
          label: 'Perfil',
          onPressed: widget.onOpenProfile ?? () => _showProfileHint(context),
        ),
      ];

  void _showHistoryHint(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('El historial se mostrará en otra vista.')),
    );
  }

  void _showProfileHint(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Abre tu perfil desde la pantalla de Inicio.')),
    );
  }

  String _formatDateTime(DateTime value) {
    final date =
        '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return '$date · $time';
  }

  /// Ciudad y zona (barrio o localidad) que verán los técnicos. La
  /// dirección exacta no se pide aquí: se comparte solo al contratar.
  Future<void> _pickLocation() async {
    final picked = await showDialog<({String city, String zone})>(
      context: context,
      builder: (context) => _LocationDialog(city: _city, zone: _zone),
    );
    if (picked != null && mounted) {
      setState(() {
        _city = picked.city;
        _zone = picked.zone;
      });
    }
  }

  void _showLocationDemo(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'La ubicación precisa se mantiene privada. Solo se comparte una zona aproximada.',
        ),
      ),
    );
  }
}

/// Pide ciudad y barrio. Los campos viven con el diálogo: así no se
/// descartan mientras se anima su cierre.
class _LocationDialog extends StatefulWidget {
  const _LocationDialog({required this.city, required this.zone});

  final String city;
  final String zone;

  @override
  State<_LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends State<_LocationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _city = TextEditingController(text: widget.city);
  late final _zone = TextEditingController(text: widget.zone);

  @override
  void dispose() {
    _city.dispose();
    _zone.dispose();
    super.dispose();
  }

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? 'Escribe $label.' : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('client-request-location-dialog'),
      title: const Text('Ubicación aproximada'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const ValueKey('client-request-city'),
              controller: _city,
              maxLength: 80,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Ciudad'),
              validator: (value) => _required(value, 'la ciudad'),
            ),
            TextFormField(
              key: const ValueKey('client-request-zone'),
              controller: _zone,
              maxLength: 80,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Barrio o localidad',
              ),
              validator: (value) => _required(value, 'el barrio o localidad'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('client-request-location-save'),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(
              (city: _city.text.trim(), zone: _zone.text.trim()),
            );
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _LocationPrivacyCard extends StatelessWidget {
  const _LocationPrivacyCard({
    required this.location,
    required this.onChangeLocation,
  });

  /// `null` si todavía no se eligió.
  final String? location;
  final VoidCallback onChangeLocation;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('client-request-approximate-location'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FixiaColors.supportBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined,
                  color: FixiaColors.secondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location == null
                          ? 'Ubicación aproximada *'
                          : 'Ubicación aproximada',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      location == null
                          ? 'Elige tu ciudad y barrio. Tu dirección exacta se protege.'
                          : '$location · Tu dirección exacta se protege.',
                      key: const ValueKey('client-request-location-label'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const ValueKey('client-request-change-location'),
              onPressed: onChangeLocation,
              icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
              label: Text(
                location == null ? 'Elegir ubicación' : 'Cambiar ubicación',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photos,
    required this.onAdd,
    required this.onRemove,
  });

  final List<int> photos;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fotografías (opcional)',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: FixiaColors.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Agrega hasta 3 imágenes de referencia. La carga es simulada.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var index = 0; index < photos.length; index++)
              _PhotoPlaceholder(
                index: index,
                onRemove: () => onRemove(index),
              ),
            if (photos.length < 3)
              InkWell(
                key: const ValueKey('client-request-add-photo'),
                onTap: onAdd,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: FixiaColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFC9D6E8)),
                  ),
                  child: const Icon(
                    Icons.add_a_photo_outlined,
                    color: FixiaColors.secondary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.index, required this.onRemove});

  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          key: ValueKey('client-request-photo-$index'),
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: const Color(0xFFE7EEF8),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.image_outlined,
            color: FixiaColors.textSecondary,
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: IconButton(
            key: ValueKey('client-request-remove-photo-$index'),
            tooltip: 'Quitar fotografía',
            onPressed: onRemove,
            icon: const Icon(Icons.cancel, size: 20),
            color: FixiaColors.error,
          ),
        ),
      ],
    );
  }
}
