import 'package:flutter/material.dart';
import 'features/dev_sandbox/presentation/flow_sandbox_page.dart';
import 'package:http/http.dart' as http;

import 'core/config/api_config.dart';
import 'core/http/authorized_http.dart';
import 'core/theme/fixia_theme.dart';
import 'features/auth/login/application/login_user.dart';
import 'features/auth/login/application/logout_user.dart';
import 'features/auth/login/application/ports/auth_repository.dart';
import 'features/auth/login/application/ports/session_storage.dart';
import 'features/auth/login/application/refresh_session.dart';
import 'features/auth/login/application/restore_session.dart';
import 'features/auth/login/application/route_guard.dart';
import 'features/auth/login/application/session_store.dart';
import 'features/auth/login/infrastructure/http_auth_repository.dart';
import 'features/auth/login/infrastructure/browser_key_value_store.dart';
import 'features/auth/login/infrastructure/browser_session_storage.dart';
import 'features/auth/login/presentation/login_page.dart';
import 'features/auth/login/presentation/session_page.dart';
import 'features/auth/registration/application/ports/account_registration_repository.dart';
import 'features/auth/registration/application/register_account.dart';
import 'features/auth/registration/domain/account_role.dart';
import 'features/auth/registration/infrastructure/http_account_registration_repository.dart';
import 'features/auth/registration/presentation/registration_page.dart';
import 'features/auth/login/domain/user_profile.dart';
import 'features/client/dashboard/presentation/client_dashboard_page.dart';
import 'features/client/profile/domain/client_profile_update.dart';
import 'features/client/profile/presentation/client_profile_page.dart';
import 'features/client/service_request/presentation/service_request_page.dart';
import 'features/home/presentation/home_page.dart';
import 'features/technician/dashboard/presentation/technician_dashboard_page.dart';
import 'features/technician/opportunities/presentation/technician_opportunities_page.dart';
import 'features/technician/applications/application/application_use_cases.dart';
import 'features/technician/applications/infrastructure/http_application_repository.dart';
import 'features/technician/opportunities/application/list_compatible_opportunities.dart';
import 'features/technician/opportunities/infrastructure/http_opportunity_repository.dart';
import 'features/technician/specialties/application/get_service_catalog.dart';
import 'features/technician/specialties/application/get_technician_specialties.dart';
import 'features/technician/specialties/application/ports/technician_specialties_repository.dart';
import 'features/technician/specialties/application/update_technician_specialties.dart';
import 'features/technician/specialties/infrastructure/demo_technician_specialties_repository.dart';
import 'features/technician/specialties/infrastructure/http_technician_specialties_repository.dart';
import 'features/technician/specialties/presentation/technician_specialties_page.dart';
import 'features/technician/profile/application/get_technician_profile.dart';
import 'features/technician/profile/application/ports/technician_profile_repository.dart';
import 'features/technician/profile/application/update_technician_profile.dart';
import 'features/technician/profile/domain/technician_profile.dart';
import 'features/technician/profile/domain/technician_profile_exceptions.dart';
import 'features/technician/profile/infrastructure/http_technician_profile_repository.dart';
import 'features/technician/profile/presentation/technician_profile_page.dart';
import 'features/technician/profile/domain/verification_status.dart';

/// Rutas de la aplicación.
abstract final class AppRoutes {
  static const home = '/';
  static const login = '/login';
  static const session = '/sesion';
  static const clientRegistration = '/registro-cliente';
  static const technicianRegistration = '/registro-tecnico';
  static const clientDashboard = '/demo/inicio-cliente';
  static const technicianDashboard = '/demo/inicio-tecnico';
  static const clientServiceRequest = '/cliente/publicar-problema';
  static const technicianOpportunities = '/tecnico/solicitudes';
  static const technicianSpecialties = '/tecnico/especialidades';
  static const clientProfile = '/cliente/perfil';
  static const technicianProfile = '/tecnico/perfil';
  static const devFlowSandbox = '/dev/flujo-e2e';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final httpClient = http.Client();
  final usersApiBaseUrl = Uri.parse(ApiConfig.usersBaseUrl);
  final authRepository = HttpAuthRepository(
    client: httpClient,
    baseUrl: usersApiBaseUrl,
  );
  final sessionStorage = BrowserSessionStorage(
    tab: tabKeyValueStore(),
    persistent: persistentKeyValueStore(),
  );

  // Si hay un refresh token guardado (recarga de la pestaña o "Mantener sesión
  // iniciada"), la sesión se restaura antes de mostrar la primera pantalla.
  final sessionStore = SessionStore();
  await RestoreSession(authRepository, sessionStore, sessionStorage)();

  // ms-services con sesión real, salvo que se pida el modo local
  // (`--dart-define=USE_MOCK_APPLICATIONS=true`).
  final servicesApiBaseUrl = Uri.parse(ApiConfig.servicesBaseUrl);
  final servicesAuthorizedHttp = ApiConfig.useMockApplications
      ? null
      : AuthorizedHttp(
          accessToken: () => sessionStore.session?.accessToken,
          renewSession: RefreshSession(
            authRepository,
            sessionStore,
            sessionStorage,
          ).call,
        );

  runApp(
    FixiaApp(
      clientRegistrationRepository: HttpAccountRegistrationRepository(
        client: httpClient,
        baseUrl: usersApiBaseUrl,
      ),
      technicianRegistrationRepository: HttpAccountRegistrationRepository(
        client: httpClient,
        baseUrl: usersApiBaseUrl,
        role: AccountRole.technician,
      ),
      technicianProfileRepository: HttpTechnicianProfileRepository(
        client: httpClient,
        baseUrl: usersApiBaseUrl,
        accessToken: () => sessionStore.session?.accessToken,
        renewSession: RefreshSession(
          authRepository,
          sessionStore,
          sessionStorage,
        ).renew,
      ),
      technicianSpecialtiesRepository: HttpTechnicianSpecialtiesRepository(
        client: httpClient,
        baseUrl: usersApiBaseUrl,
        authorizedHttp: AuthorizedHttp(
          accessToken: () => sessionStore.session?.accessToken,
          renewSession: RefreshSession(
            authRepository,
            sessionStore,
            sessionStorage,
          ).call,
        ),
      ),
      authRepository: authRepository,
      sessionStorage: sessionStorage,
      sessionStore: sessionStore,
      listOpportunities: servicesAuthorizedHttp == null
          ? null
          : ListCompatibleOpportunities(
              HttpOpportunityRepository(
                client: httpClient,
                baseUrl: servicesApiBaseUrl,
                authorizedHttp: servicesAuthorizedHttp,
              ),
            ),
      applyToServiceRequest: servicesAuthorizedHttp == null
          ? null
          : ApplyToServiceRequest(
              HttpApplicationRepository(
                client: httpClient,
                baseUrl: servicesApiBaseUrl,
                authorizedHttp: servicesAuthorizedHttp,
              ),
            ),
    ),
  );
}

class FixiaApp extends StatefulWidget {
  const FixiaApp({
    super.key,
    required this.clientRegistrationRepository,
    required this.technicianRegistrationRepository,
    required this.technicianProfileRepository,
    required this.authRepository,
    required this.sessionStorage,
    this.technicianSpecialtiesRepository,
    this.listOpportunities,
    this.applyToServiceRequest,
    this.sessionStore,
  });

  /// Solicitudes compatibles y postulación reales (ms-services). Si son
  /// `null` la pantalla de oportunidades usa datos locales de demostración.
  final ListCompatibleOpportunities? listOpportunities;
  final ApplyToServiceRequest? applyToServiceRequest;

  final AccountRegistrationRepository clientRegistrationRepository;
  final AccountRegistrationRepository technicianRegistrationRepository;
  final TechnicianProfileRepository technicianProfileRepository;
  final AuthRepository authRepository;
  final SessionStorage sessionStorage;

  /// Repositorio de especialidades del técnico con sesión. Si es `null` se usa
  /// uno en memoria.
  final TechnicianSpecialtiesRepository? technicianSpecialtiesRepository;

  /// Sesión de la app. Si es `null` se crea una vacía. Llega con la sesión ya
  /// iniciada cuando se restauró desde el almacenamiento.
  final SessionStore? sessionStore;

  @override
  State<FixiaApp> createState() => _FixiaAppState();
}

class _FixiaAppState extends State<FixiaApp> {
  late final SessionStore _sessionStore = widget.sessionStore ?? SessionStore();
  late final TechnicianSpecialtiesRepository _specialtiesRepository =
      widget.technicianSpecialtiesRepository ??
          DemoTechnicianSpecialtiesRepository();

  Widget _technicianSpecialtiesPage(BuildContext context) {
    final repository = _specialtiesRepository;
    return TechnicianSpecialtiesPage(
      getCatalog: GetServiceCatalog(repository),
      getSpecialties: GetTechnicianSpecialties(repository),
      updateSpecialties: UpdateTechnicianSpecialties(repository),
      onSessionExpired: () {
        _sessionStore.clear();
        _goToLogin(context);
      },
      onCancel: () => Navigator.of(context).maybePop(),
      onOpenHome: () => Navigator.of(context)
          .pushReplacementNamed(AppRoutes.technicianDashboard),
      onOpenOpportunities: () => Navigator.of(context)
          .pushReplacementNamed(AppRoutes.technicianOpportunities),
      onOpenProfile: () => Navigator.of(context)
          .pushReplacementNamed(AppRoutes.technicianProfile),
    );
  }

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

  /// Inicia sesión con la cuenta recién creada y lleva al destino de la
  /// sesión (para el técnico, completar su perfil).
  Future<bool> _signInAfterRegistration(
    BuildContext context,
    String email,
    String password,
  ) async {
    try {
      await LoginUser(
        widget.authRepository,
        _sessionStore,
        widget.sessionStorage,
      )(email: email, password: password);
    } catch (_) {
      return false;
    }
    if (context.mounted) {
      final route = _sessionStore.profile?.role == UserRole.professional
          ? AppRoutes.technicianProfile
          : AppRoutes.home;
      Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
    }
    return true;
  }

  void _goToLogin(BuildContext context) => Navigator.of(context)
      .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);

  /// Aplica la regla de acceso de la ruta (GC-314, `RouteGuard`). Las rutas
  /// protegidas escuchan la sesión: si se cierra o vence mientras están
  /// abiertas, llevan al login. Login y registro no la escuchan, para no
  /// interrumpir el inicio de sesión automático después de registrarse.
  WidgetBuilder _guard(RouteAccess access, WidgetBuilder builder) {
    Widget decide(BuildContext context) {
      final decision = RouteGuard.decide(
        access,
        isAuthenticated: _sessionStore.isAuthenticated,
        role: _sessionStore.profile?.role,
      );
      switch (decision) {
        case RouteDecision.allow:
          return builder(context);
        case RouteDecision.toLogin:
          return const _RedirectTo(AppRoutes.login);
        case RouteDecision.toHome:
          return const _RedirectTo(AppRoutes.home);
      }
    }

    if (access == RouteAccess.public || access == RouteAccess.guestOnly) {
      return decide;
    }
    return (context) => ListenableBuilder(
          listenable: _sessionStore,
          builder: (context, _) => decide(context),
        );
  }

  /// Abre el inicio correspondiente al rol de la cuenta autenticada.
  Widget _sessionPage(BuildContext context) {
    final profile = _sessionStore.profile;
    if (!_sessionStore.isAuthenticated || profile == null) {
      return _loginPage(context);
    }
    if (profile.role == UserRole.client) {
      return _clientDashboardPage(context);
    }
    if (profile.role == UserRole.professional) {
      return _technicianDashboardPage(context);
    }

    return SessionPage(
      store: _sessionStore,
      logoutUser: _logoutUser,
      onLoggedOut: () => _goToLogin(context),
    );
  }

  Future<void> _logoutAndGoToLogin(BuildContext context) async {
    await _logoutUser();
    if (context.mounted) _goToLogin(context);
  }

  Widget _clientDashboardPage(BuildContext context) {
    final profile = _sessionStore.profile!;
    return ClientDashboardPage(
      firstName: profile.firstName,
      onPublishProblem: () =>
          Navigator.of(context).pushNamed(AppRoutes.clientServiceRequest),
      onOpenProfile: () =>
          Navigator.of(context).pushNamed(AppRoutes.clientProfile),
      onLogout: () => _logoutAndGoToLogin(context),
    );
  }

  Widget _clientServiceRequestPage(BuildContext context) {
    return ServiceRequestPage(
      onBack: () => Navigator.of(context).maybePop(),
      onOpenHome: () =>
          Navigator.of(context).pushReplacementNamed(AppRoutes.clientDashboard),
      onOpenProfile: () =>
          Navigator.of(context).pushReplacementNamed(AppRoutes.clientProfile),
    );
  }

  Widget _clientProfilePage(BuildContext context) {
    final profile = _sessionStore.profile;
    if (!_sessionStore.isAuthenticated ||
        profile == null ||
        profile.role != UserRole.client) {
      return _loginPage(context);
    }
    return ClientProfilePage(
      firstName: profile.firstName,
      lastName: profile.lastName,
      email: profile.email,
      phone: profile.phone,
      onBack: () => Navigator.of(context).maybePop(),
      onOpenHome: () =>
          Navigator.of(context).pushReplacementNamed(AppRoutes.clientDashboard),
      onOpenPublish: () => Navigator.of(context)
          .pushReplacementNamed(AppRoutes.clientServiceRequest),
      onSaved: (ClientProfileUpdate update) {
        _sessionStore.updateProfile(
          profile.copyWith(
            firstName: update.firstName,
            lastName: update.lastName,
            phone: update.phone,
          ),
        );
      },
    );
  }

  Widget _technicianDashboardPage(BuildContext context) {
    final profile = _sessionStore.profile!;
    return _TechnicianDashboardLoader(
      getProfile: GetTechnicianProfile(widget.technicianProfileRepository),
      firstName: profile.firstName,
      onOpenSettings: () =>
          Navigator.of(context).pushNamed(AppRoutes.technicianProfile),
      onOpenOpportunities: () =>
          Navigator.of(context).pushNamed(AppRoutes.technicianOpportunities),
      onOpenSpecialties: () =>
          Navigator.of(context).pushNamed(AppRoutes.technicianSpecialties),
      onLogout: () => _logoutAndGoToLogin(context),
      onSessionExpired: () {
        _sessionStore.clear();
        _goToLogin(context);
      },
    );
  }

  Widget _technicianOpportunitiesPage(BuildContext context) {
    return TechnicianOpportunitiesPage(
      listOpportunities: widget.listOpportunities,
      applyToServiceRequest: widget.applyToServiceRequest,
      onSessionExpired: () {
        _sessionStore.clear();
        _goToLogin(context);
      },
      onBack: () => Navigator.of(context).maybePop(),
      onOpenHome: () => Navigator.of(context)
          .pushReplacementNamed(AppRoutes.technicianDashboard),
      onOpenSpecialties: () => Navigator.of(context)
          .pushReplacementNamed(AppRoutes.technicianSpecialties),
      onOpenProfile: () => Navigator.of(context)
          .pushReplacementNamed(AppRoutes.technicianProfile),
    );
  }

  Widget _technicianProfilePage(BuildContext context) {
    final profile = _sessionStore.profile!;
    final repository = widget.technicianProfileRepository;
    return TechnicianProfilePage(
      getProfile: GetTechnicianProfile(repository),
      updateProfile: UpdateTechnicianProfile(repository),
      firstName: profile.firstName,
      onBack: () => Navigator.of(context).maybePop(),
      onOpenHome: () => Navigator.of(context)
          .pushReplacementNamed(AppRoutes.technicianDashboard),
      onOpenOpportunities: () => Navigator.of(context)
          .pushReplacementNamed(AppRoutes.technicianOpportunities),
      onLogout: () => _logoutAndGoToLogin(context),
      onSessionExpired: () {
        _sessionStore.clear();
        _goToLogin(context);
      },
    );
  }

  Widget _loginPage(BuildContext context) {
    // Con una sesión ya iniciada (por ejemplo, restaurada) no se pide login.
    if (_sessionStore.isAuthenticated) return _sessionPage(context);
    return LoginPage(
      loginUser: LoginUser(
        widget.authRepository,
        _sessionStore,
        widget.sessionStorage,
      ),
      onLoggedIn: () => Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.home,
        (_) => false,
      ),
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
          ApiConfig.devFlowSandbox ? AppRoutes.devFlowSandbox : AppRoutes.home,
      routes: {
        AppRoutes.devFlowSandbox: (context) => FlowSandboxPage(
              onBack: () => Navigator.of(context)
                  .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false),
            ),
        // El inicio autenticado se selecciona según el rol de la cuenta.
        AppRoutes.home: (context) => _sessionStore.isAuthenticated
            ? _sessionPage(context)
            : HomePage(
                onRegisterClient: () => Navigator.of(context)
                    .pushNamed(AppRoutes.clientRegistration),
                onRegisterTechnician: () => Navigator.of(context)
                    .pushNamed(AppRoutes.technicianRegistration),
                onLogin: () => Navigator.of(context).pushNamed(AppRoutes.login),
              ),
        AppRoutes.login: _guard(RouteAccess.guestOnly, _loginPage),
        // Sin sesión no se muestra la cuenta: la ruta cae en el login.
        AppRoutes.session: _guard(RouteAccess.authenticated, _sessionPage),
        AppRoutes.technicianProfile:
            _guard(RouteAccess.professional, _technicianProfilePage),
        AppRoutes.clientRegistration: _guard(
            RouteAccess.guestOnly,
            (context) => RegistrationPage(
                  registerAccount:
                      RegisterAccount(widget.clientRegistrationRepository),
                  onGoToLogin: () => Navigator.of(context)
                      .pushReplacementNamed(AppRoutes.login),
                  onSwitchRole: () => Navigator.of(context)
                      .pushReplacementNamed(AppRoutes.technicianRegistration),
                )),
        AppRoutes.technicianRegistration: _guard(
            RouteAccess.guestOnly,
            (context) => RegistrationPage(
                  role: AccountRole.technician,
                  // Paso 1 → paso 2 sin volver a escribir la contraseña.
                  onAutoLogin: (email, password) =>
                      _signInAfterRegistration(context, email, password),
                  registerAccount:
                      RegisterAccount(widget.technicianRegistrationRepository),
                  onGoToLogin: () => Navigator.of(context)
                      .pushReplacementNamed(AppRoutes.login),
                  onSwitchRole: () => Navigator.of(context)
                      .pushReplacementNamed(AppRoutes.clientRegistration),
                )),
        AppRoutes.clientDashboard:
            _guard(RouteAccess.client, _clientDashboardPage),
        AppRoutes.technicianDashboard:
            _guard(RouteAccess.professional, _technicianDashboardPage),
        AppRoutes.clientProfile: _guard(RouteAccess.client, _clientProfilePage),
        AppRoutes.clientServiceRequest:
            _guard(RouteAccess.client, _clientServiceRequestPage),
        AppRoutes.technicianOpportunities:
            _guard(RouteAccess.professional, _technicianOpportunitiesPage),
        AppRoutes.technicianSpecialties:
            _guard(RouteAccess.professional, _technicianSpecialtiesPage),
      },
      // Una URL que no existe lleva al inicio en vez de mostrar un error.
      onUnknownRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const _RedirectTo(AppRoutes.home),
      ),
    );
  }
}

/// Reemplaza la ruta actual por [route] apenas se dibuja el primer cuadro.
class _RedirectTo extends StatefulWidget {
  const _RedirectTo(this.route);

  final String route;

  @override
  State<_RedirectTo> createState() => _RedirectToState();
}

class _RedirectToState extends State<_RedirectTo> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Si otra acción ya navegó (por ejemplo, cerrar sesión lleva al login
      // al mismo tiempo), no se navega dos veces.
      if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
      Navigator.of(context).pushNamedAndRemoveUntil(widget.route, (_) => false);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}

class _TechnicianDashboardLoader extends StatefulWidget {
  const _TechnicianDashboardLoader({
    required this.getProfile,
    required this.firstName,
    required this.onOpenSettings,
    required this.onOpenOpportunities,
    required this.onOpenSpecialties,
    required this.onLogout,
    required this.onSessionExpired,
  });

  final GetTechnicianProfile getProfile;
  final String firstName;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenOpportunities;
  final VoidCallback onOpenSpecialties;
  final VoidCallback onLogout;
  final VoidCallback onSessionExpired;

  @override
  State<_TechnicianDashboardLoader> createState() =>
      _TechnicianDashboardLoaderState();
}

class _TechnicianDashboardLoaderState
    extends State<_TechnicianDashboardLoader> {
  late Future<TechnicianProfile> _profileFuture;
  bool _sessionExpiryHandled = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.getProfile();
  }

  void _retry() {
    setState(() {
      _sessionExpiryHandled = false;
      _profileFuture = widget.getProfile();
    });
  }

  void _handleExpiredSession() {
    if (_sessionExpiryHandled) return;
    _sessionExpiryHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onSessionExpired();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TechnicianProfile>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          if (error is TechnicianProfileFailure && error.isSessionExpired) {
            _handleExpiredSession();
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final message = error is TechnicianProfileFailure
              ? error.message
              : 'No pudimos cargar tu inicio. Inténtalo de nuevo.';
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_outlined,
                          size: 48,
                          color: FixiaColors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(message, textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _retry,
                          child: const Text('Reintentar'),
                        ),
                        TextButton(
                          onPressed: widget.onLogout,
                          child: const Text('Cerrar sesión'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        final verificationStatus =
            snapshot.data?.verificationStatus ?? VerificationStatus.pending;
        return TechnicianDashboardPage(
          firstName: widget.firstName,
          verificationStatus: verificationStatus,
          onOpenSettings: widget.onOpenSettings,
          onOpenOpportunities: widget.onOpenOpportunities,
          onOpenSpecialties: widget.onOpenSpecialties,
          onLogout: widget.onLogout,
        );
      },
    );
  }
}
