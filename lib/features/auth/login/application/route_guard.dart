import '../domain/user_profile.dart';

/// Quién puede abrir una ruta (GC-314).
enum RouteAccess {
  /// Cualquiera, con o sin sesión (página de inicio).
  public,

  /// Solo sin sesión (login y registro): con sesión se va al inicio del rol.
  guestOnly,

  /// Cualquier cuenta autenticada.
  authenticated,

  /// Solo clientes.
  client,

  /// Solo técnicos.
  professional,
}

/// Qué hacer al intentar abrir una ruta.
enum RouteDecision {
  /// Mostrar la ruta.
  allow,

  /// Ir al login: hace falta iniciar sesión.
  toLogin,

  /// Ir al inicio: la ruta no es para esta cuenta (otro rol, o ya tiene
  /// sesión y la ruta es solo para visitantes).
  toHome,
}

/// Regla única de navegación por rol (GC-314).
///
/// Es la única fuente de verdad de qué rol ve qué ruta: la app la aplica a
/// todas las rutas, así que un usuario no puede abrir desde la interfaz (ni
/// escribiendo la URL) vistas o acciones de otro rol. La autorización real
/// la vuelve a validar el backend en cada llamada.
abstract final class RouteGuard {
  static RouteDecision decide(
    RouteAccess access, {
    required bool isAuthenticated,
    required UserRole? role,
  }) {
    switch (access) {
      case RouteAccess.public:
        return RouteDecision.allow;
      case RouteAccess.guestOnly:
        return isAuthenticated ? RouteDecision.toHome : RouteDecision.allow;
      case RouteAccess.authenticated:
        return isAuthenticated ? RouteDecision.allow : RouteDecision.toLogin;
      case RouteAccess.client:
        return _forRole(UserRole.client, isAuthenticated, role);
      case RouteAccess.professional:
        return _forRole(UserRole.professional, isAuthenticated, role);
    }
  }

  static RouteDecision _forRole(
    UserRole required,
    bool isAuthenticated,
    UserRole? role,
  ) {
    if (!isAuthenticated) return RouteDecision.toLogin;
    return role == required ? RouteDecision.allow : RouteDecision.toHome;
  }
}
