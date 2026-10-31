import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/auth/login/application/route_guard.dart';
import 'package:ms_frontend/features/auth/login/domain/user_profile.dart';

RouteDecision _decide(RouteAccess access, UserRole? role,
        {bool authenticated = true}) =>
    RouteGuard.decide(access, isAuthenticated: authenticated, role: role);

void main() {
  test('la página de inicio es pública', () {
    expect(_decide(RouteAccess.public, null, authenticated: false),
        RouteDecision.allow);
    expect(_decide(RouteAccess.public, UserRole.client), RouteDecision.allow);
  });

  test('login y registro son solo para visitantes', () {
    expect(_decide(RouteAccess.guestOnly, null, authenticated: false),
        RouteDecision.allow);
    for (final role in [...UserRole.values, null]) {
      expect(_decide(RouteAccess.guestOnly, role), RouteDecision.toHome);
    }
  });

  test('sin sesión, toda ruta protegida lleva al login', () {
    for (final access in [
      RouteAccess.authenticated,
      RouteAccess.client,
      RouteAccess.professional,
    ]) {
      expect(
          _decide(access, null, authenticated: false), RouteDecision.toLogin);
    }
  });

  test('cada rol solo entra a lo suyo', () {
    expect(_decide(RouteAccess.client, UserRole.client), RouteDecision.allow);
    expect(_decide(RouteAccess.client, UserRole.professional),
        RouteDecision.toHome);
    expect(_decide(RouteAccess.professional, UserRole.professional),
        RouteDecision.allow);
    expect(_decide(RouteAccess.professional, UserRole.client),
        RouteDecision.toHome);
  });

  test('la empresa solo entra a sus rutas y nadie más entra a las de empresa',
      () {
    expect(_decide(RouteAccess.company, UserRole.company), RouteDecision.allow);
    expect(_decide(RouteAccess.client, UserRole.company), RouteDecision.toHome);
    expect(_decide(RouteAccess.professional, UserRole.company),
        RouteDecision.toHome);
    for (final role in [UserRole.client, UserRole.professional]) {
      expect(_decide(RouteAccess.company, role), RouteDecision.toHome);
    }
    expect(_decide(RouteAccess.company, null, authenticated: false),
        RouteDecision.toLogin);
  });

  test('un administrador o un rol desconocido no entra a rutas de rol', () {
    for (final role in [UserRole.admin, null]) {
      expect(_decide(RouteAccess.client, role), RouteDecision.toHome);
      expect(_decide(RouteAccess.professional, role), RouteDecision.toHome);
      expect(_decide(RouteAccess.company, role), RouteDecision.toHome);
      expect(_decide(RouteAccess.authenticated, role), RouteDecision.allow);
    }
  });
}
