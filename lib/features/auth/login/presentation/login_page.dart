import 'package:flutter/material.dart';

import '../../../../core/theme/fixia_theme.dart';
import '../../../../core/validation/email_rule.dart';
import '../application/login_user.dart';
import '../domain/login_rules.dart';
import 'login_controller.dart';

/// Pantalla de inicio de sesión (GC-258, historia GC-236).
class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.loginUser,
    this.onLoggedIn,
    this.onGoToRegistration,
  });

  final LoginUser loginUser;

  /// Se llama cuando la sesión quedó iniciada.
  final VoidCallback? onLoggedIn;

  /// Navega al registro. Si es `null` el enlace no se muestra.
  final VoidCallback? onGoToRegistration;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  late final LoginController _controller;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _controller = LoginController(loginUser: widget.loginUser)
      ..addListener(_refresh);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (_controller.isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    final loggedIn = await _controller.login(
      email: _email.text,
      password: _password.text,
    );
    if (!mounted) return;

    if (loggedIn) {
      widget.onLoggedIn?.call();
      return;
    }
    // Muestra debajo de cada campo los errores que devolvió el backend.
    _formKey.currentState!.validate();
    final message = _controller.errorMessage;
    if (message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Primero el error del backend para ese campo; si no hay, el local.
  FormFieldValidator<String> _validator(
    String field,
    FormFieldValidator<String> local,
  ) =>
      (value) => _controller.fieldError(field) ?? local(value);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: DecoratedBox(
                decoration: FixiaDecorations.card,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: _buildForm(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final isSubmitting = _controller.isSubmitting;
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header(),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TextFormField(
                key: const ValueKey('login-email-field'),
                controller: _email,
                // Cada campo se valida solo cuando el usuario lo toca.
                autovalidateMode: AutovalidateMode.onUserInteraction,
                enabled: !isSubmitting,
                keyboardType: TextInputType.emailAddress,
                maxLength: EmailRule.maxLength,
                autocorrect: false,
                autofillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.next,
                onChanged: (_) => _controller.clearFieldError('email'),
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  counterText: '',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: _validator('email', LoginRules.email),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TextFormField(
                key: const ValueKey('login-password-field'),
                controller: _password,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                enabled: !isSubmitting,
                obscureText: _obscurePassword,
                maxLength: LoginRules.passwordMaxLength,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onChanged: (_) => _controller.clearFieldError('password'),
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  counterText: '',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Mostrar contraseña'
                        : 'Ocultar contraseña',
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: _validator('password', LoginRules.password),
              ),
            ),
            CheckboxListTile(
              key: const ValueKey('login-remember-checkbox'),
              value: _controller.rememberSession,
              enabled: !isSubmitting,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: FixiaColors.secondary,
              onChanged: (checked) =>
                  _controller.setRememberSession(checked ?? false),
              title: Text(
                'Mantener sesión iniciada',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              key: const ValueKey('login-submit'),
              onPressed: isSubmitting ? null : _submit,
              child: isSubmitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: FixiaColors.white,
                      ),
                    )
                  : const Text('Iniciar sesión'),
            ),
            if (widget.onGoToRegistration != null) ...[
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('¿No tienes cuenta?', style: theme.textTheme.bodyMedium),
                  TextButton(
                    key: const ValueKey('login-go-to-registration'),
                    onPressed: isSubmitting ? null : widget.onGoToRegistration,
                    child: const Text('Crear cuenta'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Image.asset(
          'assets/brand/fixia_logo.png',
          height: 48,
          semanticLabel: 'Fixia',
        ),
        const SizedBox(height: 24),
        Text(
          'Inicia sesión',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Ingresa con tu correo y contraseña para continuar.',
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: FixiaColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
