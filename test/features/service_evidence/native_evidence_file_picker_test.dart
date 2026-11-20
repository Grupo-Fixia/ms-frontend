import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/service_evidence/domain/service_evidence.dart';
import 'package:ms_frontend/features/service_evidence/infrastructure/evidence_file_picker_stub.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Selector de evidencias en la app Android (GC-550).
class _FakeFilePicker extends FilePicker with MockPlatformInterfaceMixin {
  _FakeFilePicker(this.result, {this.error});

  final FilePickerResult? result;
  final Object? error;
  List<String>? allowedExtensions;
  FileType? type;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    this.type = type;
    this.allowedExtensions = allowedExtensions;
    if (error != null) throw error!;
    return result;
  }
}

void main() {
  final policy = EvidenceFilePolicy.backend;

  test('solo ofrece los formatos que acepta el backend', () async {
    final fake = _FakeFilePicker(null);
    await NativeEvidenceFilePicker(picker: fake).pick(policy);
    expect(fake.type, FileType.custom);
    expect(fake.allowedExtensions, ['jpg', 'jpeg', 'png', 'webp', 'pdf']);
  });

  test('respeta una política más estrecha', () async {
    final fake = _FakeFilePicker(null);
    await NativeEvidenceFilePicker(picker: fake)
        .pick(EvidenceFilePolicy(mimeTypes: {'application/pdf'}, maxBytes: 10));
    expect(fake.allowedExtensions, ['pdf']);
  });

  test('cancelar devuelve null', () async {
    expect(
        await NativeEvidenceFilePicker(picker: _FakeFilePicker(null))
            .pick(policy),
        isNull);
  });

  test('una foto elegida se lee del disco con su tipo y tamaño', () async {
    final dir = await Directory.systemTemp.createTemp('evidencia');
    addTearDown(() => dir.delete(recursive: true));
    final photo = File('${dir.path}/fuga.JPG')..writeAsBytesSync([1, 2, 3, 4]);
    final picker = NativeEvidenceFilePicker(
      picker: _FakeFilePicker(FilePickerResult([
        PlatformFile(name: 'fuga.JPG', size: 4, path: photo.path),
      ])),
    );

    final file = (await picker.pick(policy))!;

    expect(file.name, 'fuga.JPG');
    expect(file.mimeType, 'image/jpeg');
    expect(file.size, 4);
    expect(await file.readBytes(), [1, 2, 3, 4]);
    expect(policy.validate(file), isNull);
  });

  test('usa los bytes en memoria si el sistema los entrega', () async {
    final picker = NativeEvidenceFilePicker(
      picker: _FakeFilePicker(FilePickerResult([
        PlatformFile(
            name: 'acta.pdf', size: 2, bytes: Uint8List.fromList([7, 8])),
      ])),
    );
    final file = (await picker.pick(policy))!;
    expect(file.mimeType, 'application/pdf');
    expect(await file.readBytes(), [7, 8]);
  });

  test('un formato desconocido lo rechaza la política', () async {
    final picker = NativeEvidenceFilePicker(
      picker: _FakeFilePicker(FilePickerResult([
        PlatformFile(name: 'video.mp4', size: 5, path: '/x/video.mp4'),
      ])),
    );
    final file = (await picker.pick(policy))!;
    expect(policy.validate(file), 'El formato del archivo no está permitido.');
  });

  test('sin ruta ni bytes no se puede leer', () async {
    final picker = NativeEvidenceFilePicker(
      picker: _FakeFilePicker(FilePickerResult([
        PlatformFile(name: 'a.png', size: 5),
      ])),
    );
    final file = (await picker.pick(policy))!;
    expect(file.readBytes, throwsA(isA<EvidenceFailure>()));
  });

  test('si el selector falla, un mensaje claro', () {
    final picker = NativeEvidenceFilePicker(
        picker: _FakeFilePicker(null, error: Exception('sin permiso')));
    expect(
      () => picker.pick(policy),
      throwsA(isA<EvidenceFailure>().having((e) => e.message, 'message',
          'No pudimos abrir el selector de archivos.')),
    );
  });
}
