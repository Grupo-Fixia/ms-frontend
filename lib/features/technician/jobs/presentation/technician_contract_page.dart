import 'package:flutter/material.dart';

import '../../../../core/theme/fixia_theme.dart';
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
  });

  final Future<ServiceContract> Function() load;
  final List<Widget> Function(
          BuildContext context, ServiceContract contract, VoidCallback reload)?
      actionsBuilder;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: FixiaColors.neutralBackground,
        appBar: AppBar(title: const Text('Servicio contratado')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            ServerSection<ServiceContract>(
              title: 'Contratación',
              load: load,
              builder: (context, contract, reload) => ContractCard(
                contract: contract,
                actions:
                    actionsBuilder?.call(context, contract, reload) ?? const [],
              ),
            ),
          ],
        ),
      );
}
