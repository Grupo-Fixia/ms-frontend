import 'package:flutter/material.dart';

import '../../../../core/theme/fixia_theme.dart';
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
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: FixiaColors.neutralBackground,
        appBar: AppBar(
          title: const Text('Mis trabajos'),
          actions: [
            IconButton(
              tooltip: 'Actualizar trabajos',
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: FutureBuilder<(List<ServiceApplication>, List<ServiceContract>)>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    TextButton(
                      onPressed: _reload,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }
            final (applications, contracts) = snapshot.data!;
            final contracted = {for (final c in contracts) c.serviceRequestId};
            final toQuote = [
              for (final a in applications)
                if (a.status == ApplicationStatus.selected &&
                    !contracted.contains(a.serviceRequest.id))
                  a,
            ];
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const _Title('Te eligieron: envía tu cotización'),
                if (toQuote.isEmpty)
                  const _Empty(
                      'Cuando un cliente te seleccione aparecerá aquí para que le envíes la cotización formal.')
                else
                  for (final a in toQuote)
                    _JobTile(
                      key: ValueKey('to-quote-${a.id}'),
                      title: a.serviceRequest.category.label,
                      subtitle:
                          '${a.serviceRequest.zone}, ${a.serviceRequest.city}'
                          '${a.proposedPrice == null ? '' : ' · propusiste ${a.proposedPrice!.label}'}',
                      trailing: 'Cotizar',
                      onTap: () => _open(() => widget.onOpenQuotation(a)),
                    ),
                const SizedBox(height: 16),
                const _Title('Servicios contratados'),
                if (contracts.isEmpty)
                  const _Empty('Todavía no tienes servicios contratados.')
                else
                  for (final c in contracts)
                    _JobTile(
                      key: ValueKey('contract-${c.id}'),
                      title:
                          '${c.request.category.label} · ${formatCents(c.amountInCents, c.currency)}',
                      subtitle:
                          '${c.serviceStatus?.label ?? 'Contratado'} · ${formatDateTime(c.agreedAt)}',
                      trailing: 'Ver',
                      onTap: () => _open(() => widget.onOpenContract(c)),
                    ),
                if (widget.onOpenOpportunities != null) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: widget.onOpenOpportunities,
                    icon: const Icon(Icons.search),
                    label: const Text('Buscar oportunidades'),
                  ),
                ],
              ],
            );
          },
        ),
      );
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: FixiaColors.primary,
          ),
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(color: FixiaColors.textSecondary),
      );
}

class _JobTile extends StatelessWidget {
  const _JobTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        color: FixiaColors.white,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FixiaRadii.card),
        ),
        child: ListTile(
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle),
          trailing: Text(
            trailing,
            style: const TextStyle(
              color: FixiaColors.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          onTap: onTap,
        ),
      );
}
