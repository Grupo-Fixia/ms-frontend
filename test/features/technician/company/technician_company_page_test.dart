import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/technician/company/domain/technician_company.dart';
import 'package:ms_frontend/features/technician/company/presentation/technician_company_page.dart';

ReceivedInvitation _inv(String id, String company) => ReceivedInvitation(
      id: id,
      companyName: company,
      createdAt: DateTime.utc(2026, 11, 21, 15),
      expiresAt: DateTime.utc(2026, 11, 28, 15),
    );

class _Fake implements TechnicianCompanyGateway {
  _Fake({this.member, List<ReceivedInvitation>? invitations})
      : items = invitations ?? [];

  Membership? member;
  List<ReceivedInvitation> items;
  final accepted = <String>[];
  final rejected = <String>[];
  var leaves = 0;
  Object? leaveError;
  Object? acceptError;
  Object? loadError;

  @override
  Future<List<ReceivedInvitation>> invitations() async => items;

  @override
  Future<Membership?> membership() async {
    if (loadError != null) throw loadError!;
    return member;
  }

  @override
  Future<Membership> accept(String invitationId) async {
    accepted.add(invitationId);
    if (acceptError != null) throw acceptError!;
    final inv = items.firstWhere((i) => i.id == invitationId);
    member = Membership(
        companyName: inv.companyName, joinedAt: DateTime.utc(2026, 11, 22));
    items = [];
    return member!;
  }

  @override
  Future<void> reject(String invitationId) async {
    rejected.add(invitationId);
    items = [
      for (final i in items)
        if (i.id != invitationId) i
    ];
  }

  @override
  Future<void> leave() async {
    leaves++;
    if (leaveError != null) throw leaveError!;
    member = null;
  }
}

Finder _key(String k) => find.byKey(ValueKey(k));

Future<_Fake> _pump(WidgetTester tester, _Fake fake,
    {Size size = const Size(1280, 1000), VoidCallback? onExpired}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: FixiaTheme.light,
    home: TechnicianCompanyPage(
        gateway: fake, onSessionExpired: onExpired ?? () {}),
  ));
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('independiente sin invitaciones', (tester) async {
    await _pump(tester, _Fake());
    expect(_key('technician-independent'), findsOneWidget);
    expect(find.textContaining('No tienes invitaciones pendientes'),
        findsOneWidget);
  });

  testWidgets('acepta una invitación tras confirmar y queda en la empresa',
      (tester) async {
    final fake = await _pump(
        tester,
        _Fake(invitations: [
          _inv('i1', 'Soluciones Hogar'),
          _inv('i2', 'Reparaciones Express'),
        ]));

    await tester.tap(_key('technician-invitation-accept-i1'));
    await tester.pumpAndSettle();
    expect(_key('technician-invitation-accept-dialog'), findsOneWidget);
    expect(find.textContaining('Tus otras 1 invitaciones se cancelarán'),
        findsOneWidget);

    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();
    expect(fake.accepted, isEmpty);

    await tester.tap(_key('technician-invitation-accept-i1'));
    await tester.pumpAndSettle();
    await tester.tap(_key('technician-invitation-accept-dialog-confirm'));
    await tester.pumpAndSettle();

    expect(fake.accepted, ['i1']);
    expect(_key('technician-invitation-accepted'), findsOneWidget);
    expect(_key('technician-membership'), findsOneWidget);
    expect(find.text('Soluciones Hogar'), findsOneWidget);
  });

  testWidgets('un error al aceptar se muestra', (tester) async {
    final fake = _Fake(invitations: [_inv('i1', 'Soluciones Hogar')])
      ..acceptError = const TechnicianCompanyFailure(
          'Esta invitación ya no está pendiente.');
    await _pump(tester, fake);
    await tester.tap(_key('technician-invitation-accept-i1'));
    await tester.pumpAndSettle();
    await tester.tap(_key('technician-invitation-accept-dialog-confirm'));
    await tester.pumpAndSettle();
    expect(_key('technician-company-action-error'), findsOneWidget);
    expect(find.text('Esta invitación ya no está pendiente.'), findsOneWidget);
  });

  testWidgets('rechaza una invitación', (tester) async {
    final fake = await _pump(
        tester, _Fake(invitations: [_inv('i1', 'Soluciones Hogar')]));
    await tester.tap(_key('technician-invitation-reject-i1'));
    await tester.pumpAndSettle();
    await tester.tap(_key('technician-invitation-reject-dialog-confirm'));
    await tester.pumpAndSettle();
    expect(fake.rejected, ['i1']);
    expect(_key('technician-invitation-i1'), findsNothing);
    expect(_key('technician-invitation-rejected'), findsOneWidget);
  });

  testWidgets('con empresa: se desvincula y vuelve a independiente',
      (tester) async {
    final fake = await _pump(
        tester,
        _Fake(
            member: Membership(
                companyName: 'Soluciones Hogar',
                joinedAt: DateTime.utc(2026, 11, 1))));
    expect(_key('technician-membership'), findsOneWidget);
    expect(find.textContaining('Te uniste el'), findsOneWidget);

    await tester.tap(_key('technician-leave-company'));
    await tester.pumpAndSettle();
    await tester.tap(_key('technician-leave-dialog-confirm'));
    await tester.pumpAndSettle();

    expect(fake.leaves, 1);
    expect(_key('technician-left-company'), findsOneWidget);
    expect(_key('technician-independent'), findsOneWidget);
  });

  testWidgets('no puede desvincularse: explica por qué', (tester) async {
    final fake = _Fake(
        member:
            const Membership(companyName: 'Soluciones Hogar', joinedAt: null))
      ..leaveError = const TechnicianCompanyFailure(
        'Todavía no puedes desvincularte de la empresa.',
        statusCode: 409,
        blockers: [LeaveBlocker.pendingWork, LeaveBlocker.heldBalance],
        serviceRequestIds: ['s1', 's2'],
      );
    await _pump(tester, fake);
    await tester.tap(_key('technician-leave-company'));
    await tester.pumpAndSettle();
    await tester.tap(_key('technician-leave-dialog-confirm'));
    await tester.pumpAndSettle();

    expect(_key('technician-leave-blocked'), findsOneWidget);
    expect(
        find.textContaining(LeaveBlocker.pendingWork.message), findsOneWidget);
    expect(
        find.textContaining(LeaveBlocker.heldBalance.message), findsOneWidget);
    expect(find.text('Servicios relacionados: 2.'), findsOneWidget);
    expect(_key('technician-membership'), findsOneWidget);
  });

  testWidgets('503 al desvincularse se muestra como aviso', (tester) async {
    final fake = _Fake(
        member:
            const Membership(companyName: 'Soluciones Hogar', joinedAt: null))
      ..leaveError = const TechnicianCompanyFailure('No pudimos verificar.',
          statusCode: 503);
    await _pump(tester, fake);
    await tester.tap(_key('technician-leave-company'));
    await tester.pumpAndSettle();
    await tester.tap(_key('technician-leave-dialog-confirm'));
    await tester.pumpAndSettle();
    expect(find.text('No pudimos verificar.'), findsOneWidget);
    expect(_key('technician-leave-blocked'), findsNothing);
  });

  testWidgets('error de carga con reintento y sesión vencida', (tester) async {
    var expired = 0;
    final fake = _Fake()
      ..loadError =
          const TechnicianCompanyFailure('Expiró.', isSessionExpired: true);
    await _pump(tester, fake, onExpired: () => expired++);
    expect(expired, 1);
    expect(_key('technician-company-error'), findsOneWidget);

    fake.loadError = null;
    await tester.tap(_key('technician-company-retry'));
    await tester.pumpAndSettle();
    expect(_key('technician-independent'), findsOneWidget);
  });

  testWidgets('en celular no desborda', (tester) async {
    await _pump(
        tester,
        _Fake(invitations: [
          for (var i = 0; i < 4; i++)
            _inv('i$i', 'Empresa con un nombre bastante largo número $i'),
        ]),
        size: const Size(390, 844));
    expect(tester.takeException(), isNull);
  });
}
