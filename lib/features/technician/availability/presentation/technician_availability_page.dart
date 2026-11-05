import 'package:flutter/material.dart';

import '../../../../core/constants/colombian_cities.dart';
import '../../../../core/layout/app_shell.dart';
import '../../../../core/theme/fixia_theme.dart';
import '../../../../core/widgets/fixia_ui.dart';
import '../application/ports/technician_availability_repository.dart';
import '../domain/availability_rules.dart';
import '../domain/clock_time.dart';
import '../domain/coverage_zone.dart';
import '../domain/technician_availability_exceptions.dart';
import '../domain/weekday.dart';
import '../domain/weekly_availability.dart';

/// Horario semanal y zona de atención del técnico (GC-329, sobre la
/// integración de GC-330). Sin las dos cosas ms-users no lo considera
/// elegible y no le llega ninguna solicitud, por eso la pantalla lo explica.
class TechnicianAvailabilityPage extends StatefulWidget {
  const TechnicianAvailabilityPage({
    super.key,
    required this.repository,
    this.onSessionExpired,
    this.onSaved,
  });

  final TechnicianAvailabilityRepository repository;
  final VoidCallback? onSessionExpired;

  /// Se llama después de guardar con éxito (p. ej. para refrescar el inicio).
  final VoidCallback? onSaved;

  /// Ciudades sugeridas; se puede escribir cualquier otra.
  static const suggestedCities = [
    'Bogotá',
    'Medellín',
    'Cali',
    'Barranquilla',
    'Cartagena',
    'Bucaramanga',
  ];

  @override
  State<TechnicianAvailabilityPage> createState() =>
      _TechnicianAvailabilityPageState();
}

/// Franja editable de un día.
class _Range {
  _Range(this.start, this.end);
  ClockTime start;
  ClockTime end;
}

class _TechnicianAvailabilityPageState
    extends State<TechnicianAvailabilityPage> {
  String? _city;

  /// Ciudad guardada que no está en la lista (p. ej. escrita a mano antes):
  /// se avisa para que elija una de la lista.
  String? _unknownSavedCity;
  final Map<Weekday, List<_Range>> _days = {
    for (final d in Weekday.values) d: <_Range>[],
  };
  CoverageZone? _savedZone;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _slotsError;
  String? _cityError;
  String? _saveError;
  bool _justSaved = false;

  /// Horas cada 30 minutos, de 00:00 a 23:30.
  static final List<ClockTime> _times = [
    for (var m = 0; m < 24 * 60; m += 30) ClockTime(m ~/ 60, m % 60),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait<Object?>([
        widget.repository.fetchAvailability(),
        widget.repository.fetchCoverageZone(),
      ]);
      if (!mounted) return;
      final availability = results[0] as WeeklyAvailability;
      final zone = results[1] as CoverageZone?;
      setState(() {
        for (final d in Weekday.values) {
          _days[d] = [
            for (final s in availability.slots)
              if (s.day == d) _Range(s.start, s.end),
          ]..sort((a, b) => a.start.compareTo(b.start));
        }
        _savedZone = zone;
        _city = ColombianCities.match(zone?.city);
        _unknownSavedCity = zone != null && _city == null ? zone.city : null;
        _loading = false;
      });
    } on TechnicianAvailabilityFailure catch (failure) {
      if (!mounted) return;
      if (failure.isSessionExpired) return widget.onSessionExpired?.call();
      setState(() {
        _loading = false;
        _loadError = failure.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'No pudimos cargar tu horario. Inténtalo de nuevo.';
      });
    }
  }

  List<AvailabilitySlot> get _slots => [
        for (final d in Weekday.values)
          for (final r in _days[d]!)
            AvailabilitySlot(day: d, start: r.start, end: r.end),
      ];

  bool get _hasSchedule => _days.values.any((ranges) => ranges.isNotEmpty);

  void _changed() => setState(() {
        _justSaved = false;
        _saveError = null;
        _slotsError = AvailabilityRules.slots(_slots);
      });

  void _toggleDay(Weekday day, bool on) {
    _days[day] = on
        ? [_Range(const ClockTime(8, 0), const ClockTime(17, 0))]
        : <_Range>[];
    _changed();
  }

  void _addRange(Weekday day) {
    final ranges = _days[day]!;
    final lastEnd = ranges.isEmpty ? const ClockTime(8, 0) : ranges.last.end;
    final startMinutes = (lastEnd.minutesOfDay + 60).clamp(0, 22 * 60);
    final start = ClockTime(startMinutes ~/ 60, startMinutes % 60);
    final endMinutes = (startMinutes + 120).clamp(0, 23 * 60 + 30);
    ranges.add(_Range(start, ClockTime(endMinutes ~/ 60, endMinutes % 60)));
    _changed();
  }

  void _applyPreset(Set<Weekday> days, ClockTime start, ClockTime end) {
    for (final d in Weekday.values) {
      _days[d] = days.contains(d) ? [_Range(start, end)] : <_Range>[];
    }
    _changed();
  }

  void _copyMondayToAll() {
    final monday = _days[Weekday.monday]!;
    for (final d in Weekday.values) {
      if (d == Weekday.monday) continue;
      _days[d] = [for (final r in monday) _Range(r.start, r.end)];
    }
    _changed();
  }

  Future<void> _save() async {
    final city = _city ?? '';
    final zone = CoverageZoneUpdate(
      city: city,
      // Si ya tenía un radio guardado, se conserva.
      latitude: _savedZone?.latitude,
      longitude: _savedZone?.longitude,
      radiusKm: _savedZone?.radiusKm,
    );
    final zoneErrors = city.isEmpty
        ? {'city': 'Elige la ciudad donde atiendes.'}
        : AvailabilityRules.coverageZone(zone);
    final slotsError = AvailabilityRules.slots(_slots);
    setState(() {
      _cityError = zoneErrors['city'];
      _slotsError = slotsError ??
          (_hasSchedule ? null : 'Activa al menos un día con su horario.');
      _saveError = null;
      _justSaved = false;
    });
    if (_cityError != null || _slotsError != null) return;
    setState(() => _saving = true);
    try {
      final savedZone = await widget.repository.updateCoverageZone(zone);
      await widget.repository.replaceAvailability(List.unmodifiable(_slots));
      if (!mounted) return;
      setState(() {
        _savedZone = savedZone;
        _unknownSavedCity = null;
        _saving = false;
        _justSaved = true;
      });
      widget.onSaved?.call();
    } on TechnicianAvailabilityFailure catch (failure) {
      if (!mounted) return;
      if (failure.isSessionExpired) return widget.onSessionExpired?.call();
      setState(() {
        _saving = false;
        _cityError = failure.fieldErrors['city'];
        _slotsError = failure.fieldErrors['slots'];
        _saveError = failure.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const SectionLoading();
    } else if (_loadError != null) {
      body = EmptyState(
        icon: Icons.cloud_off_outlined,
        message: _loadError!,
        action: OutlinedButton(
          key: const ValueKey('availability-retry'),
          onPressed: _load,
          child: const Text('Reintentar'),
        ),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_justSaved)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: NoticeBanner(
                key: ValueKey('availability-saved'),
                message:
                    'Guardado. Ya te llegarán las solicitudes de tu ciudad, especialidades y horario.',
                tone: PillTone.success,
                icon: Icons.check_circle_outline_rounded,
              ),
            ),
          TwoColumns(
            sideWidth: 340,
            sideFirstWhenStacked: true,
            main: _scheduleSection(),
            side: _zoneSection(),
          ),
          const SizedBox(height: 20),
          if (_saveError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _saveError!,
                key: const ValueKey('availability-save-error'),
                style: const TextStyle(color: FixiaColors.error),
              ),
            ),
          ActionBar(actions: [
            FilledButton.icon(
              key: const ValueKey('availability-save'),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(_saving ? 'Guardando…' : 'Guardar horario y zona'),
            ),
          ]),
        ],
      );
    }
    return AppShell(
      destination: ShellDestination.technicianProfile,
      subpage: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BackLink(),
          const PageHeader(
            title: 'Horario y zona de atención',
            subtitle:
                'Solo te llegan solicitudes de tu ciudad, de tus especialidades y en los horarios en que atiendes.',
          ),
          const SizedBox(height: 24),
          body,
        ],
      ),
    );
  }

  Widget _zoneSection() {
    final circle = _savedZone?.hasCircle ?? false;
    return FixiaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Zona de atención',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: FixiaColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ciudad donde atiendes. Los clientes no ven tu ubicación.',
            style: TextStyle(fontSize: 13, color: FixiaColors.textSecondary),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: const ValueKey('availability-city'),
            // Flutter 3.22 necesita `value`.
            // ignore: deprecated_member_use
            value: _city,
            isExpanded: true,
            menuMaxHeight: 360,
            decoration: InputDecoration(
              labelText: 'Ciudad *',
              prefixIcon: const Icon(Icons.location_city_outlined),
              errorText: _cityError,
            ),
            hint: const Text('Elige tu ciudad'),
            items: [
              for (final c in ColombianCities.all)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (value) => setState(() {
              _city = value;
              _cityError = null;
              _justSaved = false;
            }),
          ),
          if (_unknownSavedCity != null) ...[
            const SizedBox(height: 10),
            NoticeBanner(
              key: const ValueKey('availability-unknown-city'),
              message:
                  'Tenías guardada la ciudad «$_unknownSavedCity», que no coincide con las de las solicitudes. Elige una de la lista y guarda.',
              tone: PillTone.warning,
              icon: Icons.warning_amber_rounded,
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in TechnicianAvailabilityPage.suggestedCities)
                ActionChip(
                  key: ValueKey('availability-city-$c'),
                  label: Text(c),
                  onPressed: () => setState(() {
                    _city = c;
                    _cityError = null;
                    _justSaved = false;
                  }),
                ),
            ],
          ),
          if (circle) ...[
            const SizedBox(height: 12),
            Text(
              'Atiendes en un radio de ${_savedZone!.radiusKm} km dentro de la ciudad.',
              style: const TextStyle(
                fontSize: 13,
                color: FixiaColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _scheduleSection() {
    return FixiaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Horario semanal',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: FixiaColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Activa los días que trabajas y sus horas (hora de Colombia).',
            style: TextStyle(fontSize: 13, color: FixiaColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const ValueKey('availability-preset-weekdays'),
                onPressed: () => _applyPreset(
                  {
                    Weekday.monday,
                    Weekday.tuesday,
                    Weekday.wednesday,
                    Weekday.thursday,
                    Weekday.friday,
                  },
                  const ClockTime(8, 0),
                  const ClockTime(17, 0),
                ),
                child: const Text('Lun a vie, 8:00–17:00'),
              ),
              OutlinedButton(
                key: const ValueKey('availability-preset-all'),
                onPressed: () => _applyPreset(
                  Weekday.values.toSet(),
                  const ClockTime(6, 0),
                  const ClockTime(22, 0),
                ),
                child: const Text('Todos los días, 6:00–22:00'),
              ),
              if (_days[Weekday.monday]!.isNotEmpty)
                TextButton.icon(
                  key: const ValueKey('availability-copy-monday'),
                  onPressed: _copyMondayToAll,
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                  label: const Text('Copiar lunes a toda la semana'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (final day in Weekday.values) _dayRow(day),
          if (_slotsError != null) ...[
            const SizedBox(height: 8),
            Text(
              _slotsError!,
              key: const ValueKey('availability-slots-error'),
              style: const TextStyle(color: FixiaColors.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dayRow(Weekday day) {
    final ranges = _days[day]!;
    final on = ranges.isNotEmpty;
    return Container(
      key: ValueKey('availability-day-${day.apiValue}'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEEF2F7))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 560;
          final toggle = SizedBox(
            width: 150,
            child: Row(
              children: [
                Switch(
                  key: ValueKey('availability-toggle-${day.apiValue}'),
                  value: on,
                  onChanged: (v) => _toggleDay(day, v),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    day.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color:
                          on ? FixiaColors.primary : FixiaColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          );
          final detail = on
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < ranges.length; i++)
                      _rangeRow(day, i, ranges[i]),
                    TextButton.icon(
                      key: ValueKey('availability-add-${day.apiValue}'),
                      onPressed: () => _addRange(day),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Agregar franja'),
                    ),
                  ],
                )
              : const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'No atiendes',
                    style: TextStyle(color: FixiaColors.textSecondary),
                  ),
                );
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                toggle,
                const SizedBox(width: 12),
                Expanded(child: detail)
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [toggle, if (on) detail],
          );
        },
      ),
    );
  }

  Widget _rangeRow(Weekday day, int index, _Range range) {
    Widget picker(String key, ClockTime value, ValueChanged<ClockTime> set) =>
        SizedBox(
          width: 130,
          child: DropdownButtonFormField<ClockTime>(
            key: ValueKey(key),
            // Flutter 3.22 necesita `value`.
            // ignore: deprecated_member_use
            value: value,
            isDense: true,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            items: [
              for (final t in _times)
                DropdownMenuItem(value: t, child: Text(t.format())),
            ],
            onChanged: (v) {
              if (v == null) return;
              set(v);
              _changed();
            },
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          picker('availability-start-${day.apiValue}-$index', range.start,
              (v) => range.start = v),
          const Text('a'),
          picker('availability-end-${day.apiValue}-$index', range.end,
              (v) => range.end = v),
          IconButton(
            key: ValueKey('availability-remove-${day.apiValue}-$index'),
            tooltip: 'Quitar franja',
            onPressed: () {
              _days[day]!.removeAt(index);
              _changed();
            },
            icon: const Icon(Icons.delete_outline_rounded,
                color: FixiaColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
