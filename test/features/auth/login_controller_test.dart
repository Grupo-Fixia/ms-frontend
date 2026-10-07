import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/auth/application/login_user.dart';
import 'package:ms_frontend/features/auth/application/session_store.dart';
import 'package:ms_frontend/features/auth/domain/auth_exceptions.dart';
import 'package:ms_frontend/features/auth/presentation/login_controller.dart';

import 'fake_auth_repository.dart';

LoginController _controller(FakeAuthRepository repository) =>
    LoginController(
      loginUser: LoginUser(repository, SessionStore(), FakeSessionStorage()),
    );

void main() {
  test('"mantener sesión" parte desmarcado y avisa al cambiar', () {
    final controller = _controller(FakeAuthRepository());
    var notified = 0;
    controller.addListener(() => notified++);

    expect(controller.rememberSession, isFalse);
    controller.setRememberSession(true);
    controller.setRememberSession(true); // sin cambio: no notifica

    expect(controller.rememberSession, isTrue);
    expect(notified, 1);
  });

  test('envía "mantener sesión" al iniciar sesión', () async {
    final storage = FakeSessionStorage();
    final controller = LoginController(
      loginUser: LoginUser(FakeAuthRepository(), SessionStore(), storage),
    )..setRememberSession(true);

    await controller.login(email: 'ana@fixia.com', password: 'Segura123');

    expect(storage.refreshToken, fixtureSession.refreshToken);
  });

  test('un login correcto devuelve true y no deja error', () async {
    final repository = FakeAuthRepository();
    final controller = _controller(repository);

    final result = await controller.login(
      email: '  ana@fixia.com ',
      password: 'Segura123',
    );

    expect(result, isTrue);
    expect(controller.isSubmitting, isFalse);
    expect(controller.errorMessage, isNull);
    expect(repository.lastEmail, 'ana@fixia.com');
  });

  test('un rechazo del backend devuelve false con el mensaje y los campos',
      () async {
    final controller = _controller(
      FakeAuthRepository(
        loginFailure: const AuthFailure(
          'Credenciales inválidas',
          fieldErrors: {'email': 'El correo no es válido'},
        ),
      ),
    );

    final result = await controller.login(email: 'x', password: 'y');

    expect(result, isFalse);
    expect(controller.isSubmitting, isFalse);
    expect(controller.errorMessage, 'Credenciales inválidas');
    expect(controller.fieldError('email'), 'El correo no es válido');
  });

  test('clearFieldError descarta solo el error de ese campo y avisa', () async {
    final controller = _controller(
      FakeAuthRepository(
        loginFailure: const AuthFailure(
          'Revisa los datos',
          fieldErrors: {'email': 'a', 'password': 'b'},
        ),
      ),
    );
    await controller.login(email: 'x', password: 'y');
    var notified = 0;
    controller.addListener(() => notified++);

    controller.clearFieldError('email');
    controller.clearFieldError('email'); // ya no existe: no notifica

    expect(controller.fieldError('email'), isNull);
    expect(controller.fieldError('password'), 'b');
    expect(notified, 1);
  });

  test('un nuevo intento limpia el error anterior', () async {
    final repository = FakeAuthRepository(
      loginFailure: const AuthFailure(
        'Credenciales inválidas',
        fieldErrors: {'email': 'a'},
      ),
    );
    final controller = _controller(repository);
    await controller.login(email: 'x', password: 'y');
    expect(controller.errorMessage, isNotNull);

    repository.loginFailure = null;
    final result = await controller.login(email: 'ana@fixia.com', password: 'z');

    expect(result, isTrue);
    expect(controller.errorMessage, isNull);
    expect(controller.fieldError('email'), isNull);
  });

  test('ignora un segundo envío mientras el primero sigue en curso', () async {
    final pending = Completer<void>();
    final repository = FakeAuthRepository(pendingLogin: pending);
    final controller = _controller(repository);

    final first = controller.login(email: 'ana@fixia.com', password: 'a');
    expect(controller.isSubmitting, isTrue);
    final second = await controller.login(email: 'ana@fixia.com', password: 'a');
    pending.complete();
    await first;

    expect(second, isFalse);
    expect(repository.loginCalls, 1);
    expect(controller.isSubmitting, isFalse);
  });
}
