import 'package:flutter/material.dart';

import '../../../../core/theme/fixia_theme.dart';
import '../../../contracts/domain/service_contract.dart';
import '../../../contracts/presentation/contract_card.dart';
import '../../../quotations/domain/quotation.dart';
import '../../../quotations/presentation/quotation_card.dart';

/// Carga un dato del servidor y muestra carga, error con reintento o el
/// contenido. Nunca muestra un valor de ejemplo mientras espera.
class ServerSection<T> extends StatefulWidget {
  const ServerSection({
    super.key,
    required this.title,
    required this.load,
    required this.builder,
  });

  final String title;
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, VoidCallback reload)
      builder;

  @override
  State<ServerSection<T>> createState() => _ServerSectionState<T>();
}

class _ServerSectionState<T> extends State<ServerSection<T>> {
  late Future<T> _future = widget.load();

  void _reload() => setState(() {
        _future = widget.load();
      });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: FixiaColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<T>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Column(
                    children: [
                      Text('${snapshot.error}', textAlign: TextAlign.center),
                      TextButton(
                        onPressed: _reload,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  );
                }
                return widget.builder(context, snapshot.data as T, _reload);
              },
            ),
          ],
        ),
      );
}

/// Cotizaciones que recibió el cliente del prestador seleccionado (GC-428):
/// la versión vigente con aceptar y rechazar (GC-429) y las anteriores como
/// historial. Lo que se ve después de responder lo devuelve el servidor.
class ClientQuotationSection extends StatefulWidget {
  const ClientQuotationSection({
    super.key,
    required this.load,
    required this.accept,
    required this.reject,
    required this.onChanged,
  });

  final Future<List<Quotation>> Function() load;
  final Future<Quotation> Function(String quotationId) accept;
  final Future<Quotation> Function(String quotationId) reject;

  /// Avisa a la pantalla para que vuelva a consultar la solicitud (al
  /// aceptar queda contratada).
  final Future<void> Function() onChanged;

  @override
  State<ClientQuotationSection> createState() => _ClientQuotationSectionState();
}

class _ClientQuotationSectionState extends State<ClientQuotationSection> {
  bool _busy = false;

  Future<void> _respond(
    Quotation quotation, {
    required bool accept,
    required VoidCallback reload,
  }) async {
    if (_busy) return;
    final amount = formatCents(quotation.amountInCents, quotation.currency);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(accept ? 'Aceptar cotización' : 'Rechazar cotización'),
        content: Text(accept
            ? 'Vas a contratar el servicio por $amount con las condiciones de la '
                '${quotation.versionLabel.toLowerCase()}. Esta decisión queda registrada.'
            : 'El prestador podrá enviarte una nueva versión.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(accept ? 'Aceptar y contratar' : 'Rechazar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    String message;
    try {
      if (accept) {
        await widget.accept(quotation.id);
        message = 'Cotización aceptada. El servicio quedó contratado.';
      } else {
        await widget.reject(quotation.id);
        message = 'Rechazaste la cotización.';
      }
    } catch (error) {
      message = '$error';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    reload();
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) => ServerSection<List<Quotation>>(
        title: 'Cotización del prestador',
        load: widget.load,
        builder: (context, quotations, reload) {
          if (quotations.isEmpty) {
            return const Text(
              'Esperando la cotización formal del prestador seleccionado.',
              style: TextStyle(color: FixiaColors.textSecondary),
            );
          }
          final versions = splitVersions(quotations);
          final main = versions.main;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (main == null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'No hay una versión vigente. El prestador puede enviarte una nueva.',
                    style: TextStyle(color: FixiaColors.textSecondary),
                  ),
                )
              else
                QuotationCard(
                  quotation: main,
                  actions: main.isCurrent
                      ? [
                          OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _respond(main,
                                    accept: false, reload: reload),
                            child: const Text('Rechazar'),
                          ),
                          FilledButton(
                            onPressed: _busy
                                ? null
                                : () => _respond(main,
                                    accept: true, reload: reload),
                            child: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text('Aceptar'),
                          ),
                        ]
                      : const [],
                ),
              if (versions.history.isNotEmpty) ...[
                const Text(
                  'Versiones anteriores',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                for (final q in versions.history)
                  QuotationCard(quotation: q, compact: true),
              ],
            ],
          );
        },
      );
}

/// Contratación de la solicitud del cliente (GC-429), consultada al
/// servidor cada vez que se abre.
class ClientContractSection extends StatelessWidget {
  const ClientContractSection({
    super.key,
    required this.load,
    this.actionsBuilder,
  });

  final Future<ServiceContract> Function() load;

  /// Acciones del cliente sobre el servicio (confirmar cierre u objetar).
  final List<Widget> Function(
          BuildContext context, ServiceContract contract, VoidCallback reload)?
      actionsBuilder;

  @override
  Widget build(BuildContext context) => ServerSection<ServiceContract>(
        title: 'Tu contratación',
        load: load,
        builder: (context, contract, reload) => ContractCard(
          contract: contract,
          actions: actionsBuilder?.call(context, contract, reload) ?? const [],
        ),
      );
}
