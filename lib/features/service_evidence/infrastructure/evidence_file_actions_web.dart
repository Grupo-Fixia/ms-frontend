import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../domain/service_evidence.dart';

Future<void> saveEvidenceFile(EvidenceDownload file) async {
  final blob = web.Blob(
      [file.bytes.toJS].toJS, web.BlobPropertyBag(type: file.mimeType));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = file.fileName;
  web.document.body?.appendChild(anchor);
  try {
    anchor.click();
  } finally {
    anchor.remove();
    Timer(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
  }
}
