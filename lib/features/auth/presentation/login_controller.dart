import 'package:flutter/foundation.dart';

import '../application/login_user.dart';
import '../domain/auth_exceptions.dart';

/// Estado de la pantalla de inicio de sesión.
class LoginController extends ChangeNotifier {
  LoginController({required LoginUser loginUser}) : _loginUser = loginUser;

  final LoginUser _loginUser;

  bool _isSubmitting = false;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};

  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  /// Error que devolvió el backend para un campo (`email`, `password`).
  String? fieldError(String field) => _fieldErrors[field];

  /// El usuario editó el campo: se descarta el error que vino del backend.
  void clearFieldError(String field) {
    if (!_fieldErrors.containsKey(field)) return;
    _fieldErrors = Map.of(_fieldErrors)..remove(field);
    notifyListeners();
  }

  /// Devuelve `true` si la sesión quedó iniciada. Ignora un segundo envío
  /// mientras el primero sigue en curso.
  Future<bool> login({required String email, required String password}) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    _errorMessage = null;
    _fieldErrors = const {};
    notifyListeners();

    try {
      await _loginUser(email: email.trim(), password: password);
      return true;
    } on AuthFailure catch (failure) {
      _errorMessage = failure.message;
      _fieldErrors = failure.fieldErrors;
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
