/// Configuración de la API, fijada al compilar con `--dart-define`.
abstract final class ApiConfig {
  /// URL base de ms-users. Por defecto, el origen que sirve Traefik; el
  /// `Dockerfile` la sobrescribe con `USERS_API_BASE_URL`.
  static const usersBaseUrl = String.fromEnvironment(
    'USERS_API_BASE_URL',
    defaultValue: 'http://localhost',
  );

  /// URL base de ms-services (`/api/services/...`). Por defecto es la misma
  /// de ms-users, porque el gateway enruta ambos por prefijo desde el mismo
  /// origen; se puede cambiar con `SERVICES_API_BASE_URL`.
  static const servicesBaseUrl = String.fromEnvironment(
    'SERVICES_API_BASE_URL',
    defaultValue: usersBaseUrl,
  );

  /// Usa datos locales en lugar de ms-services para oportunidades y
  /// postulaciones (pruebas sin red): `--dart-define=USE_MOCK_APPLICATIONS=true`.
  static const useMockApplications = bool.fromEnvironment(
    'USE_MOCK_APPLICATIONS',
    defaultValue: false,
  );

  /// Abre al iniciar el recorrido E2E de desarrollo (datos locales):
  /// `--dart-define=DEV_FLOW_SANDBOX=true`.
  static const devFlowSandbox = bool.fromEnvironment(
    'DEV_FLOW_SANDBOX',
    defaultValue: false,
  );
}
