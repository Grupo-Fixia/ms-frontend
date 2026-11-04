import '../../../../core/constants/service_request_status.dart';
import '../../auth/login/domain/user_profile.dart';
import '../../contracts/application/ports/contract_repository.dart';
import '../../contracts/domain/contract_exceptions.dart';
import '../application/ports/evidence_repository.dart';
import '../domain/service_evidence.dart';

class EvidenceTarget {
  const EvidenceTarget.forContract(this.id)
      : actor = EvidenceActor.professional;
  const EvidenceTarget.forRequest(this.id) : actor = EvidenceActor.client;
  final String id;
  final EvidenceActor actor;
}

class EvidenceConnection {
  const EvidenceConnection(this.access, this.repository);
  final EvidenceAccess access;
  final EvidenceContentRepository repository;
}

class EvidenceFeature {
  const EvidenceFeature({required this.contracts, required this.repositoryFor});
  final ContractRepository contracts;
  final EvidenceContentRepository Function(EvidenceAccess access) repositoryFor;

  Future<EvidenceConnection> connect(
      EvidenceTarget target, UserProfile profile) async {
    final professional = target.actor == EvidenceActor.professional;
    if (target.id.trim().isEmpty ||
        profile.role?.name != (professional ? 'professional' : 'client')) {
      throw const EvidenceFailure('Tu cuenta no puede abrir estas evidencias.');
    }
    try {
      final contract = professional
          ? await contracts.getMine(target.id)
          : await contracts.getForRequest(target.id);
      if ((professional ? contract.providerId : contract.clientId) !=
              profile.id ||
          (professional ? contract.id : contract.serviceRequestId) !=
              target.id) {
        throw const EvidenceFailure(
            'La contratación no corresponde a tu cuenta.');
      }
      final access = EvidenceAccess(
          serviceRequestId: contract.serviceRequestId,
          contractId: contract.id,
          actor: target.actor,
          providerId: contract.providerId,
          canUpload: professional &&
              const [
                ServiceRequestStatus.inProgress,
                ServiceRequestStatus.technicianFinished
              ].contains(contract.serviceStatus));
      return EvidenceConnection(access, repositoryFor(access));
    } on ContractFailure catch (error) {
      throw EvidenceFailure(error.message,
          isSessionExpired: error.isSessionExpired);
    }
  }
}
