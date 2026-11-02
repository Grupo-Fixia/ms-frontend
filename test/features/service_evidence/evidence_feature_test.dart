import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/features/auth/login/domain/user_profile.dart';
import 'package:ms_frontend/features/contracts/application/ports/contract_repository.dart';
import 'package:ms_frontend/features/contracts/domain/service_contract.dart';
import 'package:ms_frontend/features/service_evidence/application/evidence_feature.dart';
import 'package:ms_frontend/features/service_evidence/application/ports/evidence_repository.dart';
import 'package:ms_frontend/features/service_evidence/domain/service_evidence.dart';

class Contracts implements ContractRepository {
  Contracts(this.status);
  final String? status;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  String? requested;
  ServiceContract get value => ServiceContract(
      id: 'c1',
      serviceRequestId: 'r1',
      quotationId: 'q1',
      clientId: 'client',
      providerId: 'tech',
      amountInCents: 10000,
      currency: 'COP',
      scope: 'Trabajo',
      conditions: 'Condiciones',
      agreedAt: DateTime(2026),
      contractedAt: DateTime(2026),
      request: const ContractedRequest(
          category: ServiceCategory.plumbing,
          description: 'Servicio',
          city: 'Bogotá',
          zone: 'Centro'),
      serviceStatus: ServiceRequestStatus.fromApi(status));
  @override
  Future<ServiceContract> getMine(String id) async {
    requested = id;
    return value;
  }

  @override
  Future<ServiceContract> getForRequest(String id) async {
    requested = id;
    return value;
  }

  @override
  Future<List<ServiceContract>> listMine() async => [value];
}

class Content implements EvidenceContentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserProfile profile(String id, UserRole role) => UserProfile(
    id: id,
    email: 'test@example.invalid',
    firstName: 'Test',
    lastName: 'User',
    role: role);
void main() {
  for (final state in <String?>[
    null,
    'CONTRACTED',
    'IN_PROGRESS',
    'TECHNICIAN_FINISHED',
    'CLOSED'
  ]) {
    test('permisos del técnico provienen del contrato en estado $state',
        () async {
      final contracts = Contracts(state);
      final feature = EvidenceFeature(
          contracts: contracts, repositoryFor: (_) => Content());
      final connection = await feature.connect(
          const EvidenceTarget.forContract('c1'),
          profile('tech', UserRole.professional));
      expect(contracts.requested, 'c1');
      expect(connection.access.serviceRequestId, 'r1');
      expect(connection.access.contractId, 'c1');
      expect(connection.access.canUpload,
          ['IN_PROGRESS', 'TECHNICIAN_FINISHED'].contains(state));
    });
  }
  test('el cliente abre su solicitud en solo lectura', () async {
    final feature = EvidenceFeature(
        contracts: Contracts('IN_PROGRESS'), repositoryFor: (_) => Content());
    final result = await feature.connect(const EvidenceTarget.forRequest('r1'),
        profile('client', UserRole.client));
    expect(result.access.canUpload, false);
    expect(result.access.actor, EvidenceActor.client);
  });
  test('no abre contratación de otra cuenta ni confunde solicitud con contrato',
      () async {
    final feature = EvidenceFeature(
        contracts: Contracts('IN_PROGRESS'), repositoryFor: (_) => Content());
    await expectLater(
        feature.connect(const EvidenceTarget.forContract('c1'),
            profile('other', UserRole.professional)),
        throwsA(isA<EvidenceFailure>()));
    await expectLater(
        feature.connect(const EvidenceTarget.forContract('r1'),
            profile('tech', UserRole.professional)),
        throwsA(isA<EvidenceFailure>()));
    await expectLater(
        feature.connect(const EvidenceTarget.forContract('c1'),
            profile('client', UserRole.client)),
        throwsA(isA<EvidenceFailure>()));
  });
}
