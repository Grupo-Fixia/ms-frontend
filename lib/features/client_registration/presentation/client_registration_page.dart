import 'package:flutter/material.dart';

import '../../../core/theme/fixia_theme.dart';
import '../application/register_client.dart';
import '../domain/client_registration_rules.dart';
import '../domain/document_type.dart';
import 'client_registration_controller.dart';
import 'widgets/data_consent_field.dart';

/// Formulario de registro de cliente (GC-252, historia GC-234).
class ClientRegistrationPage extends StatefulWidget {
  const ClientRegistrationPage({
    super.key,
    required this.registerClient,
    this.onGoToLogin,
  });

  final RegisterClient registerClient;

  /// Navega al inicio de sesión. Si es `null` el enlace no se muestra.
  final VoidCallback? onGoToLogin;

  @override
  State<ClientRegistrationPage> createState() => _ClientRegistrationPageState();
}

class _ClientRegistrationPageState extends State<ClientRegistrationPage> {
  /// Ancho a partir del cual nombres y apellidos van en la misma fila.
  static const _twoColumnBreakpoint = 480.0;

  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _documentNumber = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  late final ClientRegistrationController _controller;
  DocumentType? _documentType;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _controller = ClientRegistrationController(
      registerClient: widget.registerClient,
    )..addListener(_refresh);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    for (final field in [
      _firstName,
      _lastName,
      _documentNumber,
      _email,
      _phone,
      _password,
      _confirmPassword,
    ]) {
      field.dispose();
    }
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await _controller.register(
      firstName: _firstName.text,
      lastName: _lastName.text,
      documentType: _documentType,
      documentNumber: _documentNumber.text,
      email: _email.text,
      phone: _phone.text,
      password: _password.text,
    );
    if (!mounted) return;

    final message = _controller.errorMessage;
    if (message == null) return;
    // Muestra debajo de cada campo los errores que devolvió el backend.
    _formKey.currentState!.validate();
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

  Widget _textField({
    required String field,
    required TextEditingController controller,
    required String label,
    required FormFieldValidator<String> validator,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
    int? maxLength,
    bool obscureText = false,
    String? helperText,
    Widget? suffixIcon,
    Iterable<String>? autofillHints,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        key: ValueKey('client-$field-field'),
        controller: controller,
        enabled: !_controller.isLocked,
        keyboardType: keyboardType,
        textCapitalization: capitalization,
        maxLength: maxLength,
        obscureText: obscureText,
        autocorrect: false,
        enableSuggestions: !obscureText,
        autofillHints: autofillHints,
        textInputAction: TextInputAction.next,
        onChanged: (_) => _controller.clearFieldError(field),
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          suffixIcon: suffixIcon,
          counterText: '',
        ),
        validator: _validator(field, validator),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: DecoratedBox(
                decoration: FixiaDecorations.card,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: _controller.isRegistered
                      ? _RegistrationSuccess(
                          email: _email.text.trim(),
                          onGoToLogin: widget.onGoToLogin,
                        )
                      : _buildForm(context),
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
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header(),
            const SizedBox(height: 28),
            LayoutBuilder(
              builder: (context, constraints) {
                final names = [
                  _textField(
                    field: 'firstName',
                    controller: _firstName,
                    label: 'Nombres',
                    capitalization: TextCapitalization.words,
                    maxLength: ClientRegistrationRules.nameMaxLength,
                    autofillHints: const [AutofillHints.givenName],
                    validator: ClientRegistrationRules.firstName,
                  ),
                  _textField(
                    field: 'lastName',
                    controller: _lastName,
                    label: 'Apellidos',
                    capitalization: TextCapitalization.words,
                    maxLength: ClientRegistrationRules.nameMaxLength,
                    autofillHints: const [AutofillHints.familyName],
                    validator: ClientRegistrationRules.lastName,
                  ),
                ];
                if (constraints.maxWidth < _twoColumnBreakpoint) {
                  return Column(children: names);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: names[0]),
                    const SizedBox(width: 12),
                    Expanded(child: names[1]),
                  ],
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DropdownButtonFormField<DocumentType>(
                key: const ValueKey('client-documentType-field'),
                value: _documentType,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Tipo de documento'),
                items: [
                  for (final type in DocumentType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: _controller.isLocked
                    ? null
                    : (value) {
                        _controller.clearFieldError('documentType');
                        setState(() => _documentType = value);
                      },
                validator: (value) =>
                    _controller.fieldError('documentType') ??
                    (value == null ? 'Selecciona tu tipo de documento.' : null),
              ),
            ),
            _textField(
              field: 'documentNumber',
              controller: _documentNumber,
              label: 'Número de documento',
              capitalization: TextCapitalization.characters,
              maxLength: ClientRegistrationRules.documentMaxLength,
              validator: ClientRegistrationRules.documentNumber,
            ),
            _textField(
              field: 'email',
              controller: _email,
              label: 'Correo electrónico',
              keyboardType: TextInputType.emailAddress,
              maxLength: ClientRegistrationRules.emailMaxLength,
              autofillHints: const [AutofillHints.email],
              validator: ClientRegistrationRules.email,
            ),
            _textField(
              field: 'phone',
              controller: _phone,
              label: 'Teléfono celular',
              keyboardType: TextInputType.phone,
              maxLength: 16,
              autofillHints: const [AutofillHints.telephoneNumber],
              validator: ClientRegistrationRules.phone,
            ),
            _textField(
              field: 'password',
              controller: _password,
              label: 'Contraseña',
              obscureText: _obscurePassword,
              maxLength: ClientRegistrationRules.passwordMaxLength,
              helperText: 'Mínimo 8 caracteres, con letras y números.',
              autofillHints: const [AutofillHints.newPassword],
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
              validator: ClientRegistrationRules.password,
            ),
            _textField(
              field: 'confirmPassword',
              controller: _confirmPassword,
              label: 'Confirmar contraseña',
              obscureText: _obscurePassword,
              maxLength: ClientRegistrationRules.passwordMaxLength,
              validator: (value) => ClientRegistrationRules.confirmPassword(
                value,
                _password.text,
              ),
            ),
            const SizedBox(height: 4),
            DataConsentField(
              value: _controller.consentAccepted,
              policyVersion: _controller.policyVersion,
              enabled: !_controller.isLocked,
              onChanged: _controller.setConsentAccepted,
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey('client-registration-submit'),
              onPressed: _controller.isLocked ? null : _submit,
              child: _controller.isSubmitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: FixiaColors.white,
                      ),
                    )
                  : const Text('Crear cuenta'),
            ),
            if (widget.onGoToLogin != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('¿Ya tienes cuenta?', style: theme.textTheme.bodyMedium),
                  TextButton(
                    onPressed: widget.onGoToLogin,
                    child: const Text('Inicia sesión'),
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
          'Crea tu cuenta',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Regístrate como cliente y conecta con técnicos verificados.',
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: FixiaColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Resultado de la acción y siguiente paso (RNF-016).
class _RegistrationSuccess extends StatelessWidget {
  const _RegistrationSuccess({required this.email, this.onGoToLogin});

  final String email;
  final VoidCallback? onGoToLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('client-registration-success'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.check_circle_rounded,
          size: 64,
          color: FixiaColors.accent,
        ),
        const SizedBox(height: 16),
        Text(
          '¡Tu cuenta fue creada!',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Ya puedes iniciar sesión con $email.',
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: FixiaColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        if (onGoToLogin != null) ...[
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onGoToLogin,
            child: const Text('Ir a iniciar sesión'),
          ),
        ],
      ],
    );
  }
}
