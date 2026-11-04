import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/features/contracts/application/contract_use_cases.dart';
import 'package:ms_frontend/features/contracts/application/ports/contract_repository.dart';
import 'package:ms_frontend/features/contracts/domain/contract_exceptions.dart';
import 'package:ms_frontend/features/contracts/domain/service_contract.dart';

final _contract = ServiceContract(
  id: 'c-1',
  serviceRequestId: 'req-1',
  quotationId: 'q-1',
  clientId: 'cli-1',
  providerId: 'tec-1',
  amountInCents: 100,
  currency: 'COP',
  scope: 's',
  conditions: 'c',
  agreedAt: DateTime.utc(2026, 10, 25),
  contractedAt: DateTime.utc(2026, 10, 22),
  request: const ContractedRequest(
    category: ServiceCategory.plumbing,
    description: 'd',
    city: 'Bogotá',
    zone: 'Chapinero',
  ),
);

class _Repository implements ContractRepository {
  final calls = <String>[];

  @override
  Future<ServiceContract> getForRequest(String serviceRequestId) async {
    calls.add('request $serviceRequestId');
    return _contract;
  }

  @override
  Future<ServiceContract> getMine(String id) async {
    calls.add('mine $id');
    return _contract;
  }

  @override
  Future<List<ServiceContract>> listMine() async {
    calls.add('list');
    return [_contract];
  }

  @override
  Future<ServiceContract> start(String contractId) async {
    calls.add('start $contractId');
    return _contract;
  }

  @override
  Future<ServiceContract> finish(String contractId) async {
    calls.add('finish $contractId');
    return _contract;
  }

  @override
  Future<ServiceContract> confirmClosure(String serviceRequestId) async {
    calls.add('closure $serviceRequestId');
    return _contract;
  }

  @override
  Future<ServiceContract> objectClosure(
      String serviceRequestId, String reason) async {
    calls.add('objection $serviceRequestId $reason');
    return _contract;
  }
}

void main() {
  test('consulta la contratación de una solicitud con el id limpio', () async {
    final repository = _Repository();

    final contract = await GetRequestContract(repository)(' req-1 ');

    expect(repository.calls, ['request req-1']);
    expect(contract.id, 'c-1');
  });

  test('el prestador lista y consulta sus contrataciones', () async {
    final repository = _Repository();

    expect(await ListMyContracts(repository)(), [_contract]);
    await GetMyContract(repository)(' c-1 ');

    expect(repository.calls, ['list', 'mine c-1']);
  });

  test('sin id no consulta el backend', () async {
    final repository = _Repository();

    await expectLater(
      GetRequestContract(repository)(' '),
      throwsA(isA<ContractFailure>().having((f) => f.message, 'message',
          GetRequestContract.missingRequestMessage)),
    );
    await expectLater(
      GetMyContract(repository)(''),
      throwsA(isA<ContractFailure>().having(
          (f) => f.message, 'message', GetMyContract.missingContractMessage)),
    );
    expect(repository.calls, isEmpty);
  });

  test('ciclo del servicio: iniciar, finalizar, cerrar y objetar', () async {
    final repository = _Repository();
    await StartService(repository)(' c-1 ');
    await FinishService(repository)('c-1');
    await ConfirmServiceClosure(repository)('req-1');
    await ObjectServiceClosure(repository)('req-1', '  Sigue goteando ');
    expect(repository.calls, [
      'start c-1',
      'finish c-1',
      'closure req-1',
      'objection req-1 Sigue goteando',
    ]);
  });

  test('objetar exige un motivo de máximo 500 caracteres', () async {
    final repository = _Repository();
    expect(
      () => ObjectServiceClosure(repository)('req-1', '   '),
      throwsA(isA<ContractFailure>().having((f) => f.message, 'message',
          ObjectServiceClosure.missingReasonMessage)),
    );
    expect(
      () => ObjectServiceClosure(repository)('req-1', 'x' * 501),
      throwsA(isA<ContractFailure>().having(
          (f) => f.message, 'message', ObjectServiceClosure.tooLongMessage)),
    );
    expect(
        () => FinishService(repository)(' '), throwsA(isA<ContractFailure>()));
    expect(repository.calls, isEmpty);
  });
}
