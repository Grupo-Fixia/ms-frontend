import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/features/service_evidence/domain/service_evidence.dart';
import 'package:ms_frontend/features/service_evidence/infrastructure/http_evidence_repository.dart';

final bytes = Uint8List.fromList([37, 80, 68, 70]);
final file = EvidenceFile(
    name: 'informe.pdf',
    mimeType: 'application/pdf',
    size: 4,
    readBytes: () async => bytes);
Map<String, Object?> metadata() => {
      'id': 'e1',
      'serviceRequestId': 'r1',
      'contractId': 'c1',
      'uploadedBy': 'p1',
      'contentType': 'application/pdf',
      'sizeBytes': 4,
      'sha256': List.filled(64, 'a').join(),
      'createdAt': '2026-11-02T12:00:00Z'
    };
http.Response response(int code, Object body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), code);
HttpEvidenceRepository repo(MockClientHandler handler,
        {EvidenceActor actor = EvidenceActor.professional,
        bool canUpload = true,
        AuthorizedHttp? auth}) =>
    HttpEvidenceRepository(
        client: MockClient(handler),
        baseUrl: Uri.parse('http://localhost'),
        authorizedHttp: auth ??
            AuthorizedHttp(
                accessToken: () => 'test', renewSession: () async => false),
        access: EvidenceAccess(
            serviceRequestId: 'r1',
            contractId: 'c1',
            actor: actor,
            canUpload: canUpload,
            providerId: 'p1'));

void main() {
  test('multipart file autenticado y confirmación por listado real', () async {
    final calls = <String>[];
    final saved = await repo((req) async {
      calls.add(req.method);
      expect(req.url.path, '/api/services/contracts/c1/evidences');
      expect(req.headers['Authorization'], 'Bearer test');
      if (req.method == 'POST') {
        expect(req.headers['content-type'],
            startsWith('multipart/form-data; boundary='));
        expect(req.body, contains('name="file"; filename="informe.pdf"'));
        expect(
            req.body.toLowerCase(), contains('content-type: application/pdf'));
        expect(req.body, contains('%PDF'));
        expect(req.body, isNot(contains('name="uploadedBy"')));
        return response(201, metadata());
      }
      return response(200, [metadata()]);
    }).upload('r1', file);
    expect(calls, ['POST', 'GET']);
    expect(saved.serviceId, 'r1');
    expect(saved.contractId, 'c1');
  });
  test('cliente consulta y descarga por solicitud con autorización', () async {
    final repository = repo((req) async {
      expect(req.headers['Authorization'], 'Bearer test');
      if (req.url.path.endsWith('/content')) {
        expect(req.url.path, '/api/services/requests/r1/evidences/e1/content');
        return http.Response.bytes(bytes, 200, headers: {
          'content-type': 'application/pdf',
          'content-disposition': 'attachment; filename="e1.pdf"'
        });
      }
      expect(req.url.path, '/api/services/requests/r1/evidences');
      return response(200, [metadata()]);
    }, actor: EvidenceActor.client, canUpload: false);
    final evidence = (await repository.list('r1')).single;
    expect((await repository.download(evidence)).bytes, bytes);
    await expectLater(
        repository.upload('r1', file), throwsA(isA<EvidenceFailure>()));
  });
  test('la ruta de técnico descarga por contrato, nunca por ID de solicitud',
      () async {
    final repository = repo((req) async => req.url.path.endsWith('/content')
        ? http.Response.bytes(bytes, 200,
            headers: {'content-type': 'application/pdf'})
        : response(200, [metadata()]));
    final item = (await repository.list('r1')).single;
    expect((await repository.download(item)).fileName, 'e1.pdf');
  });
  test('formatos y límites reales se validan antes de leer y enviar', () async {
    var calls = 0;
    var reads = 0;
    final repository = repo((_) async {
      calls++;
      return response(500, {});
    });
    for (final invalid in [
      (0, 'application/pdf'),
      (10 * 1024 * 1024 + 1, 'application/pdf'),
      (4, 'text/plain')
    ]) {
      await expectLater(
          repository.upload(
              'r1',
              EvidenceFile(
                  name: 'x',
                  mimeType: invalid.$2,
                  size: invalid.$1,
                  readBytes: () async {
                    reads++;
                    return bytes;
                  })),
          throwsA(isA<EvidenceFailure>()));
    }
    expect(reads, 0);
    expect(calls, 0);
    expect(EvidenceFilePolicy.backend.maxBytes, 10485760);
    expect(EvidenceFilePolicy.backend.mimeTypes,
        {'image/jpeg', 'image/png', 'image/webp', 'application/pdf'});
    expect(
        EvidenceFilePolicy.backend.validate(EvidenceFile(
            name: 'x',
            mimeType: 'image/png',
            size: 10485760,
            readBytes: () async => bytes)),
        isNull);
  });
  test('estado de solo consulta y servicio ajeno no hacen peticiones de carga',
      () async {
    var calls = 0;
    final repository = repo((_) async {
      calls++;
      return response(500, {});
    }, canUpload: false);
    await expectLater(
        repository.upload('r1', file), throwsA(isA<EvidenceFailure>()));
    await expectLater(
        repository.list('other'), throwsA(isA<EvidenceFailure>()));
    expect(calls, 0);
  });
  test('lectura incompleta no se envía', () async {
    var calls = 0;
    await expectLater(
        repo((_) async {
          calls++;
          return response(500, {});
        }).upload(
            'r1',
            EvidenceFile(
                name: 'x.pdf',
                mimeType: 'application/pdf',
                size: 5,
                readBytes: () async => bytes)),
        throwsA(isA<EvidenceFailure>()));
    expect(calls, 0);
  });
  for (final status in [400, 403, 404, 409, 413]) {
    test('carga $status no confirma éxito ni reintenta', () async {
      var calls = 0;
      await expectLater(
          repo((_) async {
            calls++;
            return response(status, {'detail': 'Rechazo de prueba'});
          }).upload('r1', file),
          throwsA(isA<EvidenceFailure>()));
      expect(calls, 1);
    });
  }
  test('401 vencido y red se distinguen de una carga confirmada', () async {
    await expectLater(
        repo((_) async => response(401, {})).upload('r1', file),
        throwsA(isA<EvidenceFailure>()
            .having((e) => e.isSessionExpired, 'sesión', true)));
    var calls = 0;
    await expectLater(
        repo((_) async {
          calls++;
          throw http.ClientException('offline');
        }).upload('r1', file),
        throwsA(isA<EvidenceFailure>()
            .having((e) => e.submissionUncertain, 'incierto', true)));
    expect(calls, 1);
  });
  test('renovación 401 reconstruye multipart sin reutilizar stream consumido',
      () async {
    var token = 'old';
    var renewals = 0;
    final bodies = <String>[];
    final auth = AuthorizedHttp(
        accessToken: () => token,
        renewSession: () async {
          renewals++;
          token = 'new';
          return true;
        });
    await repo((req) async {
      if (req.method == 'GET') return response(200, [metadata()]);
      bodies.add(req.body);
      return req.headers['Authorization'] == 'Bearer old'
          ? response(401, {})
          : response(201, metadata());
    }, auth: auth)
        .upload('r1', file);
    expect(renewals, 1);
    expect(bodies.length, 2);
    expect(
        bodies.every(
            (body) => body.contains('%PDF') && body.contains('name="file"')),
        isTrue);
  });
  test('201 inconsistente o sin confirmación no se anuncia como guardado',
      () async {
    for (final changed in [
      'serviceRequestId',
      'contractId',
      'uploadedBy',
      'sizeBytes',
      'sha256'
    ]) {
      final item = metadata()..[changed] = changed == 'sizeBytes' ? 5 : 'other';
      await expectLater(
          repo((_) async => response(201, item)).upload('r1', file),
          throwsA(isA<EvidenceFailure>()
              .having((e) => e.submissionUncertain, 'incierto', true)));
    }
    await expectLater(
        repo((req) async => req.method == 'POST'
            ? response(201, metadata())
            : response(200, [])).upload('r1', file),
        throwsA(isA<EvidenceFailure>()
            .having((e) => e.submissionUncertain, 'incierto', true)));
  });
  test('listado rechaza duplicados, metadatos ajenos y exceso de evidencias',
      () async {
    for (final body in [
      [metadata(), metadata()],
      [metadata()..['contractId'] = 'other'],
      [for (var i = 0; i < 11; i++) metadata()..['id'] = 'e$i']
    ]) {
      await expectLater(repo((_) async => response(200, body)).list('r1'),
          throwsA(isA<EvidenceFailure>()));
    }
  });
  test('descarga rechaza MIME, tamaño o contenido de error inconsistentes',
      () async {
    for (final mode in ['type', 'size', 'error']) {
      final repository = repo((req) async {
        if (!req.url.path.endsWith('/content')) {
          return response(200, [metadata()]);
        }
        return mode == 'error'
            ? response(403, {})
            : http.Response.bytes(
                mode == 'size' ? Uint8List(1) : bytes, 200, headers: {
                'content-type': mode == 'type' ? 'text/html' : 'application/pdf'
              });
      });
      final item = (await repository.list('r1')).single;
      await expectLater(
          repository.download(item), throwsA(isA<EvidenceFailure>()));
    }
  });
}
