import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'core/config/api_config.dart';
import 'core/http/authorized_http.dart';
import 'core/theme/fixia_theme.dart';
import 'features/auth/login/application/login_user.dart';
import 'features/auth/login/application/logout_user.dart';
import 'features/auth/login/application/ports/auth_repository.dart';
import 'features/auth/login/application/ports/session_storage.dart';
import 'features/auth/login/application/refresh_session.dart';
import 'features/auth/login/application/follow_shared_session.dart';
import 'features/auth/login/application/restore_session.dart';
import 'features/auth/login/application/route_guard.dart';
import 'features/auth/login/application/session_store.dart';
import 'features/auth/login/infrastructure/http_auth_repository.dart';
import 'features/auth/login/infrastructure/browser_key_value_store.dart';
import 'features/auth/login/infrastructure/browser_session_storage.dart';
import 'features/auth/login/infrastructure/open_tabs.dart';
import 'features/auth/login/presentation/login_page.dart';
import 'features/auth/login/presentation/session_page.dart';
import 'features/auth/registration/application/ports/account_registration_repository.dart';
import 'features/auth/registration/application/register_account.dart';
import 'features/auth/registration/domain/account_role.dart';
import 'features/auth/registration/infrastructure/http_account_registration_repository.dart';
import 'features/auth/registration/presentation/registration_page.dart';
import 'features/auth/login/domain/user_profile.dart';
import 'features/client/dashboard/presentation/client_dashboard_page.dart';
import 'features/client/profile/application/client_profile_use_cases.dart';
import 'features/client/profile/domain/client_profile.dart';
import 'features/client/profile/domain/client_profile_exceptions.dart';
import 'features/client/profile/domain/client_profile_update.dart';
import 'features/client/profile/presentation/client_profile_page.dart';
import 'features/client/service_request/domain/service_request_draft.dart';
import 'features/client/service_request/presentation/service_request_page.dart';
import 'features/client/service_requests/application/service_request_use_cases.dart';
import 'features/client/service_requests/domain/service_request.dart';
import 'features/client/service_requests/domain/service_request_exceptions.dart';
import 'backend_integrations.dart';
import 'features/home/presentation/home_page.dart';
import 'features/technician/dashboard/presentation/technician_dashboard_page.dart';
import 'features/technician/applications/application/application_use_cases.dart';
import 'features/technician/applications/domain/application_exceptions.dart';
import 'features/technician/opportunities/application/list_compatible_opportunities.dart';
import 'features/technician/opportunities/domain/opportunity_exceptions.dart';
import 'features/technician/opportunities/domain/service_opportunity.dart';
import 'features/technician/opportunities/presentation/opportunity_view.dart';
import 'features/technician/opportunities/presentation/technician_opportunities_page.dart';
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
  static const clientDashboard = '/cliente/inicio';
  static const technicianDashboard = '/tecnico/inicio';

  /// Rutas anteriores de los paneles, cuando se llamaban «demo». Ya no se
  /// anuncian, pero siguen abriendo el inicio del rol para no romper enlaces
  /// ni marcadores guardados (GC-315).
  static const legacyClientDashboard = '/demo/inicio-cliente';
  static const legacyTechnicianDashboard = '/demo/inicio-tecnico';
  static const clientServiceRequest = '/cliente/publicar-problema';
  static const technicianOpportunities = '/tecnico/solicitudes';
  static const technicianSpecialties = '/tecnico/especialidades';
  static const clientProfile = '/cliente/perfil';
  static const technicianProfile = '/tecnico/perfil';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final httpClient = http.Client();
  final usersApiBaseUrl = Uri.parse(ApiConfig.usersBaseUrl);
  final authRepository = HttpAuthRepository(
    client: httpClient,
    baseUrl: usersApiBaseUrl,
  );
  final openTabs = OpenTabs(persistentKeyValueStore());
  final sessionStorage = BrowserSessionStorage(
    tab: tabKeyValueStore(),
    shared: persistentKeyValueStore(),
    browserSession: browserSessionKeyValueStore(),
    openTabs: openTabs,
  );

  // Si hay una sesión en el navegador (otra pestaña, una recarga o "Mantener
  // sesión iniciada"), se restaura antes de mostrar la primera pantalla.
  final sessionStore = SessionStore();
  await RestoreSession(authRepository, sessionStore, sessionStorage)();
  _keepTabAlive(openTabs);

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
      backend: BackendIntegrations.http(
        client: httpClient,
        usersBaseUrl: usersApiBaseUrl,
        servicesBaseUrl: Uri.parse(ApiConfig.servicesBaseUrl),
        authorizedHttp: AuthorizedHttp(
          accessToken: () => sessionStore.session?.accessToken,
          renewSession: RefreshSession(
            authRepository,
            sessionStore,
            sessionStorage,
          ).renew,
        ),
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
      sessionChangesFromOtherTabs:
          sharedSessionChanges(BrowserSessionStorage.sessionIdKey),
    ),
  );
}

/// Sin "Mantener sesión iniciada", la sesión dura mientras quede abierta
/// alguna pestaña de Fixia: esta pestaña avisa que sigue abierta y, al
/// cerrarse, deja de contar (GC-394). Si el navegador bloquea el
/// almacenamiento, no se hace nada.
void _keepTabAlive(OpenTabs openTabs) {
  void quietly(void Function() action) {
    try {
      action();
    } catch (_) {
      // Sin `localStorage` no hay sesión compartida que mantener.
    }
  }

  quietly(openTabs.markAlive);
  Timer.periodic(OpenTabs.heartbeat, (_) => quietly(openTabs.markAlive));
  onTabClosed(
    () => quietly(openTabs.markClosed),
    () => quietly(openTabs.markAlive),
  );
}

class FixiaApp extends StatefulWidget {
  const FixiaApp({
    super.key,
    this.backend,
    required this.clientRegistrationRepository,
    required this.technicianRegistrationRepository,
    required this.technicianProfileRepository,
    required this.authRepository,
    required this.sessionStorage,
    this.technicianSpecialtiesRepository,
    this.sessionStore,
    this.sessionChangesFromOtherTabs,
  });

  /// Conexión de perfil del cliente, solicitudes, oportunidades y
  /// postulaciones con el backend. Si es `null`, esas pantallas usan datos de
  /// demostración.
  final BackendIntegrations? backend;

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

  /// Avisa cuando otra pestaña inicia o cierra sesión: la sesión es una sola
  /// en todo el navegador y esta pestaña la sigue (GC-394).
  final Stream<void>? sessionChangesFromOtherTabs;

  @override
  State<FixiaApp> createState() => _FixiaAppState();
}

class _FixiaAppState extends State<FixiaApp> {
  late final SessionStore _sessionStore = widget.sessionStore ?? SessionStore();

  /// Ruta protegida que un visitante intentó abrir sin sesión (GC-315). Tras
  /// iniciar sesión se vuelve a ella; si no es para su rol, la guarda de la
  /// propia ruta lo lleva a su inicio.
  String? _returnTo;

  /// Hubo una sesión que ya terminó (cierre o vencimiento). Entonces no se
  /// recuerda la ruta que se estaba viendo: otra persona podría ingresar después
  /// y no debe heredar el destino de la anterior.
  bool _sessionEnded = false;
  bool _wasAuthenticated = false;

  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<void>? _otherTabs;
  late final _followSharedSession = FollowSharedSession(
    widget.authRepository,
    _sessionStore,
    widget.sessionStorage,
  );

  @override
  void initState() {
    super.initState();
    _wasAuthenticated = _sessionStore.isAuthenticated;
    _sessionStore.addListener(_onSessionChanged);
    _otherTabs =
        widget.sessionChangesFromOtherTabs?.listen((_) => _followOtherTabs());
  }

  /// Otra pestaña inició o cerró sesión: esta pestaña queda con la misma
  /// sesión. Si se cerró, va al login; si ahora es otra cuenta, a su inicio.
  Future<void> _followOtherTabs() async {
    final change = await _followSharedSession();
    final navigator = _navigatorKey.currentState;
    if (!mounted || navigator == null) return;
    switch (change) {
      case SharedSessionChange.sameAccount:
        return;
      case SharedSessionChange.signedOut:
        _returnTo = null;
        navigator.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
      case SharedSessionChange.otherAccount:
        _returnTo = null;
        navigator.pushNamedAndRemoveUntil(_accountHome, (_) => false);
    }
  }

  void _onSessionChanged() {
    final authenticated = _sessionStore.isAuthenticated;
    if (authenticated) {
      _sessionEnded = false;
    } else if (_wasAuthenticated) {
      _sessionEnded = true;
      _returnTo = null;
    }
    _wasAuthenticated = authenticated;
  }

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
    _otherTabs?.cancel();
    _sessionStore.removeListener(_onSessionChanged);
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
    _returnTo = null;
    if (context.mounted) {
      final route = _sessionStore.profile?.role == UserRole.professional
          ? AppRoutes.technicianProfile
          : _accountHome;
      Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
    }
    return true;
  }

  void _goToLogin(BuildContext context) => Navigator.of(context)
      .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);

  /// Inicio de la cuenta con sesión según su rol. La raíz (`/`) es siempre
  /// la página de bienvenida, también con sesión iniciada.
  String get _accountHome => switch (_sessionStore.profile?.role) {
        UserRole.client => AppRoutes.clientDashboard,
        UserRole.professional => AppRoutes.technicianDashboard,
        _ => AppRoutes.session,
      };

  /// Después de iniciar sesión: al inicio del rol y, si el visitante había
  /// pedido una ruta protegida, a esa ruta (GC-315). La guarda de la ruta
  /// decide si es para su rol; si no, queda en su inicio.
  void _goAfterLogin(BuildContext context) {
    final target = _returnTo;
    _returnTo = null;
    final navigator = Navigator.of(context);
    final home = _accountHome;
    navigator.pushNamedAndRemoveUntil(home, (_) => false);
    if (target != null && target != AppRoutes.home && target != home) {
      navigator.pushNamed(target);
    }
  }

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
          // Un visitante que pide una ruta protegida vuelve a ella al ingresar.
          if (!_sessionEnded) _returnTo = ModalRoute.of(context)?.settings.name;
          return const _RedirectTo(AppRoutes.login);
        case RouteDecision.toHome:
          return _RedirectTo(_accountHome);
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
    final backend = widget.backend;
    return ServiceRequestPage(
      publish: backend == null
          ? null
          : (draft) => _publishServiceRequest(context, backend, draft),
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
    final backend = widget.backend;
    if (backend == null) return _clientProfileView(context, profile, null);
    // Los datos se cargan del servidor: la sesión no siempre trae el teléfono
    // y, como es obligatorio, sin él no se podría guardar ningún cambio.
    return _ClientProfileLoader(
      load: () => GetClientProfile(backend.clientProfile)(),
      onSessionExpired: () => _endExpiredSession(context),
      builder: (context, saved) => _clientProfileView(
        context,
        saved == null
            ? profile
            : profile.copyWith(
                firstName: saved.firstName,
                lastName: saved.lastName,
                phone: saved.phone,
              ),
        backend,
      ),
    );
  }

  Widget _clientProfileView(
    BuildContext context,
    UserProfile profile,
    BackendIntegrations? backend,
  ) {
    return ClientProfilePage(
      saveProfile: backend == null
          ? null
          : (update) => _saveClientProfile(context, backend, update),
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
    final backend = widget.backend;
    return TechnicianOpportunitiesPage(
      loadOpportunities:
          backend == null ? null : () => _loadOpportunities(context, backend),
      applyTo: backend == null
          ? null
          : (id) => _applyToOpportunity(context, backend, id),
      onBack: () => Navigator.of(context).maybePop(),
      onOpenHome: () => Navigator.of(context)
          .pushReplacementNamed(AppRoutes.technicianDashboard),
      onOpenSpecialties: () => Navigator.of(context)
          .pushReplacementNamed(AppRoutes.technicianSpecialties),
      onOpenProfile: () => Navigator.of(context)
          .pushReplacementNamed(AppRoutes.technicianProfile),
    );
  }

  /// GC-320: guarda nombre, apellido y teléfono del cliente en ms-users.
  Future<void> _saveClientProfile(
    BuildContext context,
    BackendIntegrations backend,
    ClientProfileUpdate update,
  ) async {
    try {
      await UpdateClientProfile(backend.clientProfile)(update);
    } on ClientProfileFailure catch (failure) {
      if (failure.isSessionExpired && context.mounted) {
        _endExpiredSession(context);
      }
      throw _UserMessage(
        failure.fieldErrors.isEmpty
            ? failure.message
            : failure.fieldErrors.values.join(' '),
      );
    }
  }

  /// GC-335: publica la solicitud del cliente en ms-services.
  Future<void> _publishServiceRequest(
    BuildContext context,
    BackendIntegrations backend,
    ServiceRequestDraft draft,
  ) async {
    try {
      await PublishServiceRequest(backend.serviceRequests)(
        NewServiceRequest(
          category: draft.category,
          description: draft.description,
          approximateLocation: ApproximateLocation(
            city: draft.city,
            zone: draft.zone,
          ),
          expectedAt: draft.expectedAt,
        ),
      );
    } on ServiceRequestFailure catch (failure) {
      if (failure.isSessionExpired && context.mounted) {
        _endExpiredSession(context);
      }
      throw _UserMessage(
        failure.fieldErrors.isEmpty
            ? failure.message
            : failure.fieldErrors.values.join(' '),
      );
    }
  }

  /// GC-340: solicitudes compatibles con el técnico, desde ms-services.
  Future<List<ServiceOpportunity>> _loadOpportunities(
    BuildContext context,
    BackendIntegrations backend,
  ) async {
    try {
      final page = await ListCompatibleOpportunities(backend.opportunities)();
      return [for (final item in page.items) opportunityView(item)];
    } on OpportunityFailure catch (failure) {
      if (failure.isSessionExpired && context.mounted) {
        _endExpiredSession(context);
      }
      throw _UserMessage(failure.message);
    }
  }

  /// GC-345: postulación del técnico a una solicitud, en ms-services.
  Future<void> _applyToOpportunity(
    BuildContext context,
    BackendIntegrations backend,
    String opportunityId,
  ) async {
    try {
      await ApplyToServiceRequest(backend.applications)(opportunityId);
    } on ApplicationFailure catch (failure) {
      if (failure.isSessionExpired && context.mounted) {
        _endExpiredSession(context);
      }
      throw _UserMessage(
        failure.reasons.isEmpty
            ? failure.message
            : failure.reasons.map((reason) => reason.message).join(' '),
      );
    }
  }

  /// La sesión venció mientras se usaba una pantalla: se vuelve al login.
  void _endExpiredSession(BuildContext context) {
    _sessionStore.clear();
    _goToLogin(context);
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
      onLoggedIn: () => _goAfterLogin(context),
      onGoToRegistration: () => Navigator.of(context)
          .pushReplacementNamed(AppRoutes.clientRegistration),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Fixia',
      debugShowCheckedModeBanner: false,
      theme: FixiaTheme.light,
      initialRoute: AppRoutes.home,
      routes: {
        // La bienvenida se ve siempre, también con sesión iniciada (por
        // ejemplo, al abrir otra pestaña). Con sesión, «Iniciar sesión» lleva
        // directo al inicio de la cuenta en vez de pedir las credenciales.
        AppRoutes.home: (context) => HomePage(
              onRegisterClient: () =>
                  Navigator.of(context).pushNamed(AppRoutes.clientRegistration),
              onRegisterTechnician: () => Navigator.of(context)
                  .pushNamed(AppRoutes.technicianRegistration),
              onLogin: () => _sessionStore.isAuthenticated
                  ? Navigator.of(context).pushNamed(_accountHome)
                  : Navigator.of(context).pushNamed(AppRoutes.login),
            ),
        AppRoutes.login: _guard(RouteAccess.guestOnly, _loginPage),
        // Sin sesión no se muestra la cuenta: la ruta cae en el login.
        AppRoutes.session: _guard(RouteAccess.authenticated, _sessionPage),
        AppRoutes.technicianProfile:
            _guard(RouteAccess.professional, _technicianProfilePage),
        AppRoutes.clientRegistration: _guard(
            RouteAccess.guestOnly,
            (context) => RegistrationPage(
                  // Como el técnico: tras crear la cuenta se inicia sesión.
                  onAutoLogin: (email, password) =>
                      _signInAfterRegistration(context, email, password),
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
        // Rutas anteriores («demo»): llevan al inicio del rol, o al login.
        AppRoutes.legacyClientDashboard:
            _guard(RouteAccess.authenticated, (_) => _RedirectTo(_accountHome)),
        AppRoutes.legacyTechnicianDashboard:
            _guard(RouteAccess.authenticated, (_) => _RedirectTo(_accountHome)),
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
      // Una URL que no existe lleva al inicio (el de la cuenta, con sesión)
      // en vez de mostrar un error.
      onUnknownRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => _RedirectTo(
          _sessionStore.isAuthenticated ? _accountHome : AppRoutes.home,
        ),
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

/// Error con un texto listo para mostrarle al usuario.
class _UserMessage implements Exception {
  const _UserMessage(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Carga el perfil del cliente del servidor antes de mostrar la pantalla
/// (GC-320). Si no se puede cargar, la pantalla abre con los datos de la
/// sesión; si la sesión venció, se vuelve al login.
class _ClientProfileLoader extends StatefulWidget {
  const _ClientProfileLoader({
    required this.load,
    required this.onSessionExpired,
    required this.builder,
  });

  final Future<ClientProfile> Function() load;
  final VoidCallback onSessionExpired;
  final Widget Function(BuildContext context, ClientProfile? saved) builder;

  @override
  State<_ClientProfileLoader> createState() => _ClientProfileLoaderState();
}

class _ClientProfileLoaderState extends State<_ClientProfileLoader> {
  ClientProfile? _saved;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    ClientProfile? saved;
    try {
      saved = await widget.load();
    } on ClientProfileFailure catch (failure) {
      if (failure.isSessionExpired) {
        if (mounted) widget.onSessionExpired();
        return;
      }
    } catch (_) {
      // Sin conexión u otro error: se usan los datos de la sesión.
    }
    if (mounted) {
      setState(() {
        _saved = saved;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            key: ValueKey('client-profile-loading'),
          ),
        ),
      );
    }
    return widget.builder(context, _saved);
  }
}
