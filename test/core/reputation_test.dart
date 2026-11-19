import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/core/domain/reputation.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/core/widgets/reputation_badge.dart';
import 'package:ms_frontend/features/company/technicians/domain/associated_technician.dart';
import 'package:ms_frontend/features/company/technicians/presentation/widgets/associated_technician_tile.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(theme: FixiaTheme.light, home: Scaffold(body: child)));

void main() {
  group('Reputation.fromJson', () {
    test('lee promedio y número', () {
      final r = Reputation.fromJson({'average': 4.35, 'count': 7})!;
      expect(r.average, 4.35);
      expect(r.count, 7);
      expect(Reputation.fromJson({'average': 5, 'count': 1})!.countLabel,
          '1 calificación');
    });

    test('no inventa reputación con datos inválidos', () {
      for (final json in [
        null,
        'x',
        {'average': 4.5},
        {'count': 3},
        {'average': 4.5, 'count': 0},
        {'average': 0, 'count': 3},
        {'average': 7, 'count': 3},
        {'average': '4.5', 'count': 3},
      ]) {
        expect(Reputation.fromJson(json), isNull, reason: '$json');
      }
    });

    test('formato en español', () {
      const r = Reputation(average: 4, count: 12);
      expect(r.averageLabel, '4,0');
      expect(r.countLabel, '12 calificaciones');
    });
  });

  group('ReputationBadge', () {
    testWidgets('con reputación muestra promedio y número', (tester) async {
      await _pump(
          tester,
          const ReputationBadge(
              reputation: Reputation(average: 4.4, count: 8)));
      expect(find.text('4,4'), findsOneWidget);
      expect(find.text('(8 calificaciones)'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(
          find.bySemanticsLabel('4,4 de 5, 8 calificaciones'), findsOneWidget);
    });

    testWidgets('sin reputación lo dice', (tester) async {
      await _pump(tester, const ReputationBadge(reputation: null, large: true));
      expect(find.text('Sin calificaciones aún'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });
  });

  testWidgets('la empresa ve la calificación de cada técnico', (tester) async {
    await _pump(
      tester,
      const Column(
        children: [
          AssociatedTechnicianTile(
            technician: AssociatedTechnician(
              userId: 't1',
              displayName: 'Carlos G.',
              categories: [ServiceCategory.plumbing],
              reputation: Reputation(average: 4.4, count: 8),
            ),
          ),
          AssociatedTechnicianTile(
            technician:
                AssociatedTechnician(userId: 't2', displayName: 'Diana T.'),
          ),
        ],
      ),
    );
    expect(find.byKey(const ValueKey('associated-technician-reputation-t1')),
        findsOneWidget);
    expect(find.text('4,4'), findsOneWidget);
    expect(find.text('Sin calificaciones aún'), findsOneWidget);
  });
}
