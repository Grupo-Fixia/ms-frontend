import 'package:flutter/material.dart';

import '../theme/fixia_theme.dart';

/// Selector de fecha y hora con la identidad de Fixia: calendario del mes y
/// horarios en franjas (mañana, tarde, noche) en vez del calendario y el
/// reloj genéricos de Material. En computador se abre como ventana con el
/// calendario y los horarios lado a lado; en celular, como hoja inferior.
///
/// Devuelve la fecha y hora elegidas en hora local, o `null` si se cancela.
Future<DateTime?> showFixiaDateTimePicker(
  BuildContext context, {
  required DateTime first,
  required DateTime last,
  DateTime? initial,
  bool pickTime = true,
  String title = 'Elige fecha y hora',
  String? subtitle,
  int startHour = 6,
  int endHour = 22,
  int minuteStep = 30,
  String confirmLabel = 'Confirmar',
}) {
  final picker = FixiaDateTimePicker(
    first: first,
    last: last,
    initial: initial,
    pickTime: pickTime,
    title: title,
    subtitle: subtitle,
    startHour: startHour,
    endHour: endHour,
    minuteStep: minuteStep,
    confirmLabel: confirmLabel,
  );
  if (MediaQuery.sizeOf(context).width < 640) {
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FixiaColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FractionallySizedBox(heightFactor: 0.92, child: picker),
    );
  }
  return showDialog<DateTime>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: FixiaColors.white,
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: pickTime ? 760 : 420),
        child: picker,
      ),
    ),
  );
}

const _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];
const _weekdays = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];
const _weekdayInitials = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
const _border = Color(0xFFE3EAF4);

String _two(int n) => n.toString().padLeft(2, '0');

/// «jueves 6 de noviembre».
String fixiaLongDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]} ${d.day} de ${_months[d.month - 1]}';

/// «10:30 a. m.».
String fixiaTime(int hour, int minute) {
  final h = hour % 12 == 0 ? 12 : hour % 12;
  return '$h:${_two(minute)} ${hour < 12 ? 'a. m.' : 'p. m.'}';
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

class FixiaDateTimePicker extends StatefulWidget {
  const FixiaDateTimePicker({
    super.key,
    required this.first,
    required this.last,
    this.initial,
    this.pickTime = true,
    this.title = 'Elige fecha y hora',
    this.subtitle,
    this.startHour = 6,
    this.endHour = 22,
    this.minuteStep = 30,
    this.confirmLabel = 'Confirmar',
  });

  /// Primer momento permitido (los días y horas anteriores se deshabilitan).
  final DateTime first;

  /// Último día permitido.
  final DateTime last;
  final DateTime? initial;

  /// `false` para elegir solo el día.
  final bool pickTime;
  final String title;
  final String? subtitle;

  /// Horarios disponibles: desde [startHour] hasta antes de [endHour], cada
  /// [minuteStep] minutos.
  final int startHour;
  final int endHour;
  final int minuteStep;
  final String confirmLabel;

  @override
  State<FixiaDateTimePicker> createState() => _FixiaDateTimePickerState();
}

class _FixiaDateTimePickerState extends State<FixiaDateTimePicker> {
  late DateTime _month;
  DateTime? _date;
  ({int hour, int minute})? _time;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null &&
        !_day(initial).isBefore(_day(widget.first)) &&
        !_day(initial).isAfter(_day(widget.last))) {
      _date = _day(initial);
      if (widget.pickTime) {
        final slot = (hour: initial.hour, minute: initial.minute);
        if (_slotAllowed(_date!, slot)) _time = slot;
      }
    }
    _month =
        DateTime((_date ?? widget.first).year, (_date ?? widget.first).month);
  }

  List<({int hour, int minute})> get _slots => [
        for (var m = widget.startHour * 60;
            m < widget.endHour * 60;
            m += widget.minuteStep)
          (hour: m ~/ 60, minute: m % 60),
      ];

  bool _dayAllowed(DateTime day) {
    if (day.isBefore(_day(widget.first)) || day.isAfter(_day(widget.last))) {
      return false;
    }
    // Un día sin ningún horario libre (p. ej. hoy ya tarde) no se ofrece.
    if (widget.pickTime) return _slots.any((s) => _slotAllowed(day, s));
    return true;
  }

  bool _slotAllowed(DateTime day, ({int hour, int minute}) slot) {
    final moment =
        DateTime(day.year, day.month, day.day, slot.hour, slot.minute);
    if (moment.isBefore(widget.first)) return false;
    final lastMoment =
        DateTime(widget.last.year, widget.last.month, widget.last.day, 23, 59);
    return !moment.isAfter(lastMoment);
  }

  DateTime? get _result {
    final date = _date;
    if (date == null) return null;
    if (!widget.pickTime) return date;
    final time = _time;
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _pickDay(DateTime day) => setState(() {
        _date = day;
        if (_time != null && !_slotAllowed(day, _time!)) _time = null;
      });

  bool get _canGoBack => DateTime(_month.year, _month.month)
      .isAfter(DateTime(widget.first.year, widget.first.month));

  bool get _canGoForward => DateTime(_month.year, _month.month)
      .isBefore(DateTime(widget.last.year, widget.last.month));

  void _shiftMonth(int delta) => setState(() {
        _month = DateTime(_month.year, _month.month + delta);
      });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 640;
    final calendar = _Calendar(
      month: _month,
      selected: _date,
      today: _day(DateTime.now()),
      isAllowed: _dayAllowed,
      onPick: _pickDay,
      canGoBack: _canGoBack,
      canGoForward: _canGoForward,
      onShift: _shiftMonth,
    );
    final times = widget.pickTime
        ? _TimeSlots(
            date: _date,
            slots: _slots,
            selected: _time,
            isAllowed: (s) => _date != null && _slotAllowed(_date!, s),
            onPick: (s) => setState(() => _time = s),
          )
        : null;
    final body = wide && times != null
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 340, child: calendar),
              const SizedBox(width: 24),
              Expanded(child: times),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              calendar,
              if (times != null) ...[const SizedBox(height: 20), times],
            ],
          );
    return Column(
      key: const ValueKey('fixia-date-time-picker'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          title: widget.title,
          subtitle: widget.subtitle,
          summary: _summary(),
          onClose: () => Navigator.of(context).pop(),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: body,
          ),
        ),
        _Footer(
          confirmLabel: widget.confirmLabel,
          onConfirm:
              _result == null ? null : () => Navigator.of(context).pop(_result),
        ),
      ],
    );
  }

  String _summary() {
    final date = _date;
    if (date == null) {
      return widget.pickTime ? 'Elige el día y la hora' : 'Elige el día';
    }
    final day = fixiaLongDate(date);
    final capitalized = day[0].toUpperCase() + day.substring(1);
    if (!widget.pickTime) return capitalized;
    final time = _time;
    return time == null
        ? '$capitalized · elige la hora'
        : '$capitalized · ${fixiaTime(time.hour, time.minute)}';
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.onClose,
  });

  final String title;
  final String? subtitle;
  final String summary;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
        color: FixiaColors.primary,
        padding: const EdgeInsets.fromLTRB(24, 18, 12, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: FixiaColors.secondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.event_available_rounded,
                  color: FixiaColors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: FixiaColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: Color(0xFFB7CCE8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    summary,
                    key: const ValueKey('fixia-picker-summary'),
                    style: const TextStyle(
                      color: Color(0xFF7FE0CF),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Cerrar',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, color: FixiaColors.white),
            ),
          ],
        ),
      );
}

class _Calendar extends StatelessWidget {
  const _Calendar({
    required this.month,
    required this.selected,
    required this.today,
    required this.isAllowed,
    required this.onPick,
    required this.canGoBack,
    required this.canGoForward,
    required this.onShift,
  });

  final DateTime month;
  final DateTime? selected;
  final DateTime today;
  final bool Function(DateTime day) isAllowed;
  final ValueChanged<DateTime> onPick;
  final bool canGoBack;
  final bool canGoForward;
  final ValueChanged<int> onShift;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = firstDay.weekday - 1;
    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (var d = 1; d <= daysInMonth; d++)
        _DayCell(
          day: DateTime(month.year, month.month, d),
          selected: selected != null &&
              selected == DateTime(month.year, month.month, d),
          today: today == DateTime(month.year, month.month, d),
          enabled: isAllowed(DateTime(month.year, month.month, d)),
          onPick: onPick,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_months[month.month - 1][0].toUpperCase()}${_months[month.month - 1].substring(1)} ${month.year}',
                key: const ValueKey('fixia-picker-month'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: FixiaColors.primary,
                ),
              ),
            ),
            _NavButton(
              key: const ValueKey('fixia-picker-prev'),
              icon: Icons.chevron_left_rounded,
              tooltip: 'Mes anterior',
              onTap: canGoBack ? () => onShift(-1) : null,
            ),
            const SizedBox(width: 6),
            _NavButton(
              key: const ValueKey('fixia-picker-next'),
              icon: Icons.chevron_right_rounded,
              tooltip: 'Mes siguiente',
              onTap: canGoForward ? () => onShift(1) : null,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final w in _weekdayInitials)
              Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: FixiaColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: cells,
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: onTap == null
              ? const Color(0xFFF4F7FB)
              : FixiaColors.supportBackground,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 34,
              height: 34,
              child: Icon(
                icon,
                color: onTap == null
                    ? const Color(0xFFB8C4D3)
                    : FixiaColors.primary,
              ),
            ),
          ),
        ),
      );
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.today,
    required this.enabled,
    required this.onPick,
  });

  final DateTime day;
  final bool selected;
  final bool today;
  final bool enabled;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final Color background = selected
        ? FixiaColors.secondary
        : today && enabled
            ? FixiaColors.supportBackground
            : Colors.transparent;
    final Color foreground = selected
        ? FixiaColors.white
        : enabled
            ? FixiaColors.primary
            : const Color(0xFFC3CDD9);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: fixiaLongDate(day),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: ValueKey(
              'fixia-picker-day-${day.year}-${_two(day.month)}-${_two(day.day)}'),
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? () => onPick(day) : null,
          child: Container(
            alignment: Alignment.center,
            decoration: today && !selected
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: FixiaColors.secondary),
                  )
                : null,
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontWeight:
                    selected || today ? FontWeight.w800 : FontWeight.w600,
                color: foreground,
                decoration: enabled ? null : TextDecoration.lineThrough,
                decorationColor: const Color(0xFFC3CDD9),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeSlots extends StatelessWidget {
  const _TimeSlots({
    required this.date,
    required this.slots,
    required this.selected,
    required this.isAllowed,
    required this.onPick,
  });

  final DateTime? date;
  final List<({int hour, int minute})> slots;
  final ({int hour, int minute})? selected;
  final bool Function(({int hour, int minute}) slot) isAllowed;
  final ValueChanged<({int hour, int minute})> onPick;

  @override
  Widget build(BuildContext context) {
    final groups = [
      ('Mañana', Icons.wb_twilight_rounded, slots.where((s) => s.hour < 12)),
      (
        'Tarde',
        Icons.wb_sunny_outlined,
        slots.where((s) => s.hour >= 12 && s.hour < 18)
      ),
      ('Noche', Icons.nights_stay_outlined, slots.where((s) => s.hour >= 18)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Hora',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: FixiaColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          date == null
              ? 'Primero elige un día en el calendario.'
              : 'Horarios disponibles el ${fixiaLongDate(date!)}.',
          style:
              const TextStyle(fontSize: 13, color: FixiaColors.textSecondary),
        ),
        const SizedBox(height: 12),
        for (final (label, icon, items) in groups)
          if (items.isNotEmpty) ...[
            Row(
              children: [
                Icon(icon, size: 16, color: FixiaColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: FixiaColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final slot in items)
                  _SlotChip(
                    slot: slot,
                    selected: selected == slot,
                    enabled: isAllowed(slot),
                    onPick: onPick,
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],
      ],
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.slot,
    required this.selected,
    required this.enabled,
    required this.onPick,
  });

  final ({int hour, int minute}) slot;
  final bool selected;
  final bool enabled;
  final ValueChanged<({int hour, int minute})> onPick;

  @override
  Widget build(BuildContext context) => Material(
        color: selected
            ? FixiaColors.secondary
            : enabled
                ? FixiaColors.white
                : const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: ValueKey(
              'fixia-picker-slot-${_two(slot.hour)}:${_two(slot.minute)}'),
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? () => onPick(slot) : null,
          child: Container(
            width: 92,
            padding: const EdgeInsets.symmetric(vertical: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? FixiaColors.secondary : _border,
              ),
            ),
            child: Text(
              fixiaTime(slot.hour, slot.minute),
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected
                    ? FixiaColors.white
                    : enabled
                        ? FixiaColors.primary
                        : const Color(0xFFC3CDD9),
              ),
            ),
          ),
        ),
      );
}

class _Footer extends StatelessWidget {
  const _Footer({required this.confirmLabel, required this.onConfirm});

  final String confirmLabel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _border)),
        ),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cancel = TextButton(
                key: const ValueKey('fixia-picker-cancel'),
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(minimumSize: const Size(0, 46)),
                child: const Text('Cancelar'),
              );
              final confirm = FilledButton(
                key: const ValueKey('fixia-picker-confirm'),
                onPressed: onConfirm,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                child: Text(confirmLabel),
              );
              // En celular los dos botones se reparten el ancho.
              if (constraints.maxWidth < 420) {
                return Row(
                  children: [
                    Expanded(child: cancel),
                    const SizedBox(width: 10),
                    Expanded(child: confirm),
                  ],
                );
              }
              return Row(
                children: [
                  const Spacer(),
                  cancel,
                  const SizedBox(width: 10),
                  SizedBox(width: 160, child: confirm),
                ],
              );
            },
          ),
        ),
      );
}
