import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../application/ports/evidence_repository.dart';
import '../domain/service_evidence.dart';

EvidenceFilePicker browserEvidenceFilePicker() => _BrowserPicker();

class _BrowserPicker implements EvidenceFilePicker {
  @override
  Future<EvidenceFile?> pick(EvidenceFilePolicy policy) async {
    final input = web.HTMLInputElement()
      ..type = 'file'
      ..accept = policy.mimeTypes.join(',')
      ..multiple = false;
    final result = Completer<EvidenceFile?>();
    final change =
        web.EventStreamProviders.changeEvent.forTarget(input).listen((_) {
      final files = input.files;
      final file = files != null && files.length > 0 ? files.item(0) : null;
      if (!result.isCompleted) {
        result.complete(file == null
            ? null
            : EvidenceFile(
                name: file.name,
                mimeType: file.type,
                size: file.size,
                readBytes: () async =>
                    (await file.arrayBuffer().toDart).toDart.asUint8List(),
              ));
      }
    });
    final cancel =
        web.EventStreamProviders.cancelEvent.forTarget(input).listen((_) {
      if (!result.isCompleted) result.complete(null);
    });
    try {
      input.click();
      return await result.future;
    } finally {
      await change.cancel();
      await cancel.cancel();
      input.remove();
    }
  }
}
