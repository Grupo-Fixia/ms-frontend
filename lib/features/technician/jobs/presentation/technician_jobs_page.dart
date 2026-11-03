import 'package:flutter/material.dart';

import '../../../../core/layout/app_shell.dart';
import '../../../../core/theme/fixia_theme.dart';
import '../../../../core/widgets/fixia_ui.dart';
import '../../../contracts/domain/service_contract.dart';
import '../../../quotations/presentation/quotation_card.dart';
import '../../applications/domain/service_application.dart';

/// «Mis trabajos» del técnico: solicitudes donde el cliente lo eligió (para
/// cotizar, GC-428) y servicios contratados (GC-429). Todo sale de
/// ms-services; sin datos de ejemplo.
class TechnicianJobsPage extends StatefulWidget {
  const TechnicianJobsPage({
    super.key,
    required this.loadApplications,
    required this.loadContracts,
    required this.onOpenQuotation,
    required this.onOpenContract,
    this.onOpenOpportunities,
  });

  final Future<List<ServiceApplication>> Function() loadApplications;
  final Future<List<ServiceContract>> Function() loadContracts;
  final Future<void> Function(ServiceApplication application) onOpenQuotation;
  final Future<void> Function(ServiceContract contract) onOpenContract;
  final VoidCallback? onOpenOpportunities;

  @override
  State<TechnicianJobsPage> createState() => _TechnicianJobsPageState();
}

class _TechnicianJobsPageState extends State<TechnicianJobsPage> {
  late Future<(List<ServiceApplication>, List<ServiceContract>)> _data =
      _load();

  Future<(List<ServiceApplication>, List<ServiceContract>)> _load() async {
    final results = await Future.wait<Object>([
      widget.loadApplications(),
      widget.loadContracts(),
    ]);
    return (
      results[0] as List<ServiceApplication>,
      results[1] as List<ServiceContract>,
    );
  }

  void _reload() => setState(() {
        _data = _load();
      });

  Future<void> _open(Future<void> Function() open) async {
    await open();
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => AppShell(
        destination: ShellDestination.technicianJobs,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Mis trabajos',
              subtitle:
                  'Cotizaciones por enviar y servicios que te contrataron.',
              actions: [
                OutlinedButton.icon(
                  key: const ValueKey('technician-jobs-refresh'),
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Actualizar'),
                ),
                if (widget.onOpenOpportunities != null)
                  FilledButton.icon(
                    onPressed: widget.onOpenOpportunities,
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Buscar oportunidades'),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FutureBuilder<(List<ServiceApplication>, List<ServiceContract>)>(
              future: _data,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SectionLoading();
                }
                if (snapshot.hasError) {
                  return EmptyState(
                    message: '${snapshot.error}',
                    icon: Icons.error_outline_rounded,
                    action: TextButton(
                      onPressed: _reload,
                      child: const Text('Reintentar'),
                    ),
                  );
                }
                final (applications, contracts) = snapshot.data!;
                final contracted = {
                  for (final c in contracts) c.serviceRequestId
                };
                final toQuote = [
                  for (final a in applications)
                    if (a.status == ApplicationStatus.selected &&
                        !contracted.contains(a.serviceRequest.id))
                      a,
                ];
                final active = [
                  for (final c in contracts)
                    if (c.serviceStatus == null || !c.serviceStatus!.isTerminal)
                      c,
                ];
                final finished = [
                  for (final c in contracts)
                    if (c.serviceStatus != null && c.serviceStatus!.isTerminal)
                      c,
                ];
                Widget contractCard(ServiceContract c) => _JobCard(
                      key: ValueKey('contract-${c.id}'),
                      eyebrow: c.serviceStatus?.label ?? 'Contratado',
                      title:
                          '${c.request.category.label} · ${formatCents(c.amountInCents, c.currency)}',
                      subtitle:
                          '${c.request.description}\n${formatDateTime(c.agreedAt)} · ${c.request.zone}, ${c.request.city}',
                      action: 'Ver',
                      onTap: () => _open(() => widget.onOpenContract(c)),
                    );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StatGrid(
                      minItemWidth: 180,
                      children: [
                        StatCard(
                          label: 'Por cotizar',
                          value: '${toQuote.length}',
                          emphasis: true,
                        ),
                        StatCard(label: 'En curso', value: '${active.length}'),
                        StatCard(
                          label: 'Finalizados',
                          value: '${finished.length}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const SectionTitle(
                        title: 'Te eligieron: envía tu cotización'),
                    if (toQuote.isEmpty)
                      const EmptyState(
                        icon: Icons.request_quote_outlined,
                        message:
                            'Cuando un cliente te seleccione aparecerá aquí para que le envíes la cotización formal.',
                      )
                    else
                      ResponsiveGrid(
                        minItemWidth: 300,
                        children: [
                          for (final a in toQuote)
                            _JobCard(
                              key: ValueKey('to-quote-${a.id}'),
                              eyebrow: 'Te eligieron',
                              highlight: true,
                              title: a.serviceRequest.category.label,
                              subtitle:
                                  '${a.serviceRequest.zone}, ${a.serviceRequest.city}'
                                  '${a.proposedPrice == null ? '' : ' · propusiste ${a.proposedPrice!.label}'}',
                              action: 'Cotizar',
                              onTap: () =>
                                  _open(() => widget.onOpenQuotation(a)),
                            ),
                        ],
                      ),
                    const SizedBox(height: 28),
                    const SectionTitle(title: 'Servicios contratados'),
                    if (contracts.isEmpty)
                      const EmptyState(
                        icon: Icons.work_outline_rounded,
                        message: 'Todavía no tienes servicios contratados.',
                      )
                    else ...[
                      if (active.isNotEmpty)
                        ResponsiveGrid(
                          minItemWidth: 300,
                          children: [for (final c in active) contractCard(c)],
                        ),
                      if (finished.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const SectionTitle(title: 'Finalizados'),
                        ResponsiveGrid(
                          minItemWidth: 300,
                          children: [for (final c in finished) contractCard(c)],
                        ),
                      ],
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      );
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onTap,
    this.highlight = false,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: FixiaPanel(
          highlight: highlight ? FixiaColors.secondary : null,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: highlight
                      ? FixiaColors.secondary
                      : const Color(0xFF00745F),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: FixiaColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: highlight
                    ? FilledButton(onPressed: onTap, child: Text(action))
                    : OutlinedButton(onPressed: onTap, child: Text(action)),
              ),
            ],
          ),
        ),
      );
}
