import '../../domain/service_evidence.dart';

/// El adaptador debe autorizar cada operación y confirmar objeto + metadatos.
/// Las firmas Dart no son un contrato HTTP ni deciden multipart/URL temporal.
abstract interface class EvidenceRepository {
  Future<List<ServiceEvidence>> list(String serviceId);
  Future<ServiceEvidence> upload(String serviceId, EvidenceFile file);
}

abstract interface class EvidenceFilePicker {
  Future<EvidenceFile?> pick(EvidenceFilePolicy policy);
}

abstract interface class EvidenceContentRepository
    implements EvidenceRepository {
  Future<EvidenceDownload> download(ServiceEvidence evidence);
}
