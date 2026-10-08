import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/api_config.dart';
import 'core/theme/fixia_theme.dart';
import 'features/auth/login/application/login_user.dart';
import 'features/auth/login/application/logout_user.dart';
import 'features/auth/login/application/ports/auth_repository.dart';
import 'features/auth/login/application/ports/session_storage.dart';
import 'features/auth/login/application/restore_session.dart';
import 'features/auth/login/application/session_store.dart';
import 'features/auth/login/infrastructure/http_auth_repository.dart';
import 'features/auth/login/infrastructure/shared_preferences_session_storage.dart';
import 'features/auth/login/presentation/login_page.dart';
import 'features/auth/login/presentation/session_page.dart';
import 'features/client/registration/application/ports/client_registration_repository.dart';
import 'features/client/registration/application/register_client.dart';
import 'features/client/registration/infrastructure/http_client_registration_repository.dart';
import 'features/client/registration/presentation/client_registration_page.dart';
import 'features/home/presentation/home_page.dart';

/// Rutas de la aplicación.
abstract final class AppRoutes {
  static const home = '/';
  static const login = '/login';
  static const session = '/sesion';
  static const clientRegistration = '/registro-cliente';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final httpClient = http.Client();
  final usersApiBaseUrl = Uri.parse(ApiConfig.usersBaseUrl);
  final authRepository = HttpAuthRepository(
    client: httpClient,
    baseUrl: usersApiBaseUrl,
  );
  final sessionStorage =
      SharedPreferencesSessionStorage(await SharedPreferences.getInstance());

  // "Mantener sesión iniciada": si hay un refresh token guardado, la sesión
  // se restaura antes de mostrar la primera pantalla.
  final sessionStore = SessionStore();
  await RestoreSession(authRepository, sessionStore, sessionStorage)();

  runApp(
    FixiaApp(
      clientRegistrationRepository: HttpClientRegistrationRepository(
        client: httpClient,
        baseUrl: usersApiBaseUrl,
      ),
      authRepository: authRepository,
      sessionStorage: sessionStorage,
      sessionStore: sessionStore,
    ),
  );
}

class FixiaApp extends StatefulWidget {
  const FixiaApp({
    super.key,
    required this.clientRegistrationRepository,
    required this.authRepository,
    required this.sessionStorage,
    this.sessionStore,
  });

  final ClientRegistrationRepository clientRegistrationRepository;
  final AuthRepository authRepository;
  final SessionStorage sessionStorage;

  /// Sesión de la app. Si es `null` se crea una vacía. Llega con la sesión ya
  /// iniciada cuando se restauró desde el almacenamiento.
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

  LogoutUser get _logoutUser => LogoutUser(
        widget.authRepository,
        _sessionStore,
        widget.sessionStorage,
      );

  Widget _sessionPage(BuildContext context) => SessionPage(
        store: _sessionStore,
        logoutUser: _logoutUser,
        onLoggedOut: () => Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false),
      );

  Widget _loginPage(BuildContext context) {
    // Con una sesión ya iniciada (por ejemplo, restaurada) no se pide login.
    if (_sessionStore.isAuthenticated) return _sessionPage(context);
    return LoginPage(
      loginUser: LoginUser(
        widget.authRepository,
        _sessionStore,
        widget.sessionStorage,
      ),
      onLoggedIn: () =>
          Navigator.of(context).pushReplacementNamed(AppRoutes.session),
      onGoToRegistration: () => Navigator.of(context)
          .pushReplacementNamed(AppRoutes.clientRegistration),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fixia',
      debugShowCheckedModeBanner: false,
      theme: FixiaTheme.light,
      initialRoute:
          _sessionStore.isAuthenticated ? AppRoutes.session : AppRoutes.home,
      routes: {
        // Con sesión iniciada la página de inicio lleva directo a la cuenta.
        AppRoutes.home: (context) => _sessionStore.isAuthenticated
            ? _sessionPage(context)
            : HomePage(
                onRegisterClient: () => Navigator.of(context)
                    .pushNamed(AppRoutes.clientRegistration),
                onLogin: () =>
                    Navigator.of(context).pushNamed(AppRoutes.login),
              ),
        AppRoutes.login: _loginPage,
        // Sin sesión no se muestra la cuenta: la ruta cae en el login.
        AppRoutes.session: (context) => ListenableBuilder(
              listenable: _sessionStore,
              builder: (context, _) => _sessionStore.isAuthenticated
                  ? _sessionPage(context)
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
