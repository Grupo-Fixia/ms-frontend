import 'dart:typed_data';

/// Archivo local, todavía no cargado ni registrado como evidencia.
class EvidenceFile {
  const EvidenceFile({
    required this.name,
    required this.mimeType,
    required this.size,
    required this.readBytes,
  });
  final String name;
  final String mimeType;
  final int size;
  final Future<Uint8List> Function() readBytes;
}

/// Política recibida del contrato acordado; no establece límites de producto.
class EvidenceFilePolicy {
  static final backend = EvidenceFilePolicy(
      mimeTypes: {'image/jpeg', 'image/png', 'image/webp', 'application/pdf'},
      maxBytes: 10 * 1024 * 1024);
  static const maxEvidences = 10;
  EvidenceFilePolicy({required Set<String> mimeTypes, required this.maxBytes})
      : mimeTypes = Set.unmodifiable(mimeTypes) {
    if (mimeTypes.isEmpty || maxBytes <= 0) {
      throw ArgumentError('Se requiere una política de archivos válida.');
    }
  }
  final Set<String> mimeTypes;
  final int maxBytes;

  String? validate(EvidenceFile file) {
    if (file.size <= 0) return 'El archivo está vacío.';
    if (file.size > maxBytes) return 'El archivo supera el tamaño permitido.';
    if (!mimeTypes.contains(file.mimeType.toLowerCase())) {
      return 'El formato del archivo no está permitido.';
    }
    return null;
  }
}

/// Solo representa metadatos confirmados por el servidor. No guarda URL pública.
class ServiceEvidence {
  const ServiceEvidence({
    required this.id,
    required this.serviceId,
    required this.fileName,
    required this.author,
    required this.createdAt,
    this.contractId,
    this.contentType,
    this.sizeBytes,
    this.sha256,
  });
  final String id;
  final String serviceId;
  final String fileName;
  final String author;
  final DateTime createdAt;
  final String? contractId;
  final String? contentType;
  final int? sizeBytes;
  final String? sha256;
}

enum EvidenceActor { client, professional }

class EvidenceAccess {
  const EvidenceAccess(
      {required this.serviceRequestId,
      required this.contractId,
      required this.actor,
      required this.canUpload,
      this.providerId});
  final String serviceRequestId;
  final String contractId;
  final EvidenceActor actor;
  final bool canUpload;
  final String? providerId;
}

class EvidenceDownload {
  const EvidenceDownload(
      {required this.bytes, required this.mimeType, required this.fileName});
  final Uint8List bytes;
  final String mimeType;
  final String fileName;
}

class EvidenceFailure implements Exception {
  const EvidenceFailure(this.message,
      {this.isSessionExpired = false, this.submissionUncertain = false});
  final String message;
  final bool isSessionExpired;
  final bool submissionUncertain;
  @override
  String toString() => message;
}
