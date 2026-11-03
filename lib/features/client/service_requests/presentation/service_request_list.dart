import 'package:flutter/material.dart';

import '../../../../core/theme/fixia_theme.dart';
import '../../../../core/widgets/fixia_ui.dart';
import '../domain/service_request.dart';

/// Qué le toca hacer al cliente en cada estado, para destacarlo.
String? pendingActionFor(ServiceRequestStatus status) => switch (status) {
      ServiceRequestStatus.published => 'Revisa los postulantes',
      ServiceRequestStatus.providerSelected => 'Revisa la cotización',
      ServiceRequestStatus.technicianFinished => 'Confirma el cierre',
      _ => null,
    };

/// Tono de la etiqueta de cada estado.
PillTone toneFor(ServiceRequestStatus status) => switch (status) {
      ServiceRequestStatus.published => PillTone.neutral,
      ServiceRequestStatus.providerSelected ||
      ServiceRequestStatus.contracted ||
      ServiceRequestStatus.inProgress =>
        PillTone.info,
      ServiceRequestStatus.technicianFinished ||
      ServiceRequestStatus.closed =>
        PillTone.success,
      ServiceRequestStatus.cancelled ||
      ServiceRequestStatus.expired =>
        PillTone.neutral,
    };

/// Fecha corta (dd/mm/aaaa) en hora local.
String formatDay(DateTime value) {
  final d = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

/// Tabla en pantallas anchas y tarjetas en celular.
class ServiceRequestList extends StatelessWidget {
  const ServiceRequestList({
    super.key,
    required this.requests,
    required this.onOpen,
  });

  final List<ServiceRequest> requests;
  final ValueChanged<ServiceRequest> onOpen;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 600) return _table();
          return Column(
            children: [
              for (final r in requests) ...[
                _card(r),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      );

  Widget _table() {
    const header = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: FixiaColors.textSecondary,
      letterSpacing: 0.4,
    );
    return FixiaPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Row(
              children: [
                Expanded(flex: 5, child: Text('SOLICITUD', style: header)),
                Expanded(flex: 3, child: Text('ESTADO', style: header)),
                Expanded(flex: 2, child: Text('PRESUPUESTO', style: header)),
                Expanded(flex: 2, child: Text('PARA', style: header)),
              ],
            ),
          ),
          for (final r in requests)
            InkWell(
              key: ValueKey('client-request-row-${r.id}'),
              onTap: () => onOpen(r),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFEEF2F7))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${r.category.label} · ${r.approximateLocation.zone}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: FixiaColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: StatusPill(
                          label: r.status.label,
                          tone: toneFor(r.status),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        r.budget?.label ?? 'Presupuesto no informado',
                        style: TextStyle(
                          color: r.budget == null
                              ? FixiaColors.textSecondary
                              : null,
                          fontSize: r.budget == null ? 12 : null,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        formatDay(r.expectedAt),
                        style:
                            const TextStyle(color: FixiaColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(ServiceRequest r) => InkWell(
        key: ValueKey('client-request-row-${r.id}'),
        onTap: () => onOpen(r),
        borderRadius: BorderRadius.circular(16),
        child: FixiaPanel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusPill(label: r.status.label, tone: toneFor(r.status)),
                  Text(
                    '${r.category.label} · ${r.approximateLocation.zone}, ${r.approximateLocation.city}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: FixiaColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                r.budget == null
                    ? 'Presupuesto no informado'
                    : 'Presupuesto: ${r.budget!.label} · Para el ${formatDay(r.expectedAt)}',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      );
}
