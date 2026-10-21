import 'package:flutter/material.dart';

import '../../../../core/constants/service_category.dart';
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
  });

  final ValueChanged<ServiceRequestDraft>? onSubmitted;
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
  ServiceCategory? _category;
  DateTime? _expectedAt;
  final List<int> _photos = [];

  bool get _canSubmit =>
      _category != null &&
      _descriptionController.text.trim().isNotEmpty &&
      _expectedAt != null;

  @override
  void dispose() {
    _descriptionController.dispose();
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
    );
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
        title: const Text('Solicitud lista'),
        content: const Text(
          'Esta es una confirmación de demostración. No se envió información a ningún servidor.',
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
                  _LocationPrivacyCard(
                    onChangeLocation: () => _showLocationDemo(context),
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
                    onRemove: (index) =>
                        setState(() => _photos.removeAt(index)),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const ValueKey('client-request-submit'),
                    onPressed: _canSubmit ? _submit : null,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Enviar solicitud'),
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
          onPressed:
              widget.onOpenHistory ?? () => _showHistoryHint(context),
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
          onPressed:
              widget.onOpenProfile ?? () => _showProfileHint(context),
        ),
      ];

  void _showHistoryHint(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('El historial se mostrará en otra vista.')),
    );
  }

  void _showProfileHint(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Abre tu perfil desde la pantalla de Inicio.')),
    );
  }

  String _formatDateTime(DateTime value) {
    final date =
        '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return '$date · $time';
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

class _LocationPrivacyCard extends StatelessWidget {
  const _LocationPrivacyCard({required this.onChangeLocation});

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
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on_outlined, color: FixiaColors.secondary),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ubicación aproximada',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Chapinero, Bogotá · Tu dirección exacta se protege.',
                      style: TextStyle(fontSize: 12),
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
              label: const Text('Cambiar ubicación'),
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
