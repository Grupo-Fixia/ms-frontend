import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/quotations/application/quotation_use_cases.dart';
import 'package:ms_frontend/features/quotations/domain/quotation.dart';
import 'package:ms_frontend/features/quotations/infrastructure/mock_quotation_repository.dart';
import 'package:ms_frontend/features/quotations/presentation/quotation_detail_page.dart';
import 'package:ms_frontend/features/quotations/presentation/quotation_form_page.dart';
import 'package:ms_frontend/features/quotations/presentation/quotation_formatters.dart';

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  test('formatMoney agrupa miles y omite centavos en cero', () {
    expect(formatMoney(15000000), '\$150.000');
    expect(formatMoney(12345050), '\$123.450,50');
    expect(formatMoney(0), '\$0');
  });

  testWidgets('GC-355: el formulario valida y luego envía la cotización',
      (tester) async {
    phone(tester);
    final repository = MockQuotationRepository(providerId: 'p1');
    Quotation? sent;
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: QuotationFormPage(
          serviceRequestId: 'r1',
          sendQuotation: SendQuotation(repository),
          onSent: (q) => sent = q,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('quotation-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Escribe el valor con máximo dos decimales.'),
        findsOneWidget);
    expect(find.text('Describe el alcance del trabajo.'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('quotation-labor')), '100000');
    await tester.tap(find.byKey(const ValueKey('quotation-add-material')));
    await tester.pump();
    await tester.enterText(
        find.byKey(const ValueKey('quotation-material-name-0')), 'Sifón');
    await tester.enterText(
        find.byKey(const ValueKey('quotation-material-amount-0')), '25000');
    await tester.pump();
    expect(find.text('\$125.000'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('quotation-scope')), 'Cambio de sifón');
    await tester.enterText(
        find.byKey(const ValueKey('quotation-conditions')), 'Garantía 30 días');

    await tester
        .ensureVisible(find.byKey(const ValueKey('quotation-valid-until')));
    await tester.tap(find.byKey(const ValueKey('quotation-valid-until')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('quotation-agreed-at')));
    await tester.tap(find.byKey(const ValueKey('quotation-agreed-at')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('quotation-submit')));
    await tester.tap(find.byKey(const ValueKey('quotation-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('quotation-sent')), findsOneWidget);
    expect(sent?.amountInCents, 12500000);
    expect(sent?.materials.single.name, 'Sifón');
    expect(sent?.laborInCents, 10000000);
  });

  testWidgets('GC-355: el cliente ve el desglose de la cotización',
      (tester) async {
    phone(tester);
    final repository = MockQuotationRepository(providerId: 'p1');
    final now = DateTime.now();
    await repository.send(NewQuotation(
      serviceRequestId: 'r1',
      amountInCents: 12500000,
      scope: 'Cambio de sifón',
      conditions: 'Garantía 30 días',
      agreedAt: now.add(const Duration(days: 3)),
      validUntil: now.add(const Duration(days: 2)),
      materials: const [
        QuotationMaterial(name: 'Sifón', amountInCents: 2500000),
      ],
    ));

    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: QuotationDetailPage(
          serviceRequestId: 'r1',
          listQuotations: ListRequestQuotations(repository),
          providerName: 'Carlos Ramírez',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cotización de Carlos Ramírez'), findsOneWidget);
    expect(find.text('\$100.000'), findsOneWidget);
    expect(find.text('Sifón'), findsOneWidget);
    expect(find.text('\$125.000'), findsOneWidget);
    expect(find.text('Garantía 30 días'), findsOneWidget);
    expect(find.text('ENVIADA'), findsOneWidget);
  });
}
