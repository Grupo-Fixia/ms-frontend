import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'core/config/api_config.dart';
import 'core/theme/fixia_theme.dart';
import 'features/auth/application/login_user.dart';
import 'features/auth/application/logout_user.dart';
import 'features/auth/application/ports/auth_repository.dart';
import 'features/auth/application/session_store.dart';
import 'features/auth/data/http_auth_repository.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/session_page.dart';
import 'features/client_registration/application/ports/client_registration_repository.dart';
import 'features/client_registration/application/register_client.dart';
import 'features/client_registration/domain/client_registration.dart';
import 'features/client_registration/domain/client_registration_exceptions.dart';
import 'features/client_registration/presentation/client_registration_page.dart';

/// Rutas de la aplicación.
abstract final class AppRoutes {
  static const login = '/login';
  static const session = '/sesion';
  static const clientRegistration = '/registro-cliente';
}

void main() {
  runApp(
    FixiaApp(
      // TODO(GC-253): reemplazar por el repositorio HTTP conectado a ms-users.
      clientRegistrationRepository: const PendingClientRegistrationRepository(),
      authRepository: HttpAuthRepository(
        client: http.Client(),
        baseUrl: Uri.parse(ApiConfig.usersBaseUrl),
      ),
    ),
  );
}

class FixiaApp extends StatefulWidget {
  const FixiaApp({
    super.key,
    required this.clientRegistrationRepository,
    required this.authRepository,
    this.sessionStore,
  });

  final ClientRegistrationRepository clientRegistrationRepository;
  final AuthRepository authRepository;

  /// Sesión de la app. Si es `null` se crea una vacía.
  final SessionStore? sessionStore;

  @override
  State<FixiaApp> createState() => _FixiaAppState();
}

class _FixiaAppState extends State<FixiaApp> {
  late final SessionStore _sessionStore =
      widget.sessionStore ?? SessionStore();

  @override
  void dispose() {
    if (widget.sessionStore == null) _sessionStore.dispose();
    super.dispose();
  }

  Widget _loginPage(BuildContext context) => LoginPage(
        loginUser: LoginUser(widget.authRepository, _sessionStore),
        onLoggedIn: () =>
            Navigator.of(context).pushReplacementNamed(AppRoutes.session),
        onGoToRegistration: () => Navigator.of(context)
            .pushReplacementNamed(AppRoutes.clientRegistration),
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fixia',
      debugShowCheckedModeBanner: false,
      theme: FixiaTheme.light,
      initialRoute: AppRoutes.login,
      routes: {
        AppRoutes.login: _loginPage,
        // Sin sesión no se muestra la cuenta: la ruta cae en el login.
        AppRoutes.session: (context) => ListenableBuilder(
              listenable: _sessionStore,
              builder: (context, _) => _sessionStore.isAuthenticated
                  ? SessionPage(
                      store: _sessionStore,
                      logoutUser:
                          LogoutUser(widget.authRepository, _sessionStore),
                      onLoggedOut: () => Navigator.of(context)
                          .pushNamedAndRemoveUntil(
                              AppRoutes.login, (_) => false),
                    )
                  : _loginPage(context),
            ),
        AppRoutes.clientRegistration: (context) => ClientRegistrationPage(
              registerClient:
                  RegisterClient(widget.clientRegistrationRepository),
              onGoToLogin: () =>
                  Navigator.of(context).pushReplacementNamed(AppRoutes.login),
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
