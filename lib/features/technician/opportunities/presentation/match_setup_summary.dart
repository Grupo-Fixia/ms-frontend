import 'package:flutter/material.dart';

import '../../../../core/constants/colombian_cities.dart';
import '../../../../core/constants/service_category.dart';
import '../../../../core/theme/fixia_theme.dart';
import '../../../../core/widgets/fixia_ui.dart';
import '../../availability/domain/weekly_availability.dart';

/// Lo que ms-services cruza para decidir qué solicitudes ve el técnico:
/// ciudad de su zona, franjas de horario y especialidades.
///
/// Cada parte es `null` si no se pudo consultar (se muestra "–"), para no
/// confundir "no lo sé" con "no lo tienes".
class MatchSetup {
  const MatchSetup({
    this.zoneLoaded = false,
    this.city,
    this.slots,
    this.categories,
  });

  /// `true` si la zona se consultó; entonces `city == null` es "sin zona".
  final bool zoneLoaded;
  final String? city;
  final List<AvailabilitySlot>? slots;
  final Set<ServiceCategory>? categories;

  bool get missingZone => zoneLoaded && (city == null || city!.trim().isEmpty);

  /// Ciudad guardada a mano que no coincide con las de las solicitudes.
  bool get cityOutsideList =>
      zoneLoaded && !missingZone && ColombianCities.match(city) == null;

  bool get missingSlots => slots != null && slots!.isEmpty;
  bool get missingCategories => categories != null && categories!.isEmpty;
}

/// Resume el horario por días, juntando días seguidos con las mismas
/// franjas: "Lunes a Viernes 08:00–17:00 · Sábado 09:00–12:00".
String describeWeeklySlots(List<AvailabilitySlot> slots) {
  final byDay = <int, List<String>>{};
  for (final slot in slots) {
    byDay
        .putIfAbsent(slot.day.index, () => [])
        .add('${slot.start.format()}–${slot.end.format()}');
  }
  final days = byDay.keys.toList()..sort();
  final groups = <String>[];
  var i = 0;
  while (i < days.length) {
    var j = i;
    final ranges = byDay[days[i]]!.join(', ');
    while (j + 1 < days.length &&
        days[j + 1] == days[j] + 1 &&
        byDay[days[j + 1]]!.join(', ') == ranges) {
      j++;
    }
    final first = _dayLabel(days[i]);
    final label = i == j
        ? first
        : j == i + 1
            ? '$first y ${_dayLabel(days[j])}'
            : '$first a ${_dayLabel(days[j])}';
    groups.add('$label $ranges');
    i = j + 1;
  }
  return groups.join(' · ');
}

String _dayLabel(int index) => const [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ][index];

/// Estado vacío de oportunidades que explica qué se cruza y muestra la
/// configuración del técnico, con accesos para corregirla.
class MatchSetupSummary extends StatefulWidget {
  const MatchSetupSummary({
    super.key,
    required this.message,
    required this.load,
    this.onOpenAvailability,
    this.onOpenSpecialties,
  });

  final String message;
  final Future<MatchSetup> Function() load;
  final VoidCallback? onOpenAvailability;
  final VoidCallback? onOpenSpecialties;

  @override
  State<MatchSetupSummary> createState() => _MatchSetupSummaryState();
}

class _MatchSetupSummaryState extends State<MatchSetupSummary> {
  late Future<MatchSetup> _future = widget.load()..ignore();

  @override
  void didUpdateWidget(covariant MatchSetupSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.load != widget.load) _future = widget.load()..ignore();
  }

  @override
  Widget build(BuildContext context) {
    return FixiaPanel(
      key: const ValueKey('match-setup-summary'),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.search_off_rounded,
                  color: Color(0xFF9AAABB), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.message,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: FixiaColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Solo ves solicitudes de tu ciudad, de tus especialidades y cuya '
            'fecha cae dentro de tu horario. Revisa tu configuración:',
            style: TextStyle(color: FixiaColors.textSecondary),
          ),
          const SizedBox(height: 12),
          FutureBuilder<MatchSetup>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(
                      key: ValueKey('match-setup-loading')),
                );
              }
              final setup = snapshot.data ?? const MatchSetup();
              return _Details(
                setup: setup,
                onOpenAvailability: widget.onOpenAvailability,
                onOpenSpecialties: widget.onOpenSpecialties,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.setup,
    this.onOpenAvailability,
    this.onOpenSpecialties,
  });

  final MatchSetup setup;
  final VoidCallback? onOpenAvailability;
  final VoidCallback? onOpenSpecialties;

  @override
  Widget build(BuildContext context) {
    final city = !setup.zoneLoaded
        ? '–'
        : setup.missingZone
            ? 'Sin configurar'
            : setup.city!;
    final slots = setup.slots == null
        ? '–'
        : setup.missingSlots
            ? 'Sin configurar'
            : describeWeeklySlots(setup.slots!);
    final categories = setup.categories == null
        ? '–'
        : setup.missingCategories
            ? 'Sin especialidades'
            : (setup.categories!.map((c) => c.label).toList()..sort())
                .join(', ');

    final warnings = <String>[
      if (setup.missingZone) 'Configura la ciudad donde atiendes.',
      if (setup.cityOutsideList)
        '«${setup.city}» no coincide con las ciudades de las solicitudes. '
            'Elige una de la lista.',
      if (setup.missingSlots) 'Agrega al menos una franja de horario.',
      if (setup.missingCategories) 'Elige al menos una especialidad.',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoRow(label: 'Ciudad', value: city),
        InfoRow(label: 'Horario', value: slots),
        InfoRow(label: 'Especialidades', value: categories),
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: 8),
          NoticeBanner(
            key: const ValueKey('match-setup-warning'),
            message: warnings.join(' '),
            icon: Icons.warning_amber_rounded,
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (onOpenAvailability != null)
              OutlinedButton.icon(
                key: const ValueKey('match-setup-open-availability'),
                onPressed: onOpenAvailability,
                icon: const Icon(Icons.schedule_rounded, size: 18),
                label: const Text('Horario y zona'),
              ),
            if (onOpenSpecialties != null)
              OutlinedButton.icon(
                key: const ValueKey('match-setup-open-specialties'),
                onPressed: onOpenSpecialties,
                icon: const Icon(Icons.handyman_outlined, size: 18),
                label: const Text('Especialidades'),
              ),
          ],
        ),
      ],
    );
  }
}
