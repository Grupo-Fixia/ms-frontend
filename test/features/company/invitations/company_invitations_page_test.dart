import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/company/invitations/domain/company_invitation.dart';
import 'package:ms_frontend/features/company/invitations/presentation/company_invitations_page.dart';

CompanyInvitation _inv(String id, InvitationStatus status,
        {String name = 'Carlos G.'}) =>
    CompanyInvitation(
      id: id,
      status: status,
      technicianName: name,
      createdAt: DateTime.utc(2026, 11, 10, 15),
      expiresAt: DateTime.utc(2026, 11, 17, 15),
      respondedAt: status == InvitationStatus.pending
          ? null
          : DateTime.utc(2026, 11, 11, 10),
    );

class _Fake implements CompanyInvitationsGateway {
  _Fake(this.items);

  List<CompanyInvitation> items;
  final listCalls = <InvitationStatus?>[];
  final invites = <String>[];
  final cancels = <String>[];
  Object? inviteError;
  Object? listError;
  Object? cancelError;

  @override
  Future<CompanyInvitation> invite(String technicianEmail) async {
    invites.add(technicianEmail);
    if (inviteError != null) throw inviteError!;
    final created = _inv('nueva', InvitationStatus.pending, name: 'Laura P.');
    items = [created, ...items];
    return created;
  }

  @override
  Future<List<CompanyInvitation>> list({InvitationStatus? status}) async {
    listCalls.add(status);
    if (listError != null) throw listError!;
    return [
      for (final i in items)
        if (status == null || i.status == status) i
    ];
  }

  @override
  Future<void> cancel(String invitationId) async {
    cancels.add(invitationId);
    if (cancelError != null) throw cancelError!;
    items = [
      for (final i in items)
        i.id == invitationId ? _inv(i.id, InvitationStatus.cancelled) : i
    ];
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
    home: CompanyInvitationsPage(
        gateway: fake, onSessionExpired: onExpired ?? () {}),
  ));
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('lista las invitaciones con su estado', (tester) async {
    await _pump(
        tester,
        _Fake([
          _inv('p1', InvitationStatus.pending),
          _inv('a1', InvitationStatus.accepted, name: 'Ana R.'),
        ]));

    expect(_key('company-invitation-p1'), findsOneWidget);
    expect(_key('company-invitation-a1'), findsOneWidget);
    expect(find.text('Pendiente'), findsOneWidget);
    expect(find.text('Aceptada'), findsOneWidget);
    expect(_key('company-invitation-cancel-p1'), findsOneWidget);
    expect(_key('company-invitation-cancel-a1'), findsNothing);
  });

  testWidgets('invita: valida, envía, avisa y recarga', (tester) async {
    final fake = await _pump(tester, _Fake([]));
    expect(
        find.text('Todavía no has invitado a ningún técnico.'), findsOneWidget);

    await tester.tap(_key('company-invite-submit'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe el correo del técnico.'), findsOneWidget);
    expect(fake.invites, isEmpty);

    await tester.enterText(
        _key('company-invite-email'), 'tecnico5@fixia-qa.test');
    await tester.tap(_key('company-invite-submit'));
    await tester.pumpAndSettle();

    expect(fake.invites, ['tecnico5@fixia-qa.test']);
    expect(_key('company-invite-sent'), findsOneWidget);
    expect(find.textContaining('Laura P.'), findsWidgets);
    expect(_key('company-invitation-nueva'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(_key('company-invite-email'))
            .controller!
            .text,
        isEmpty);
  });

  testWidgets('un error al invitar se muestra y conserva el correo',
      (tester) async {
    final fake = _Fake([])
      ..inviteError = const InvitationFailure('No es posible invitar.');
    await _pump(tester, fake);

    await tester.enterText(_key('company-invite-email'), 'x@fixia.co');
    await tester.tap(_key('company-invite-submit'));
    await tester.pumpAndSettle();

    expect(_key('company-invite-error'), findsOneWidget);
    expect(find.text('No es posible invitar.'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(_key('company-invite-email'))
            .controller!
            .text,
        'x@fixia.co');
  });

  testWidgets('cancelar pide confirmación y actualiza', (tester) async {
    final fake =
        await _pump(tester, _Fake([_inv('p1', InvitationStatus.pending)]));

    await tester.tap(_key('company-invitation-cancel-p1'));
    await tester.pumpAndSettle();
    expect(_key('company-invitation-cancel-dialog'), findsOneWidget);

    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();
    expect(fake.cancels, isEmpty);

    await tester.tap(_key('company-invitation-cancel-p1'));
    await tester.pumpAndSettle();
    await tester.tap(_key('company-invitation-cancel-confirm'));
    await tester.pumpAndSettle();

    expect(fake.cancels, ['p1']);
    expect(_key('company-invitation-cancelled'), findsOneWidget);
    expect(find.text('Cancelada'), findsOneWidget);
    expect(_key('company-invitation-cancel-p1'), findsNothing);
  });

  testWidgets('un error al cancelar se avisa', (tester) async {
    final fake = _Fake([_inv('p1', InvitationStatus.pending)])
      ..cancelError = const InvitationFailure('Ya no está pendiente.');
    await _pump(tester, fake);
    await tester.tap(_key('company-invitation-cancel-p1'));
    await tester.pumpAndSettle();
    await tester.tap(_key('company-invitation-cancel-confirm'));
    await tester.pumpAndSettle();
    expect(_key('company-invitation-cancel-error'), findsOneWidget);
  });

  testWidgets('filtra por estado', (tester) async {
    final fake = await _pump(
        tester,
        _Fake([
          _inv('p1', InvitationStatus.pending),
          _inv('x1', InvitationStatus.expired),
        ]));
    await tester.tap(find.text('Vencidas'));
    await tester.pumpAndSettle();

    expect(fake.listCalls.last, InvitationStatus.expired);
    expect(_key('company-invitation-x1'), findsOneWidget);
    expect(_key('company-invitation-p1'), findsNothing);

    await tester.tap(find.text('Rechazadas'));
    await tester.pumpAndSettle();
    expect(find.text('No hay invitaciones rechazadas.'), findsOneWidget);
  });

  testWidgets('error de carga con reintento', (tester) async {
    final fake = _Fake([_inv('p1', InvitationStatus.pending)])
      ..listError = const InvitationFailure('Sin conexión.');
    await _pump(tester, fake);
    expect(_key('company-invitations-error'), findsOneWidget);

    fake.listError = null;
    await tester.tap(_key('company-invitations-retry'));
    await tester.pumpAndSettle();
    expect(_key('company-invitation-p1'), findsOneWidget);
  });

  testWidgets('sesión vencida avisa', (tester) async {
    var expired = 0;
    await _pump(
      tester,
      _Fake([])
        ..listError =
            const InvitationFailure('Expiró.', isSessionExpired: true),
      onExpired: () => expired++,
    );
    expect(expired, 1);
  });

  testWidgets('en celular no desborda', (tester) async {
    await _pump(
        tester,
        _Fake([
          for (var i = 0; i < 6; i++)
            _inv('p$i', InvitationStatus.pending, name: 'Técnico número $i'),
        ]),
        size: const Size(390, 844));
    expect(tester.takeException(), isNull);
    expect(_key('company-invite-submit'), findsOneWidget);
  });
}
