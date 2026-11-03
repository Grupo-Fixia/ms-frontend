import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/service_evidence/application/ports/evidence_repository.dart';
import 'package:ms_frontend/features/service_evidence/domain/service_evidence.dart';
import 'package:ms_frontend/features/service_evidence/presentation/service_evidence_page.dart';

final policy = EvidenceFilePolicy(mimeTypes: {'application/pdf'}, maxBytes: 20);
final file = EvidenceFile(
    name: 'informe.pdf',
    mimeType: 'application/pdf',
    size: 4,
    readBytes: () async => Uint8List.fromList([37, 80, 68, 70]));
ServiceEvidence evidence([String service = 's1']) => ServiceEvidence(
    id: 'e1',
    serviceId: service,
    fileName: 'informe.pdf',
    author: 'Técnico',
    createdAt: DateTime.utc(2026, 10, 25));

class Picker implements EvidenceFilePicker {
  EvidenceFile? next = file;
  @override
  Future<EvidenceFile?> pick(EvidenceFilePolicy policy) async => next;
}

class Repository implements EvidenceRepository {
  List<ServiceEvidence> items = [];
  Object? loadError;
  Object? uploadError;
  Completer<ServiceEvidence>? pending;
  int uploads = 0;
  int reads = 0;
  @override
  Future<List<ServiceEvidence>> list(String serviceId) async {
    reads++;
    if (loadError != null) throw loadError!;
    return items;
  }

  @override
  Future<ServiceEvidence> upload(String serviceId, EvidenceFile file) async {
    uploads++;
    if (uploadError != null) throw uploadError!;
    final result =
        pending != null ? await pending!.future : evidence(serviceId);
    items = [result];
    return result;
  }
}

Future<void> show(WidgetTester tester, Repository repository, Picker picker,
        {bool canUpload = true,
        String service = 's1',
        Future<void> Function(ServiceEvidence)? open}) =>
    tester.pumpWidget(MaterialApp(
      home: ServiceEvidencePage(
        serviceId: service,
        canUpload: canUpload,
        repository: repository,
        picker: picker,
        policy: policy,
        openEvidence: open ?? (_) async {},
      ),
    ));
Future<void> pick(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('evidence-pick')));
  await tester.pumpAndSettle();
}

Future<void> upload(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('evidence-upload')));
  await tester.pump();
}

void main() {
  test('política exige tamaño válido y MIME explícito sin cargar bytes', () {
    expect(policy.validate(file), isNull);
    EvidenceFile invalid(int size, String mime) => EvidenceFile(
        name: 'x',
        mimeType: mime,
        size: size,
        readBytes: () => throw StateError('No leer antes de validar'));
    expect(policy.validate(invalid(0, 'application/pdf')), isNotNull);
    expect(policy.validate(invalid(21, 'application/pdf')), isNotNull);
    expect(policy.validate(invalid(4, 'image/png')), isNotNull);
    expect(() => EvidenceFilePolicy(mimeTypes: {}, maxBytes: 1),
        throwsArgumentError);
  });

  testWidgets('selección local no aparece como evidencia guardada',
      (tester) async {
    final repository = Repository();
    await show(tester, repository, Picker());
    await tester.pumpAndSettle();
    await pick(tester);
    expect(find.text('Archivo local, pendiente de cargar.'), findsOneWidget);
    expect(find.text('Todavía no hay evidencias registradas.'), findsOneWidget);
    expect(repository.uploads, 0);
    await tester.tap(find.byKey(const ValueKey('evidence-remove')));
    await tester.pump();
    expect(find.byKey(const ValueKey('evidence-selected')), findsNothing);
  });

  testWidgets('cancelar selector no carga ni confirma archivos',
      (tester) async {
    final repository = Repository();
    await show(tester, repository, Picker()..next = null);
    await tester.pumpAndSettle();
    await pick(tester);
    expect(find.byKey(const ValueKey('evidence-upload')), findsNothing);
    expect(repository.uploads, 0);
  });

  testWidgets('formato no permitido impide seleccionar y cargar',
      (tester) async {
    final repository = Repository();
    await show(
        tester,
        repository,
        Picker()
          ..next = EvidenceFile(
              name: 'x.exe',
              mimeType: 'application/octet-stream',
              size: 1,
              readBytes: () async => Uint8List(1)));
    await tester.pumpAndSettle();
    await pick(tester);
    expect(
        find.text('El formato del archivo no está permitido.'), findsOneWidget);
    expect(find.byKey(const ValueKey('evidence-upload')), findsNothing);
  });

  testWidgets('espera confirmación, evita doble envío y recarga',
      (tester) async {
    final repository = Repository()..pending = Completer<ServiceEvidence>();
    await show(tester, repository, Picker());
    await tester.pumpAndSettle();
    await pick(tester);
    await upload(tester);
    expect(find.byKey(const ValueKey('evidence-notice')), findsNothing);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('evidence-upload')))
            .onPressed,
        isNull);
    expect(repository.uploads, 1);
    repository.pending!.complete(evidence());
    await tester.pumpAndSettle();
    expect(find.text('Evidencia registrada.'), findsOneWidget);
    expect(find.byKey(const ValueKey('evidence-selected')), findsNothing);
    expect(find.text('informe.pdf'), findsOneWidget);
    expect(repository.reads, 2);
  });

  testWidgets('fallo conserva archivo para reintentar sin éxito falso',
      (tester) async {
    final repository = Repository()
      ..uploadError = const EvidenceFailure('Carga rechazada');
    await show(tester, repository, Picker());
    await tester.pumpAndSettle();
    await pick(tester);
    await upload(tester);
    await tester.pumpAndSettle();
    expect(find.text('Carga rechazada'), findsOneWidget);
    expect(find.byKey(const ValueKey('evidence-selected')), findsOneWidget);
    expect(find.byKey(const ValueKey('evidence-notice')), findsNothing);
    repository.uploadError = null;
    await upload(tester);
    await tester.pumpAndSettle();
    expect(find.text('Evidencia registrada.'), findsOneWidget);
  });

  testWidgets(
      'consulta rechazada no muestra datos anteriores ni permite cargar',
      (tester) async {
    final repository = Repository()
      ..loadError = const EvidenceFailure('Sin permiso');
    await show(tester, repository, Picker());
    await tester.pumpAndSettle();
    expect(find.text('Sin permiso'), findsOneWidget);
    expect(
        tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('evidence-pick')))
            .onPressed,
        isNull);
    repository.loadError = null;
    await tester.ensureVisible(find.text('Reintentar consulta'));
    await tester.tap(find.text('Reintentar consulta'));
    await tester.pumpAndSettle();
    expect(find.text('Todavía no hay evidencias registradas.'), findsOneWidget);
  });

  testWidgets(
      'lector sin permiso de carga consulta y abre por callback autorizado',
      (tester) async {
    final repository = Repository()..items = [evidence()];
    ServiceEvidence? opened;
    await show(tester, repository, Picker(),
        canUpload: false, open: (item) async => opened = item);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('evidence-pick')), findsNothing);
    await tester.tap(find.byTooltip('Abrir evidencia'));
    await tester.pumpAndSettle();
    expect(opened?.id, 'e1');
  });

  testWidgets('rechaza metadatos de otro servicio', (tester) async {
    final repository = Repository()..items = [evidence('otro')];
    await show(tester, repository, Picker());
    await tester.pumpAndSettle();
    expect(find.text('informe.pdf'), findsNothing);
    expect(find.byKey(const ValueKey('evidence-load-error')), findsOneWidget);
  });

  testWidgets('cambiar servicio descarta resultado tardío y archivo anterior',
      (tester) async {
    final repository = Repository()..pending = Completer<ServiceEvidence>();
    final picker = Picker();
    await show(tester, repository, picker);
    await tester.pumpAndSettle();
    await pick(tester);
    await upload(tester);
    final other = Repository();
    await show(tester, other, picker, service: 's2');
    await tester.pumpAndSettle();
    repository.pending!.complete(evidence());
    await tester.pumpAndSettle();
    expect(find.text('informe.pdf'), findsNothing);
    expect(find.byKey(const ValueKey('evidence-notice')), findsNothing);
  });

  testWidgets('pantalla compacta y estado vacío no desbordan', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await show(tester, Repository(), Picker());
    await tester.pumpAndSettle();
    await pick(tester);
    expect(tester.takeException(), isNull);
  });
}
