import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/features/company/applications/presentation/company_application_form.dart';
import 'package:ms_frontend/features/company/applications/presentation/company_technician_selector.dart';
import 'package:ms_frontend/features/technician/applications/domain/service_application.dart';
import 'package:ms_frontend/features/technician/applications/infrastructure/http_application_repository.dart';
import 'package:ms_frontend/features/company/applications/infrastructure/http_company_application_repository.dart';
import 'package:ms_frontend/features/company/applications/domain/company_application_failure.dart';

const own =
    CompanyTechnicianOption(id: 't1', name: 'Técnico propio', eligible: true);
Map<String, Object?> response() => {
      'id': 'a1',
      'status': 'APPLIED',
      'providerType': 'COMPANY',
      'technicianId': 't1',
      'proposedAmount': 180000.25,
      'currency': 'COP',
      'serviceRequest': {
        'id': 'r1',
        'category': 'PLUMBING',
        'city': 'Bogotá',
        'zone': 'Suba'
      },
    };
http.Response jsonResponse(int status, Object body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);
HttpCompanyApplicationRepository repository(MockClientHandler handler) =>
    HttpCompanyApplicationRepository(
        client: MockClient((request) => request.method == 'GET'
            ? Future.value(jsonResponse(200, response()))
            : handler(request)),
        baseUrl: Uri.parse('http://localhost'),
        authorizedHttp: AuthorizedHttp(
            accessToken: () => 'token-de-prueba',
            renewSession: () async => false));
Future<void> show(
  WidgetTester tester,
  HttpCompanyApplicationRepository repo, {
  String session = 'empresa-1',
  List<CompanyTechnicianOption> technicians = const [own],
  ValueChanged<ServiceApplication>? submitted,
  VoidCallback? expired,
}) =>
    tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: CompanyApplicationForm(
                    sessionKey: session,
                    serviceRequestId: 'r1',
                    technicians: technicians,
                    loading: false,
                    repository: repo,
                    onRetryTechnicians: () {},
                    onSubmitted: submitted,
                    onSessionExpired: expired)))));
Future<void> select(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('company-technician-selector')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Técnico propio').last);
  await tester.pumpAndSettle();
}

Future<void> fillAndSend(WidgetTester tester,
    [String amount = '180000,25']) async {
  await tester.enterText(
      find.byKey(const ValueKey('application-price')), amount);
  final button = find.byKey(const ValueKey('application-price-submit'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

void main() {
  testWidgets(
      'asociado sin elegibilidad previa puede enviarse para validación Backend',
      (tester) async {
    var writes = 0;
    final repo = repository((_) async {
      writes++;
      return jsonResponse(201, response());
    });
    await show(tester, repo, technicians: const [
      CompanyTechnicianOption(id: 't1', name: 'Técnico propio', eligible: null)
    ]);
    await select(tester);
    await fillAndSend(tester);
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.text('Precio confirmado: 180.000,25 COP'), findsOneWidget);
  });

  for (final input in ['', '0', '-10', '1.001', '10000000000']) {
    testWidgets('importe inválido $input nunca se transforma ni envía',
        (tester) async {
      var writes = 0;
      await show(tester, repository((_) async {
        writes++;
        return jsonResponse(201, response());
      }));
      await select(tester);
      await fillAndSend(tester, input);
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(find.byKey(const ValueKey('application-price-confirmed')),
          findsNothing);
    });
  }

  testWidgets('409 bloquea un segundo envío incluso si se invoca el botón',
      (tester) async {
    var writes = 0;
    await show(tester, repository((_) async {
      writes++;
      return jsonResponse(409, {});
    }));
    await select(tester);
    await fillAndSend(tester);
    await tester.pumpAndSettle();
    tester
        .widget<FilledButton>(
            find.byKey(const ValueKey('application-price-submit')))
        .onPressed!();
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.textContaining('No envíes otra propuesta'), findsOneWidget);
  });

  testWidgets(
      'exige selección y envía técnico/precio sin identidad empresarial en cuerpo',
      (tester) async {
    var writes = 0;
    ServiceApplication? confirmed;
    final repo = repository((request) async {
      writes++;
      expect(jsonDecode(request.body), {
        'serviceRequestId': 'r1',
        'technicianId': 't1',
        'proposedAmount': 180000.25,
        'currency': 'COP'
      });
      return jsonResponse(201, response());
    });
    await show(tester, repo, submitted: (value) => confirmed = value);
    expect(
        tester
            .widget<AbsorbPointer>(find
                .ancestor(
                    of: find.byKey(const ValueKey('application-price-submit')),
                    matching: find.byType(AbsorbPointer))
                .first)
            .absorbing,
        isTrue);
    await select(tester);
    await fillAndSend(tester);
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(confirmed?.technicianId, 't1');
    expect(find.text('Precio confirmado: 180.000,25 COP'), findsOneWidget);
  });

  testWidgets('más de dos decimales no contacta API', (tester) async {
    var writes = 0;
    final repo = repository((_) async {
      writes++;
      return jsonResponse(201, response());
    });
    await show(tester, repo);
    await select(tester);
    await fillAndSend(tester, '180000,251');
    await tester.pumpAndSettle();
    expect(writes, 0);
  });

  testWidgets('409 no reintenta ni confirma éxito', (tester) async {
    var writes = 0;
    final repo = repository((_) async {
      writes++;
      return jsonResponse(409, {});
    });
    await show(tester, repo);
    await select(tester);
    await fillAndSend(tester);
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.byKey(const ValueKey('application-price-confirmed')),
        findsNothing);
    expect(
        find.text(HttpApplicationRepository.conflictMessage), findsOneWidget);
  });

  testWidgets('no cambia ejecutor durante POST', (tester) async {
    final pending = Completer<http.Response>();
    final repo = repository((_) => pending.future);
    await show(tester, repo);
    await select(tester);
    await fillAndSend(tester);
    expect(
        tester
            .widget<DropdownButtonFormField<String>>(
                find.byKey(const ValueKey('company-technician-selector')))
            .onChanged,
        isNull);
    pending.complete(jsonResponse(201, response()));
    await tester.pumpAndSettle();
  });

  testWidgets('cambio de sesión ignora confirmación anterior', (tester) async {
    final pending = Completer<http.Response>();
    var notifications = 0;
    final repo = repository((_) => pending.future);
    await show(tester, repo, submitted: (_) => notifications++);
    await select(tester);
    await fillAndSend(tester);
    await show(tester, repo,
        session: 'empresa-2', submitted: (_) => notifications++);
    pending.complete(jsonResponse(201, response()));
    await tester.pumpAndSettle();
    expect(notifications, 0);
    expect(find.byKey(const ValueKey('application-price-confirmed')),
        findsNothing);
    expect(find.text('180000,25'), findsNothing);
  });

  testWidgets('dejar de ser elegible invalida envío', (tester) async {
    final repo = repository((_) async => jsonResponse(201, response()));
    await show(tester, repo);
    await select(tester);
    await show(tester, repo, technicians: const [
      CompanyTechnicianOption(id: 't1', name: 'Técnico propio', eligible: false)
    ]);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<AbsorbPointer>(find
                .ancestor(
                    of: find.byKey(const ValueKey('application-price-submit')),
                    matching: find.byType(AbsorbPointer))
                .first)
            .absorbing,
        isTrue);
  });

  testWidgets('401 avisa al flujo de sesión sin confirmar', (tester) async {
    var expired = 0;
    final repo = repository((_) async => http.Response('', 401));
    await show(tester, repo, expired: () => expired++);
    await select(tester);
    await fillAndSend(tester);
    await tester.pumpAndSettle();
    expect(expired, 1);
    expect(find.byKey(const ValueKey('application-price-confirmed')),
        findsNothing);
  });

  testWidgets('otro técnico en respuesta no se acepta como confirmación',
      (tester) async {
    final repo = repository((_) async =>
        jsonResponse(201, {...response(), 'technicianId': 'ajeno'}));
    await show(tester, repo);
    await select(tester);
    await fillAndSend(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('application-price-confirmed')),
        findsNothing);
    expect(find.text(const CompanySubmissionUnconfirmed().message),
        findsOneWidget);
  });
}
