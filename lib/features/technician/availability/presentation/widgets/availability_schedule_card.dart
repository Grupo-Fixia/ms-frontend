import 'package:flutter/material.dart';

import '../../../../../core/theme/fixia_theme.dart';
import '../../domain/availability_day.dart';
import '../../domain/availability_hours.dart';

/// Selector de horario estilo alarma: una hora de inicio y fin y una fila
/// de círculos para elegir los días en que aplica.
class AvailabilityScheduleCard extends StatelessWidget {
  const AvailabilityScheduleCard({
    super.key,
    required this.selectedDays,
    required this.hours,
    required this.onDayToggled,
    required this.onPresetSelected,
    required this.onStartPressed,
    required this.onEndPressed,
    this.hasMixedHours = false,
  });

  static const _initials = {
    AvailabilityDay.monday: 'L',
    AvailabilityDay.tuesday: 'M',
    AvailabilityDay.wednesday: 'X',
    AvailabilityDay.thursday: 'J',
    AvailabilityDay.friday: 'V',
    AvailabilityDay.saturday: 'S',
    AvailabilityDay.sunday: 'D',
  };

  final Set<AvailabilityDay> selectedDays;
  final AvailabilityHours? hours;
  final bool hasMixedHours;
  final ValueChanged<AvailabilityDay> onDayToggled;
  final ValueChanged<Set<AvailabilityDay>> onPresetSelected;
  final VoidCallback onStartPressed;
  final VoidCallback onEndPressed;

  static String format(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  String get _summary {
    if (selectedDays.isEmpty) return 'Sin días seleccionados';
    if (selectedDays.length == 7) return 'Todos los días';
    final weekdays = AvailabilityDay.values.take(5).toSet();
    if (selectedDays.length == 5 && selectedDays.containsAll(weekdays)) {
      return 'Lunes a viernes';
    }
    return AvailabilityDay.values
        .where(selectedDays.contains)
        .map((d) => d.label.substring(0, 3))
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final valid = hours?.isValid ?? true;
    final enabled = selectedDays.isNotEmpty && hours != null;
    return Container(
      key: const ValueKey('availability-schedule-card'),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: FixiaColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: enabled && !valid
                ? FixiaColors.error
                : const Color(0xFFE3EAF4)),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TimeDisplay(
                  keyName: 'availability-start-time',
                  label: 'Desde',
                  minutes: hours?.startMinutes,
                  error: enabled && !valid,
                  onPressed: enabled ? onStartPressed : null,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('–',
                      style: TextStyle(
                          fontSize: 34, color: FixiaColors.textSecondary)),
                ),
                _TimeDisplay(
                  keyName: 'availability-end-time',
                  label: 'Hasta',
                  minutes: hours?.endMinutes,
                  error: enabled && !valid,
                  onPressed: enabled ? onEndPressed : null,
                ),
              ],
            ),
          ),
          if (enabled && !valid)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('La hora final debe ser posterior a la inicial.',
                  style: TextStyle(color: FixiaColors.error, fontSize: 12)),
            ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final day in AvailabilityDay.values)
                _DayCircle(
                  day: day,
                  initial: _initials[day]!,
                  selected: selectedDays.contains(day),
                  onTap: () => onDayToggled(day),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(_summary,
              key: const ValueKey('availability-days-summary'),
              style: const TextStyle(
                  color: FixiaColors.primary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                key: const ValueKey('availability-preset-weekdays'),
                label: const Text('Lun–Vie'),
                onPressed: () =>
                    onPresetSelected(AvailabilityDay.values.take(5).toSet()),
              ),
              ActionChip(
                key: const ValueKey('availability-preset-all'),
                label: const Text('Todos'),
                onPressed: () =>
                    onPresetSelected(AvailabilityDay.values.toSet()),
              ),
            ],
          ),
          if (hasMixedHours)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                  'Tenías horarios distintos por día; al cambiar la hora se unificarán.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: FixiaColors.textSecondary, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class _TimeDisplay extends StatelessWidget {
  const _TimeDisplay({
    required this.keyName,
    required this.label,
    required this.minutes,
    required this.error,
    required this.onPressed,
  });

  final String keyName;
  final String label;
  final int? minutes;
  final bool error;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => InkWell(
        key: ValueKey(keyName),
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            children: [
              Text(label,
                  style: const TextStyle(
                      color: FixiaColors.textSecondary, fontSize: 12)),
              Text(
                minutes == null
                    ? '--:--'
                    : AvailabilityScheduleCard.format(minutes!),
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w300,
                  color: error ? FixiaColors.error : FixiaColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
}

class _DayCircle extends StatelessWidget {
  const _DayCircle({
    required this.day,
    required this.initial,
    required this.selected,
    required this.onTap,
  });

  final AvailabilityDay day;
  final String initial;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        label: day.label,
        selected: selected,
        button: true,
        child: GestureDetector(
          key: ValueKey('availability-toggle-${day.label}'),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? FixiaColors.secondary : Colors.transparent,
              border: Border.all(
                  color: selected
                      ? FixiaColors.secondary
                      : const Color(0xFFD6E0EC)),
            ),
            child: Text(initial,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? FixiaColors.white
                        : FixiaColors.textPrimary)),
          ),
        ),
      );
}
