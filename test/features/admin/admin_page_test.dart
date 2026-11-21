import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/admin/domain/admin.dart';
import 'package:ms_frontend/features/admin/presentation/admin_page.dart';
import 'package:ms_frontend/features/payments/domain/payments.dart';

AdminUser _user(String id, {AdminUserRole role = AdminUserRole.client}) =>
    AdminUser(
      id: id,
      email: '$id@fixia-qa.test',
      firstName: 'Nombre',
      lastName: id,
      role: role,
      status: AdminUserStatus.active,
      createdAt: DateTime.utc(2026, 11, 4),
    );

AdminPayment _payment(String id, {RefundKind? kind}) => AdminPayment(
      payment: ServicePayment(
        id: id,
        serviceRequestId: 'req-$id',
        amountCents: 18400000,
        status: PaymentStatus.processing,
        method: 'Wallet',
        isWalletPayment: true,
        holdStatus: HoldStatus.held,
      ),
      clientId: 'cli-1',
      providerId: 'pro-1',
      createdAt: DateTime.utc(2026, 11, 7),
      refundKind: kind,
    );

class _FakeGateway implements AdminGateway {
  final userCalls = <(AdminUserRole?, AdminUserStatus?, String?, String?)>[];
  final paymentCalls = <(HoldStatus?, String?)>[];
  final refundCalls = <(String, String, String)>[];
  final auditCalls = <AuditSource>[];
  Object? refundError;
  Object? usersError;

  @override
  Future<AdminList<AdminUser>> users(
      {AdminUserRole? role,
      AdminUserStatus? status,
      String? query,
      String? cursor}) async {
    userCalls.add((role, status, query, cursor));
    if (usersError != null) throw usersError!;
    if (cursor == null) {
      return AdminList(items: [_user('u1'), _user('u2')], nextCursor: 'next');
    }
    return AdminList(items: [_user('u3')]);
  }

  @override
  Future<AdminUserDetail> user(String id) async => AdminUserDetail(
        id: id,
        email: '$id@fixia-qa.test',
        firstName: 'Nombre',
        lastName: id,
        role: AdminUserRole.client,
        status: AdminUserStatus.active,
        createdAt: DateTime.utc(2026, 11, 4),
        documentType: 'CC',
        documentNumberMasked: '******0001',
      );

  @override
  Future<AdminList<AdminPayment>> payments(
      {HoldStatus? holdStatus, String? userId, String? cursor}) async {
    paymentCalls.add((holdStatus, userId));
    return AdminList(items: [
      _payment('p1', kind: RefundKind.release),
      _payment('p2'),
    ]);
  }

  @override
  Future<ServicePayment> refund(String paymentId,
      {required String reason, required String idempotencyKey}) async {
    refundCalls.add((paymentId, reason, idempotencyKey));
    final error = refundError;
    if (error != null) {
      refundError = null;
      throw error;
    }
    return ServicePayment(
      id: paymentId,
      serviceRequestId: 'req-$paymentId',
      amountCents: 18400000,
      status: PaymentStatus.refunded,
      method: 'Wallet',
      isWalletPayment: true,
      holdStatus: HoldStatus.released,
    );
  }

  @override
  Future<AdminList<AdminAuditEvent>> auditEvents(AuditSource source,
      {String? cursor}) async {
    auditCalls.add(source);
    return AdminList(items: [
      AdminAuditEvent(
        id: 'e-${source.name}',
        adminId: 'admin-1',
        action: source == AuditSource.users ? 'USER_LIST' : 'PAYMENT_REFUND',
        outcome: 'OK',
        occurredAt: DateTime.utc(2026, 11, 7),
      ),
    ]);
  }
}

Finder _key(String key) => find.byKey(ValueKey(key));

Future<_FakeGateway> _pump(
  WidgetTester tester, {
  _FakeGateway? gateway,
  AdminSection section = AdminSection.users,
  Size size = const Size(1280, 900),
  VoidCallback? onLogout,
  VoidCallback? onSessionExpired,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = gateway ?? _FakeGateway();
  var keys = 0;
  await tester.pumpWidget(MaterialApp(
    theme: FixiaTheme.light,
    home: AdminPage(
      gateway: fake,
      adminName: 'Ada Admin',
      initialSection: section,
      onLogout: onLogout ?? () {},
      onSessionExpired: onSessionExpired ?? () {},
      newKey: () => 'key-${++keys}',
    ),
  ));
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  group('usuarios', () {
    testWidgets('lista, carga más y filtra por rol', (tester) async {
      final fake = await _pump(tester);

      expect(_key('admin-user-u1'), findsOneWidget);
      expect(_key('admin-user-u2'), findsOneWidget);

      await tester.tap(_key('admin-load-more'));
      await tester.pumpAndSettle();
      expect(_key('admin-user-u3'), findsOneWidget);
      expect(fake.userCalls.last.$4, 'next');

      await tester.tap(find.text('Técnico'));
      await tester.pumpAndSettle();
      expect(fake.userCalls.last.$1, AdminUserRole.professional);
      expect(fake.userCalls.last.$4, isNull);
    });

    testWidgets('búsqueda de menos de 2 letras no filtra', (tester) async {
      final fake = await _pump(tester);

      await tester.enterText(_key('admin-users-search'), 'a');
      await tester.tap(_key('admin-users-search-submit'));
      await tester.pumpAndSettle();
      expect(fake.userCalls.last.$3, isNull);

      await tester.enterText(_key('admin-users-search'), '  ana  ');
      await tester.tap(_key('admin-users-search-submit'));
      await tester.pumpAndSettle();
      expect(fake.userCalls.last.$3, 'ana');
    });

    testWidgets('el detalle muestra el documento enmascarado', (tester) async {
      await _pump(tester);

      await tester.tap(_key('admin-user-u1'));
      await tester.pumpAndSettle();

      expect(_key('admin-user-detail'), findsOneWidget);
      expect(find.text('CC ******0001'), findsOneWidget);
    });

    testWidgets('un error se muestra y se puede reintentar', (tester) async {
      final fake = _FakeGateway()
        ..usersError = const AdminFailure('Sin permisos.');
      await _pump(tester, gateway: fake);

      expect(find.text('Sin permisos.'), findsOneWidget);
      fake.usersError = null;
      await tester.tap(_key('admin-list-retry'));
      await tester.pumpAndSettle();
      expect(_key('admin-user-u1'), findsOneWidget);
    });

    testWidgets('sesión vencida avisa una vez', (tester) async {
      var expired = 0;
      await _pump(
        tester,
        gateway: _FakeGateway()
          ..usersError =
              const AdminFailure('Expiró.', isSessionExpired: true),
        onSessionExpired: () => expired++,
      );
      expect(expired, 1);
    });
  });

  group('pagos y reembolso', () {
    testWidgets('solo ofrece reembolsar lo reembolsable', (tester) async {
      await _pump(tester, section: AdminSection.payments);

      expect(_key('admin-payment-p1'), findsOneWidget);
      expect(_key('admin-refund-p1'), findsOneWidget);
      expect(_key('admin-payment-p2'), findsOneWidget);
      expect(_key('admin-refund-p2'), findsNothing);
    });

    testWidgets('filtra por retención', (tester) async {
      final fake = await _pump(tester, section: AdminSection.payments);
      await tester.tap(find.text('Cobrados'));
      await tester.pumpAndSettle();
      expect(fake.paymentCalls.last.$1, HoldStatus.captured);
    });

    testWidgets('sin motivo no reembolsa', (tester) async {
      final fake = await _pump(tester, section: AdminSection.payments);

      await tester.tap(_key('admin-refund-p1'));
      await tester.pumpAndSettle();
      expect(_key('admin-refund-dialog'), findsOneWidget);
      expect(find.text(RefundKind.release.description), findsOneWidget);

      await tester.tap(_key('admin-refund-confirm'));
      await tester.pumpAndSettle();

      expect(find.text('Escribe el motivo del reembolso.'), findsOneWidget);
      expect(fake.refundCalls, isEmpty);
    });

    testWidgets('un reintento usa la misma clave de idempotencia',
        (tester) async {
      final fake = _FakeGateway()
        ..refundError = const AdminFailure('Sin conexión.');
      await _pump(tester, gateway: fake, section: AdminSection.payments);
      final loadsBefore = fake.paymentCalls.length;

      await tester.tap(_key('admin-refund-p1'));
      await tester.pumpAndSettle();
      await tester.enterText(_key('admin-refund-reason'), 'Servicio cancelado');
      await tester.tap(_key('admin-refund-confirm'));
      await tester.pumpAndSettle();

      expect(_key('admin-refund-error'), findsOneWidget);
      expect(_key('admin-refund-dialog'), findsOneWidget);

      await tester.tap(_key('admin-refund-confirm'));
      await tester.pumpAndSettle();

      expect(fake.refundCalls, [
        ('p1', 'Servicio cancelado', 'key-1'),
        ('p1', 'Servicio cancelado', 'key-1'),
      ]);
      expect(_key('admin-refund-dialog'), findsNothing);
      expect(_key('admin-refund-done'), findsOneWidget);
      expect(fake.paymentCalls.length, loadsBefore + 1,
          reason: 'recarga la lista tras reembolsar');
    });

    testWidgets('un reembolso nuevo usa otra clave', (tester) async {
      final fake = await _pump(tester, section: AdminSection.payments);
      for (var i = 0; i < 2; i++) {
        await tester.tap(_key('admin-refund-p1'));
        await tester.pumpAndSettle();
        await tester.enterText(_key('admin-refund-reason'), 'Motivo');
        await tester.tap(_key('admin-refund-confirm'));
        await tester.pumpAndSettle();
      }
      expect(fake.refundCalls.map((c) => c.$3), ['key-1', 'key-2']);
    });

    testWidgets('cancelar no reembolsa', (tester) async {
      final fake = await _pump(tester, section: AdminSection.payments);
      await tester.tap(_key('admin-refund-p1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(_key('admin-refund-dialog'), findsNothing);
      expect(fake.refundCalls, isEmpty);
    });
  });

  group('registro y navegación', () {
    testWidgets('registro: cambia entre pagos y usuarios', (tester) async {
      final fake = await _pump(tester, section: AdminSection.audit);
      expect(find.text('Reembolsó un pago'), findsOneWidget);

      await tester.tap(find.text('Usuarios').last);
      await tester.pumpAndSettle();
      expect(find.text('Consultó la lista de usuarios'), findsOneWidget);
      expect(fake.auditCalls, [AuditSource.payments, AuditSource.users]);
    });

    for (final (label, size) in const [
      ('escritorio', Size(1280, 900)),
      ('celular', Size(390, 844)),
    ]) {
      testWidgets('$label: navega entre secciones y cierra sesión',
          (tester) async {
        var logout = 0;
        await _pump(tester, size: size, onLogout: () => logout++);

        await tester.tap(_key('admin-nav-payments'));
        await tester.pumpAndSettle();
        expect(_key('admin-payment-p1'), findsOneWidget);

        await tester.tap(_key('admin-nav-audit'));
        await tester.pumpAndSettle();
        expect(find.text('Registro de acciones'), findsOneWidget);

        await tester.tap(_key('admin-logout'));
        expect(logout, 1);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
