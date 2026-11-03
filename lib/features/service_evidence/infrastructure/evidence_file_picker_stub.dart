import '../application/ports/evidence_repository.dart';
import '../domain/service_evidence.dart';

EvidenceFilePicker browserEvidenceFilePicker() => _UnsupportedPicker();

class _UnsupportedPicker implements EvidenceFilePicker {
  @override
  Future<EvidenceFile?> pick(EvidenceFilePolicy policy) async {
    throw const EvidenceFailure(
        'La selección de archivos requiere el navegador.');
  }
}
