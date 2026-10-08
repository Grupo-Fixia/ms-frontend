/// Configuración de la API, fijada al compilar con `--dart-define`.
abstract final class ApiConfig {
  /// URL base de ms-users. Por defecto, el origen que sirve Traefik; el
  /// `Dockerfile` la sobrescribe con `USERS_API_BASE_URL`.
  static const usersBaseUrl = String.fromEnvironment(
    'USERS_API_BASE_URL',
    defaultValue: 'http://localhost',
  );
}
