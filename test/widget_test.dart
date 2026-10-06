import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/client_registration/domain/client_registration.dart';
import 'package:ms_frontend/features/client_registration/domain/client_registration_exceptions.dart';
import 'package:ms_frontend/features/client_registration/domain/document_type.dart';
import 'package:ms_frontend/main.dart';

void main() {
  testWidgets('la app arranca en el registro de cliente', (tester) async {
    await tester.pumpWidget(
      const FixiaApp(
        clientRegistrationRepository: PendingClientRegistrationRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Crea tu cuenta'), findsOneWidget);
    expect(find.byType(Form), findsOneWidget);
  });

  test('el repositorio temporal avisa que falta conectar el servicio', () {
    const repository = PendingClientRegistrationRepository();
    final registration = ClientRegistration(
      firstName: 'Ana',
      lastName: 'Pérez',
      documentType: DocumentType.cc,
      documentNumber: '1020304050',
      email: 'ana@fixia.com',
      phone: '3001234567',
      password: 'Segura123',
      policyVersion: 'v1.0',
      consentAccepted: true,
      consentAcceptedAt: DateTime(2026, 10, 6),
    );

    expect(
      repository.register(registration),
      throwsA(isA<ClientRegistrationFailure>()),
    );
  });
}
