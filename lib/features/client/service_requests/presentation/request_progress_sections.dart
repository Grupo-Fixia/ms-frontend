import '../../../payments/domain/payments.dart';
import '../../../payments/presentation/commission_confirmation.dart';
import 'package:flutter/material.dart';

import '../../../chat_prototype/domain/service_chat.dart';

import '../../../../core/theme/fixia_theme.dart';
import '../../../../core/widgets/fixia_ui.dart';
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
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(title: widget.title),
          FutureBuilder<T>(
            future: _future,
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
              return widget.builder(context, snapshot.data as T, _reload);
            },
          ),
          const SizedBox(height: 20),
        ],
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
    this.previewBuilder,
    this.loadCommission,
  });

  final Future<List<Quotation>> Function() load;

  /// Lo que se muestra antes de aceptar la versión vigente (p. ej. el
  /// desglose con la comisión, GC-491).
  final Widget Function(Quotation current)? previewBuilder;
  final Future<CommissionQuote> Function(int, String)? loadCommission;
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
  bool _confirming = false;

  Future<void> _respond(
    Quotation quotation, {
    required bool accept,
    required VoidCallback reload,
  }) async {
    if (_busy) return;
    _confirming = true;
    setState(() => _busy = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => accept
          ? CommissionConfirmation(
              quotation: quotation, load: widget.loadCommission)
          : AlertDialog(
              title: const Text('Rechazar cotización'),
              content:
                  const Text('El prestador podrá enviarte una nueva versión.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Volver')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Rechazar')),
              ],
            ),
    );
    _confirming = false;
    if (!mounted) return;
    if (confirmed != true) {
      setState(() => _busy = false);
      return;
    }
    setState(() {});
    String message;
    try {
      if (accept) {
        final latest = splitVersions(await widget.load()).main;
        if (!mounted) return;
        if (latest == null ||
            !latest.isCurrent ||
            latest.id != quotation.id ||
            latest.amountInCents != quotation.amountInCents ||
            latest.currency != quotation.currency ||
            latest.revision != quotation.revision) {
          throw const PaymentsFailure(
              'La cotización cambió. Revisa la versión vigente y su desglose.');
        }
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
            return const EmptyState(
              message:
                  'Esperando la cotización formal del prestador seleccionado.',
              icon: Icons.hourglass_empty_rounded,
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
              else ...[
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
                            child: _busy && !_confirming
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
                if (main.isCurrent && widget.previewBuilder != null)
                  widget.previewBuilder!(main),
              ],
              if (versions.history.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Versiones anteriores',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: FixiaColors.primary,
                  ),
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
    this.walletPayments = false,
    this.footerBuilder,
  });

  final Future<ServiceContract> Function() load;
  final bool walletPayments;
  final Widget Function(ServiceContract)? footerBuilder;

  /// Acciones del cliente sobre el servicio (confirmar cierre u objetar).
  final List<Widget> Function(
          BuildContext context, ServiceContract contract, VoidCallback reload)?
      actionsBuilder;

  @override
  Widget build(BuildContext context) => ServerSection<ServiceContract>(
        title: 'Tu contratación',
        load: load,
        builder: (context, contract, reload) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ContractCard(
                contract: contract,
                walletPayments: walletPayments,
                chatAs: ChatParticipant.client,
                actions: actionsBuilder?.call(context, contract, reload) ??
                    const []),
            if (footerBuilder != null) ...[
              const SizedBox(height: 20),
              footerBuilder!(contract)
            ],
          ],
        ),
      );
}
