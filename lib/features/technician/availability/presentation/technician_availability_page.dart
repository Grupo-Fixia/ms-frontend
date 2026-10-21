import 'package:flutter/material.dart';

import '../../../../core/theme/fixia_theme.dart';
import '../../../home/presentation/widgets/dashboard_components.dart';
import '../application/get_technician_service_settings.dart';
import '../application/save_technician_service_settings.dart';
import '../domain/availability_day.dart';
import '../domain/availability_hours.dart';
import '../domain/coverage_zone.dart';
import '../domain/technician_availability.dart';
import '../domain/technician_service_settings.dart';
import 'widgets/availability_schedule_card.dart';
import 'widgets/coverage_radius_slider.dart';
import 'widgets/coverage_zone_preview.dart';

class TechnicianAvailabilityPage extends StatefulWidget {
  const TechnicianAvailabilityPage({
    super.key,
    required this.getSettings,
    required this.saveSettings,
    this.onBack,
    this.onOpenHome,
    this.onOpenOpportunities,
    this.onOpenProfile,
  });

  final GetTechnicianServiceSettings getSettings;
  final SaveTechnicianServiceSettings saveSettings;
  final VoidCallback? onBack;
  final VoidCallback? onOpenHome;
  final VoidCallback? onOpenOpportunities;
  final VoidCallback? onOpenProfile;

  @override
  State<TechnicianAvailabilityPage> createState() =>
      _TechnicianAvailabilityPageState();
}

class _TechnicianAvailabilityPageState
    extends State<TechnicianAvailabilityPage> {
  static const _cities = [
    'Bogotá',
    'Medellín',
    'Cali',
    'Barranquilla',
    'Bucaramanga',
    'Cartagena',
  ];
  static const _defaultHours =
      AvailabilityHours(startMinutes: 480, endMinutes: 1020);

  TechnicianServiceSettings? _savedSettings;
  Map<AvailabilityDay, AvailabilityHours> _days = {};
  String? _city;
  int _radiusKm = 15;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final settings = await widget.getSettings();
      if (!mounted) return;
      setState(() {
        _savedSettings = settings;
        _days = Map.of(settings.availability.days);
        _city = settings.coverageZone.city;
        _radiusKm = settings.coverageZone.radiusKm;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar tus preferencias: $error';
        _isLoading = false;
      });
    }
  }

  bool get _isValid =>
      _days.isNotEmpty &&
      _days.values.every((hours) => hours.isValid) &&
      CoverageZone(city: _city ?? '', radiusKm: _radiusKm).isValid;

  AvailabilityHours? get _referenceHours {
    if (_days.isEmpty) return null;
    final first = AvailabilityDay.values.firstWhere(_days.containsKey);
    return _days[first];
  }

  void _toggleDay(AvailabilityDay day) {
    setState(() {
      if (_days.containsKey(day)) {
        _days.remove(day);
      } else {
        _days[day] = _referenceHours ?? _defaultHours;
      }
    });
  }

  void _selectDays(Set<AvailabilityDay> selection) {
    setState(() {
      final hours = _referenceHours ?? _defaultHours;
      _days = {for (final day in selection) day: hours};
    });
  }

  Future<void> _changeTime({required bool isStart}) async {
    final current = _referenceHours;
    if (current == null) return;
    final currentMinutes = isStart ? current.startMinutes : current.endMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay(hour: currentMinutes ~/ 60, minute: currentMinutes % 60),
      helpText: isStart
          ? 'Selecciona la hora de inicio'
          : 'Selecciona la hora de fin',
    );
    if (picked == null || !mounted) return;
    final minutes = picked.hour * 60 + picked.minute;
    final updated = AvailabilityHours(
      startMinutes: isStart ? minutes : current.startMinutes,
      endMinutes: isStart ? current.endMinutes : minutes,
    );
    setState(() {
      _days = {for (final day in _days.keys) day: updated};
    });
  }

  void _cancelChanges() {
    final saved = _savedSettings;
    if (saved == null) return;
    setState(() {
      _days = Map.of(saved.availability.days);
      _city = saved.coverageZone.city;
      _radiusKm = saved.coverageZone.radiusKm;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cambios descartados.')),
    );
  }

  Future<void> _saveChanges() async {
    if (!_isValid || _isSaving) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    final settings = TechnicianServiceSettings(
      availability: TechnicianAvailability(days: _days),
      coverageZone: CoverageZone(city: _city!, radiusKm: _radiusKm),
    );
    try {
      await widget.saveSettings(settings);
      if (!mounted) return;
      setState(() {
        _savedSettings = settings;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: ValueKey('availability-saved'),
          content:
              Text('Disponibilidad y zona guardadas en esta demostración.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron guardar los cambios: $error';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => MobileFeatureShell(
        title: 'Disponibilidad y zona',
        onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
        bottomNavigationItems: _navigationItems(context),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _savedSettings == null
                ? _loadErrorView()
                : _settingsForm(context),
      );

  Widget _loadErrorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: _loadSettings, child: const Text('Reintentar')),
            ],
          ),
        ),
      );

  Widget _settingsForm(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        children: [
          Text('Define cuándo y dónde trabajas',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Tus preferencias se guardan localmente en esta demostración.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: FixiaColors.textSecondary),
          ),
          const SizedBox(height: 20),
          _sectionTitle(
              context, 'Disponibilidad horaria', Icons.calendar_month_rounded),
          const SizedBox(height: 10),
          AvailabilityScheduleCard(
            selectedDays: _days.keys.toSet(),
            hours: _referenceHours,
            hasMixedHours: _days.values.toSet().length > 1,
            onDayToggled: _toggleDay,
            onPresetSelected: _selectDays,
            onStartPressed: () => _changeTime(isStart: true),
            onEndPressed: () => _changeTime(isStart: false),
          ),
          const SizedBox(height: 26),
          _sectionTitle(
              context, 'Zona de atención', Icons.location_on_outlined),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: const ValueKey('availability-city-dropdown'),
            value: _cities.contains(_city) ? _city : null,
            decoration: const InputDecoration(
              labelText: 'Ciudad o municipio base',
              prefixIcon: Icon(Icons.location_city_rounded),
            ),
            items: [
              for (final city in _cities)
                DropdownMenuItem(value: city, child: Text(city))
            ],
            onChanged: (city) => setState(() => _city = city),
          ),
          const SizedBox(height: 18),
          CoverageRadiusSlider(
              radiusKm: _radiusKm,
              onChanged: (radius) => setState(() => _radiusKm = radius)),
          const SizedBox(height: 8),
          CoverageZonePreview(
              city: _city ?? 'Selecciona una ciudad', radiusKm: _radiusKm),
          const Padding(
            padding: EdgeInsets.only(top: 9),
            child: Text(
                'El mapa es ilustrativo; la cobertura se define por ciudad y radio aproximado.',
                style:
                    TextStyle(color: FixiaColors.textSecondary, fontSize: 12)),
          ),
          if (_days.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Text(
                  'Activa al menos un día para definir tu disponibilidad.',
                  key: ValueKey('availability-days-error'),
                  style: TextStyle(color: FixiaColors.error)),
            ),
          if (_days.values.any((hours) => !hours.isValid))
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Text(
                  'Corrige los horarios: la hora final debe ser posterior a la inicial.',
                  key: ValueKey('availability-hours-error'),
                  style: TextStyle(color: FixiaColors.error)),
            ),
          if (_city == null || _city!.trim().isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Text('Selecciona una ciudad para continuar.',
                  key: ValueKey('availability-city-error'),
                  style: TextStyle(color: FixiaColors.error)),
            ),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!,
                    style: const TextStyle(color: FixiaColors.error))),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey('availability-save'),
            onPressed: _isValid && !_isSaving ? _saveChanges : null,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: Text(_isSaving ? 'Guardando…' : 'Guardar Cambios'),
          ),
          TextButton(
            key: const ValueKey('availability-cancel'),
            onPressed: _isSaving ? null : _cancelChanges,
            child: const Text('Cancelar'),
          ),
        ],
      );

  Widget _sectionTitle(BuildContext context, String title, IconData icon) =>
      Row(
        children: [
          Icon(icon, color: FixiaColors.secondary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: FixiaColors.primary, fontWeight: FontWeight.w800)),
          ),
        ],
      );

  List<MobileNavigationItem> _navigationItems(BuildContext context) => [
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
          onPressed: () => _showNavigationHint(context, 'Billetera'),
        ),
        MobileNavigationItem(
          icon: Icons.person_outline_rounded,
          label: 'Perfil',
          onPressed: widget.onOpenProfile ??
              () => _showNavigationHint(context, 'Perfil'),
        ),
      ];

  void _showNavigationHint(BuildContext context, String section) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('$section está disponible desde la pantalla de Inicio.')),
    );
  }
}
