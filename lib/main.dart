import 'package:flutter/material.dart';

import 'core/theme/fixia_theme.dart';
import 'features/client/registration/application/ports/client_registration_repository.dart';
import 'features/client/registration/application/register_client.dart';
import 'features/client/registration/domain/client_registration.dart';
import 'features/client/registration/domain/client_registration_exceptions.dart';
import 'features/client/registration/presentation/client_registration_page.dart';

/// Rutas de la aplicación.
abstract final class AppRoutes {
  static const clientRegistration = '/registro-cliente';
}

void main() {
  runApp(
    const FixiaApp(
      // TODO(GC-253): reemplazar por el repositorio HTTP conectado a ms-users.
      clientRegistrationRepository: PendingClientRegistrationRepository(),
    ),
  );
}

class FixiaApp extends StatelessWidget {
  const FixiaApp({super.key, required this.clientRegistrationRepository});

  final ClientRegistrationRepository clientRegistrationRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fixia',
      debugShowCheckedModeBanner: false,
      theme: FixiaTheme.light,
      // TODO(GC-258): la ruta inicial pasa a ser el inicio de sesión.
      initialRoute: AppRoutes.clientRegistration,
      routes: {
        AppRoutes.clientRegistration: (_) => ClientRegistrationPage(
              registerClient: RegisterClient(clientRegistrationRepository),
            ),
      },
    );
  }
}

/// Repositorio temporal mientras GC-253 conecta el formulario con ms-users.
class PendingClientRegistrationRepository
    implements ClientRegistrationRepository {
  const PendingClientRegistrationRepository();

  @override
  Future<void> register(ClientRegistration registration) async {
    throw const ClientRegistrationFailure(
      'El registro todavía no está conectado al servicio (GC-253).',
    );
  }
}
