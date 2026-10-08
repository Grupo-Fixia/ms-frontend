import 'package:flutter/material.dart';

import '../../../../core/models/document_type.dart';
import '../../../../core/theme/fixia_theme.dart';
import '../../../../core/validation/registration_rules.dart';
import '../../../../core/widgets/data_consent_field.dart';
import '../domain/technician_profession.dart';
import 'technician_registration_controller.dart';
import '../application/register_technician.dart';

/// Formulario de registro de técnico (GC-255).
class TechnicianRegistrationPage extends StatefulWidget {
  const TechnicianRegistrationPage({
    super.key,
    required this.registerTechnician,
    this.onGoToLogin,
    this.onGoToClientRegistration,
  });

  final RegisterTechnician registerTechnician;
  final VoidCallback? onGoToLogin;
  final VoidCallback? onGoToClientRegistration;

  @override
  State<TechnicianRegistrationPage> createState() =>
      _TechnicianRegistrationPageState();
}

class _TechnicianRegistrationPageState
    extends State<TechnicianRegistrationPage> {
  static const _twoColumnBreakpoint = 480.0;

  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _documentNumber = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  late final TechnicianRegistrationController _controller;
  DocumentType? _documentType;
  TechnicianProfession? _profession;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _showRequiredErrors = false;

  @override
  void initState() {
    super.initState();
    _controller = TechnicianRegistrationController(
      registerTechnician: widget.registerTechnician,
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
    setState(() => _showRequiredErrors = true);
    if (!_formKey.currentState!.validate()) return;

    await _controller.register(
      firstName: _firstName.text,
      lastName: _lastName.text,
      profession: _profession,
      documentType: _documentType,
      documentNumber: _documentNumber.text,
      email: _email.text,
      phone: _phone.text,
      password: _password.text,
    );
    if (!mounted) return;

    final message = _controller.errorMessage;
    if (message == null) return;
    _formKey.currentState!.validate();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  FormFieldValidator<String> _validator(
    String field,
    FormFieldValidator<String> local,
  ) {
    return (value) {
      final fieldError = _controller.fieldError(field);
      if (fieldError != null) return fieldError;
      final isEmpty = value == null || value.trim().isEmpty;
      if (isEmpty && !_showRequiredErrors) return null;
      return local(value);
    };
  }

  Widget _textField({
    required String field,
    required TextEditingController controller,
    required String label,
    required IconData icon,
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
        key: ValueKey('technician-$field-field'),
        controller: controller,
        enabled: !_controller.isLocked,
        autovalidateMode: AutovalidateMode.onUserInteraction,
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
          prefixIcon: Icon(icon),
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
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.disabled,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header(),
            const SizedBox(height: 28),
            const InputDecorator(
              decoration: InputDecoration(
                labelText: 'Tipo de cuenta',
                prefixIcon: Icon(Icons.build_outlined),
              ),
              child: Text('Técnico profesional'),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DropdownButtonFormField<TechnicianProfession>(
                key: const ValueKey('technician-profession-field'),
                value: _profession,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Profesión',
                  prefixIcon: Icon(Icons.work_outline),
                ),
                items: [
                  for (final profession in TechnicianProfession.values)
                    DropdownMenuItem(
                      value: profession,
                      child: Text(profession.label),
                    ),
                ],
                onChanged: _controller.isLocked
                    ? null
                    : (value) => setState(() => _profession = value),
                validator: (value) => value == null && _showRequiredErrors
                    ? 'Selecciona tu profesión.'
                    : null,
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final names = [
                  _textField(
                    field: 'firstName',
                    controller: _firstName,
                    label: 'Nombres',
                    icon: Icons.person_outline,
                    capitalization: TextCapitalization.words,
                    maxLength: ClientRegistrationRules.nameMaxLength,
                    autofillHints: const [AutofillHints.givenName],
                    validator: ClientRegistrationRules.firstName,
                  ),
                  _textField(
                    field: 'lastName',
                    controller: _lastName,
                    label: 'Apellidos',
                    icon: Icons.person_outline,
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
                key: const ValueKey('technician-documentType-field'),
                value: _documentType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Tipo de documento',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
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
                    (value == null && _showRequiredErrors
                        ? 'Selecciona tu tipo de documento.'
                        : null),
              ),
            ),
            _textField(
              field: 'documentNumber',
              controller: _documentNumber,
              label: 'Número de documento',
              icon: Icons.numbers,
              capitalization: TextCapitalization.characters,
              maxLength: ClientRegistrationRules.documentMaxLength,
              validator: (value) => ClientRegistrationRules.documentNumber(
                value,
                _documentType,
              ),
            ),
            _textField(
              field: 'email',
              controller: _email,
              label: 'Correo electrónico',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              maxLength: ClientRegistrationRules.emailMaxLength,
              autofillHints: const [AutofillHints.email],
              validator: ClientRegistrationRules.email,
            ),
            _textField(
              field: 'phone',
              controller: _phone,
              label: 'Teléfono celular',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              maxLength: 16,
              autofillHints: const [AutofillHints.telephoneNumber],
              validator: ClientRegistrationRules.phone,
            ),
            _textField(
              field: 'password',
              controller: _password,
              label: 'Contraseña',
              icon: Icons.lock_outline,
              obscureText: _obscurePassword,
              maxLength: ClientRegistrationRules.passwordMaxLength,
              helperText: 'Mínimo 8 caracteres, con letras y números.',
              autofillHints: const [AutofillHints.newPassword],
              suffixIcon: IconButton(
                key: const ValueKey('technician-password-visibility'),
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
              icon: Icons.lock_outline,
              obscureText: _obscureConfirmPassword,
              maxLength: ClientRegistrationRules.passwordMaxLength,
              suffixIcon: IconButton(
                key: const ValueKey(
                  'technician-confirm-password-visibility',
                ),
                tooltip: _obscureConfirmPassword
                    ? 'Mostrar confirmación'
                    : 'Ocultar confirmación',
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(
                  () => _obscureConfirmPassword =
                      !_obscureConfirmPassword,
                ),
              ),
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
              checkboxKey: const ValueKey('technician-consent-checkbox'),
              autovalidateMode: _showRequiredErrors
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              onChanged: _controller.setConsentAccepted,
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey('technician-registration-submit'),
              onPressed: _controller.isLocked ? null : _submit,
              child: _controller.isSubmitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: FixiaColors.white,
                      ),
                    )
                  : const Text('Crear cuenta de técnico'),
            ),
            if (widget.onGoToLogin != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '¿Ya tienes cuenta?',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  TextButton(
                    key: const ValueKey('technician-go-to-login'),
                    onPressed: _controller.isLocked ? null : widget.onGoToLogin,
                    child: const Text('Inicia sesión'),
                  ),
                ],
              ),
            ],
            if (widget.onGoToClientRegistration != null) ...[
              const SizedBox(height: 8),
              TextButton(
                key: const ValueKey('technician-go-to-client-registration'),
                onPressed: _controller.isLocked
                    ? null
                    : widget.onGoToClientRegistration,
                child: const Text('Regístrate como usuario'),
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
          'Crea tu cuenta profesional',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Regístrate como técnico y ofrece tus servicios a la comunidad Fixia.',
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: FixiaColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _RegistrationSuccess extends StatelessWidget {
  const _RegistrationSuccess({required this.email, this.onGoToLogin});

  final String email;
  final VoidCallback? onGoToLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('technician-registration-success'),
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
          '¡Tu cuenta de técnico fue creada!',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'El siguiente paso llegará a $email.',
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: FixiaColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        if (onGoToLogin != null) ...[
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey('technician-success-go-to-login'),
            onPressed: onGoToLogin,
            child: const Text('Ir a iniciar sesión'),
          ),
        ],
      ],
    );
  }
}
