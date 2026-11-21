import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';

import '../application/ports/evidence_repository.dart';
import '../domain/service_evidence.dart';

/// Fuera del navegador (app Android, GC-550) usa el selector nativo del
/// sistema. Solo ofrece los formatos que acepta el backend.
EvidenceFilePicker browserEvidenceFilePicker() => NativeEvidenceFilePicker();

/// Tipo MIME por extensión, para los formatos de evidencia.
const evidenceMimeByExtension = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'pdf': 'application/pdf',
};

class NativeEvidenceFilePicker implements EvidenceFilePicker {
  NativeEvidenceFilePicker({FilePicker? picker}) : _picker = picker;

  final FilePicker? _picker;

  @override
  Future<EvidenceFile?> pick(EvidenceFilePolicy policy) async {
    final extensions = [
      for (final entry in evidenceMimeByExtension.entries)
        if (policy.mimeTypes.contains(entry.value)) entry.key,
    ];
    final FilePickerResult? result;
    try {
      result = await (_picker ?? FilePicker.platform).pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
      );
    } catch (_) {
      throw const EvidenceFailure('No pudimos abrir el selector de archivos.');
    }
    final file = result?.files.singleOrNull;
    if (file == null) return null;
    final path = file.path;
    final extension = (file.extension ?? '').toLowerCase();
    return EvidenceFile(
      name: file.name,
      // Un formato desconocido llega vacío y la política lo rechaza.
      mimeType: evidenceMimeByExtension[extension] ?? '',
      size: file.size,
      readBytes: () async {
        if (file.bytes != null) return file.bytes!;
        if (path == null) {
          throw const EvidenceFailure('No pudimos leer el archivo elegido.');
        }
        return File(path).readAsBytes();
      },
    );
  }
}
