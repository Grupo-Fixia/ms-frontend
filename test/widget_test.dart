import 'package:flutter_test/flutter_test.dart';

import 'package:ms_frontend/main.dart' as app;

void main() {
  testWidgets('la app arranca y muestra la pantalla inicial', (tester) async {
    app.main();
    await tester.pump();

    expect(find.text('Fixia Platform Frontend'), findsOneWidget);
  });
}
