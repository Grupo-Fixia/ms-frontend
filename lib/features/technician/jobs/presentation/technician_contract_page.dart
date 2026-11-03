import 'package:flutter/material.dart';

import '../../../../core/layout/app_shell.dart';
import '../../../../core/widgets/fixia_ui.dart';
import '../../../client/service_requests/presentation/request_progress_sections.dart';
import '../../../contracts/domain/service_contract.dart';
import '../../../contracts/presentation/contract_card.dart';

/// Contratación vista por el técnico (GC-429): lo acordado y la dirección
/// exacta del servicio, consultadas en ms-services. [actionsBuilder] agrega
/// las acciones del técnico según el estado (iniciar, finalizar).
class TechnicianContractPage extends StatelessWidget {
  const TechnicianContractPage({
    super.key,
    required this.load,
    this.actionsBuilder,
    this.footer,
    this.walletPayments = false,
  });

  /// Debajo de la contratación (p. ej. el estado del pago).
  final Widget? footer;
  final bool walletPayments;

  final Future<ServiceContract> Function() load;
  final List<Widget> Function(
          BuildContext context, ServiceContract contract, VoidCallback reload)?
      actionsBuilder;

  @override
  Widget build(BuildContext context) => AppShell(
        destination: ShellDestination.technicianJobs,
        subpage: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BackLink(label: 'Mis trabajos'),
            const PageHeader(
              title: 'Servicio contratado',
              subtitle:
                  'Lo acordado con el cliente, la dirección del servicio y su avance.',
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: ServerSection<ServiceContract>(
                  title: 'Contratación',
                  load: load,
                  builder: (context, contract, reload) => ContractCard(
                    contract: contract,
                    walletPayments: walletPayments,
                    actions: actionsBuilder?.call(context, contract, reload) ??
                        const [],
                  ),
                ),
              ),
            ),
            if (footer != null)
              Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: footer,
                ),
              ),
          ],
        ),
      );
}
