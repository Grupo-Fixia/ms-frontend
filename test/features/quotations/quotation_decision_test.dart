import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/quotations/application/quotation_use_cases.dart';
import 'package:ms_frontend/features/quotations/domain/quotation.dart';
import 'package:ms_frontend/features/quotations/infrastructure/mock_quotation_repository.dart';
import 'package:ms_frontend/features/quotations/presentation/quotation_detail_page.dart';

void main() {
  Future<MockQuotationRepository> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = MockQuotationRepository(providerId: 'p1');
    final now = DateTime.now();
    await repository.send(NewQuotation(
      serviceRequestId: 'r1',
      amountInCents: 5000000,
      scope: 'Cambio de sifón',
      conditions: 'Garantía',
      agreedAt: now.add(const Duration(days: 3)),
      validUntil: now.add(const Duration(days: 2)),
    ));
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: QuotationDetailPage(
          serviceRequestId: 'r1',
          listQuotations: ListRequestQuotations(repository),
          acceptQuotation: AcceptQuotation(repository),
          rejectQuotation: RejectQuotation(repository),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('GC-360: aceptar cambia el estado y muestra el siguiente paso',
      (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('quotation-accept')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('accept-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('ACEPTADA'), findsOneWidget);
    expect(find.byKey(const ValueKey('quotation-next-step')), findsOneWidget);
    expect(find.byKey(const ValueKey('quotation-accept')), findsNothing);
  });

  testWidgets('GC-360: rechazar con motivo opcional', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('quotation-reject')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('reject-reason')), 'Muy caro');
    await tester.tap(find.byKey(const ValueKey('reject-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('RECHAZADA'), findsOneWidget);
    expect(find.text('Muy caro'), findsOneWidget);
    expect(find.byKey(const ValueKey('quotation-reject')), findsNothing);
  });

  testWidgets('GC-360: cancelar el diálogo no cambia la cotización',
      (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('quotation-reject')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('ENVIADA'), findsOneWidget);
    expect(find.byKey(const ValueKey('quotation-accept')), findsOneWidget);
  });

  testWidgets('GC-360: una cotización vencida no se puede responder',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = MockQuotationRepository(providerId: 'p1');
    final now = DateTime.now();
    final q = await repository.send(NewQuotation(
      serviceRequestId: 'r1',
      amountInCents: 5000000,
      scope: 's',
      conditions: 'c',
      agreedAt: now.add(const Duration(days: 3)),
      validUntil: now.add(const Duration(days: 2)),
    ));
    repository.expire(q.id);
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: QuotationDetailPage(
          serviceRequestId: 'r1',
          listQuotations: ListRequestQuotations(repository),
          acceptQuotation: AcceptQuotation(repository),
          rejectQuotation: RejectQuotation(repository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('VENCIDA'), findsOneWidget);
    expect(find.byKey(const ValueKey('quotation-accept')), findsNothing);
    expect(find.byKey(const ValueKey('quotation-next-step')), findsOneWidget);
    expect(() => repository.accept(q.id), throwsA(anything));
  });
}
