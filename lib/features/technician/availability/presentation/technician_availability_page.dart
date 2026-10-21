import 'package:flutter/material.dart';

import '../../../../core/theme/fixia_theme.dart';
import '../../../home/presentation/widgets/dashboard_components.dart';
import '../application/availability_use_cases.dart';
import '../domain/clock_time.dart';
import '../domain/coverage_zone.dart';
import '../domain/technician_availability_exceptions.dart';
import '../domain/weekday.dart';
import '../domain/weekly_availability.dart';
import 'widgets/availability_schedule_card.dart';
import 'widgets/coverage_radius_slider.dart';
import 'widgets/coverage_zone_preview.dart';

/// Disponibilidad horaria y zona de atención (GC-329). Usa los casos de uso
/// de GC-330: una misma franja se replica en cada día elegido.
class TechnicianAvailabilityPage extends StatefulWidget {
  const TechnicianAvailabilityPage({
    super.key,
    required this.getAvailability,
    required this.replaceAvailability,
    required this.getCoverageZone,
    required this.updateCoverageZone,
    this.onSessionExpired,
    this.onBack,
    this.onOpenHome,
    this.onOpenOpportunities,
    this.onOpenProfile,
    this.onOpenWallet,
  });

  final GetWeeklyAvailability getAvailability;
  final ReplaceWeeklyAvailability replaceAvailability;
  final GetCoverageZone getCoverageZone;
  final UpdateCoverageZone updateCoverageZone;
  final VoidCallback? onSessionExpired;
  final VoidCallback? onBack;
  final VoidCallback? onOpenHome;
  final VoidCallback? onOpenOpportunities;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenWallet;

  @override
  State<TechnicianAvailabilityPage> createState() =>
      _TechnicianAvailabilityPageState();
}

class _CityCenter {
  const _CityCenter(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

class _TechnicianAvailabilityPageState
    extends State<TechnicianAvailabilityPage> {
  // Centro aproximado de cada ciudad: el radio se declara sobre este punto.
  static const _cities = {
    'Bogotá': _CityCenter(4.7110, -74.0721),
    'Medellín': _CityCenter(6.2442, -75.5812),
    'Cali': _CityCenter(3.4516, -76.5320),
    'Barranquilla': _CityCenter(10.9685, -74.7813),
    'Bucaramanga': _CityCenter(7.1193, -73.1227),
    'Cartagena': _CityCenter(10.3910, -75.4794),
  };
  static const _defaultHours = ScheduleHours(
    start: ClockTime(8, 0),
    end: ClockTime(17, 0),
  );
  static const _defaultRadiusKm = 15;

  Map<Weekday, ScheduleHours> _savedDays = {};
  String? _savedCity;
  int _savedRadiusKm = _defaultRadiusKm;
  Map<Weekday, ScheduleHours> _days = {};
  String? _city;
  int _radiusKm = _defaultRadiusKm;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final availability = await widget.getAvailability();
      final zone = await widget.getCoverageZone();
      if (!mounted) return;
      final days = {
        for (final slot in availability.slots)
          slot.day: ScheduleHours(start: slot.start, end: slot.end),
      };
      setState(() {
        _savedDays = Map.of(days);
        _days = Map.of(days);
        _savedCity = zone?.city;
        _savedRadiusKm = zone?.radiusKm ?? _defaultRadiusKm;
        _city = _savedCity;
        _radiusKm = _savedRadiusKm;
        _isLoading = false;
      });
    } on TechnicianAvailabilityFailure catch (failure) {
      if (!mounted) return;
      if (failure.isSessionExpired) return _expire();
      setState(() {
        _loadError = failure.message;
        _isLoading = false;
      });
    }
  }

  void _expire() => widget.onSessionExpired?.call();

  ScheduleHours? get _referenceHours {
    if (_days.isEmpty) return null;
    return _days[Weekday.values.firstWhere(_days.containsKey)];
  }

  bool get _isValid =>
      _days.isNotEmpty &&
      (_referenceHours?.isValid ?? false) &&
      _city != null &&
      _cities.containsKey(_city);

  void _toggleDay(Weekday day) {
    setState(() {
      if (_days.containsKey(day)) {
        _days.remove(day);
      } else {
        _days[day] = _referenceHours ?? _defaultHours;
      }
    });
  }

  void _selectDays(Set<Weekday> selection) {
    setState(() {
      final hours = _referenceHours ?? _defaultHours;
      _days = {for (final day in selection) day: hours};
    });
  }

  Future<void> _changeTime({required bool isStart}) async {
    final current = _referenceHours;
    if (current == null) return;
    final initial = isStart ? current.start : current.end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
      helpText: isStart
          ? 'Selecciona la hora de inicio'
          : 'Selecciona la hora de fin',
    );
    if (picked == null || !mounted) return;
    final time = ClockTime(picked.hour, picked.minute);
    final updated = ScheduleHours(
      start: isStart ? time : current.start,
      end: isStart ? current.end : time,
    );
    setState(() {
      _days = {for (final day in _days.keys) day: updated};
    });
  }

  void _cancelChanges() {
    setState(() {
      _days = Map.of(_savedDays);
      _city = _savedCity;
      _radiusKm = _savedRadiusKm;
      _saveError = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cambios descartados.')),
    );
  }

  Future<void> _saveChanges() async {
    if (!_isValid || _isSaving) return;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    final slots = [
      for (final day in Weekday.values)
        if (_days.containsKey(day))
          AvailabilitySlot(
            day: day,
            start: _days[day]!.start,
            end: _days[day]!.end,
          ),
    ];
    final center = _cities[_city]!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.replaceAvailability(slots);
      final zone = await widget.updateCoverageZone(CoverageZoneUpdate(
        city: _city!,
        latitude: center.latitude,
        longitude: center.longitude,
        radiusKm: _radiusKm,
      ));
      if (!mounted) return;
      setState(() {
        _savedDays = Map.of(_days);
        _savedCity = zone.city;
        _savedRadiusKm = zone.radiusKm ?? _radiusKm;
        _isSaving = false;
      });
      messenger.showSnackBar(
        const SnackBar(
          key: ValueKey('availability-saved'),
          content: Text('Disponibilidad y zona guardadas.'),
        ),
      );
    } on TechnicianAvailabilityFailure catch (failure) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (failure.isSessionExpired) return _expire();
      setState(() => _saveError = failure.fieldErrors.values.isNotEmpty
          ? failure.fieldErrors.values.first
          : failure.message);
    }
  }

  @override
  Widget build(BuildContext context) => MobileFeatureShell(
        title: 'Disponibilidad y zona',
        onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
        bottomNavigationItems: _navigationItems(context),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? _loadErrorView()
                : _settingsForm(context),
      );

  Widget _loadErrorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('availability-retry'),
                onPressed: _load,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );

  Widget _settingsForm(BuildContext context) {
    final cityItems = {
      ..._cities.keys,
      if (_city != null) _city!,
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
      children: [
        Text('Define cuándo y dónde trabajas',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'Los horarios son de Colombia y la zona es aproximada.',
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
        _sectionTitle(context, 'Zona de atención', Icons.location_on_outlined),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: const ValueKey('availability-city-dropdown'),
          value: _city,
          decoration: const InputDecoration(
            labelText: 'Ciudad o municipio base',
            prefixIcon: Icon(Icons.location_city_rounded),
          ),
          items: [
            for (final city in cityItems)
              DropdownMenuItem(value: city, child: Text(city))
          ],
          onChanged: (city) => setState(() => _city = city),
        ),
        const SizedBox(height: 18),
        CoverageRadiusSlider(
          radiusKm: _radiusKm,
          onChanged: (radius) => setState(() => _radiusKm = radius),
        ),
        const SizedBox(height: 8),
        CoverageZonePreview(
            city: _city ?? 'Selecciona una ciudad', radiusKm: _radiusKm),
        const Padding(
          padding: EdgeInsets.only(top: 9),
          child: Text(
              'Ubicación aproximada: la cobertura se define por ciudad y radio.',
              style: TextStyle(color: FixiaColors.textSecondary, fontSize: 12)),
        ),
        if (_days.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: Text(
                'Activa al menos un día para definir tu disponibilidad.',
                key: ValueKey('availability-days-error'),
                style: TextStyle(color: FixiaColors.error)),
          ),
        if (_referenceHours != null && !_referenceHours!.isValid)
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: Text(
                'Corrige los horarios: la hora final debe ser posterior a la inicial.',
                key: ValueKey('availability-hours-error'),
                style: TextStyle(color: FixiaColors.error)),
          ),
        if (_city == null)
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: Text('Selecciona una ciudad para continuar.',
                key: ValueKey('availability-city-error'),
                style: TextStyle(color: FixiaColors.error)),
          ),
        if (_saveError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_saveError!,
                key: const ValueKey('availability-save-error'),
                style: const TextStyle(color: FixiaColors.error)),
          ),
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
  }

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
