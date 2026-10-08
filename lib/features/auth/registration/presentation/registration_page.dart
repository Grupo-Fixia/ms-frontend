import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/fixia_theme.dart';
import '../../../../core/widgets/technician_steps.dart';
import '../application/register_account.dart';
import '../domain/account_role.dart';
import '../domain/registration_rules.dart';
import '../domain/document_type.dart';
import 'registration_controller.dart';
import 'widgets/data_consent_field.dart';
import 'widgets/technician_registration_extras.dart';

/// Formulario de registro de cuenta: cliente (GC-252, historia GC-234) o
/// técnico (GC-255, historia GC-235). Los datos y las validaciones son los
/// mismos; cambian los textos según [role].
class RegistrationPage extends StatefulWidget {
  const RegistrationPage({
    super.key,
    required this.registerAccount,
    this.role = AccountRole.client,
    this.onGoToLogin,
    this.onSwitchRole,
  });

  final RegisterAccount registerAccount;

  /// Tipo de cuenta que se crea.
  final AccountRole role;

  /// Navega al inicio de sesión. Si es `null` el enlace no se muestra.
  final VoidCallback? onGoToLogin;

  /// Lleva al registro del otro rol. Si es `null` el enlace no se muestra.
  final VoidCallback? onSwitchRole;

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  /// Ancho a partir del cual nombres y apellidos van en la misma fila.
  static const _twoColumnBreakpoint = 480.0;

  /// Ancho a partir del cual las razones del técnico van al lado del
  /// formulario (en pantallas más angostas van arriba, en versión corta).
  static const benefitsSideBreakpoint = 900.0;

  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _documentNumber = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  final _confirmPasswordKey = GlobalKey<FormFieldState<String>>();

  final _scrollController = ScrollController();

  late final RegistrationController _controller;
  DocumentType? _documentType;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _controller = RegistrationController(
      registerAccount: widget.registerAccount,
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
    _scrollController.dispose();
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

    if (_controller.errorMessage == null) return;
    // Muestra debajo de cada campo los errores que devolvió el backend.
    _formKey.currentState!.validate();
    if (_scrollController.hasClients) {
      // El aviso y los campos con error quedan arriba: se sube para que se vean.
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  bool get _documentAllowsLetters =>
      RegistrationRules.documentAllowsLetters(_documentType);

  void _onDocumentTypeChanged(DocumentType? type) {
    _controller.clearFieldError('documentType');
    setState(() {
      _documentType = type;
      // Si pasa de pasaporte a cédula, se quitan las letras que ya no aplican.
      if (!_documentAllowsLetters) {
        final digits = _documentNumber.text.replaceAll(RegExp('[^0-9]'), '');
        if (digits != _documentNumber.text) _documentNumber.text = digits;
      }
    });
  }

  /// Si el usuario ya escribió la confirmación, se vuelve a comparar cuando
  /// cambia la contraseña.
  void _revalidateConfirmPassword() {
    if (_confirmPassword.text.isNotEmpty) {
      _confirmPasswordKey.currentState?.validate();
    }
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
    required IconData icon,
    required FormFieldValidator<String> validator,
    Key? fieldKey,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
    int? maxLength,
    bool obscureText = false,
    String? helperText,
    Widget? suffixIcon,
    Iterable<String>? autofillHints,
  }) {
    return Padding(
      key: ValueKey('registration-$field-field'),
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        key: fieldKey,
        controller: controller,
        // Cada campo se valida solo cuando el usuario lo toca, sin marcar
        // errores en los demás.
        autovalidateMode: AutovalidateMode.onUserInteraction,
        inputFormatters: inputFormatters,
        enabled: !_controller.isLocked,
        keyboardType: keyboardType,
        textCapitalization: capitalization,
        maxLength: maxLength,
        obscureText: obscureText,
        autocorrect: false,
        enableSuggestions: !obscureText,
        autofillHints: autofillHints,
        textInputAction: TextInputAction.next,
        onChanged: (value) {
          _controller.clearFieldError(field);
          onChanged?.call(value);
        },
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
    final card = DecoratedBox(
      decoration: FixiaDecorations.card,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: _controller.isRegistered
            ? _RegistrationSuccess(
                role: widget.role,
                email: _email.text.trim(),
                onGoToLogin: widget.onGoToLogin,
              )
            : _buildForm(context),
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: _layout(
                card,
                isWide: constraints.maxWidth >= benefitsSideBreakpoint,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// El cliente ve solo el formulario; el técnico, además, las razones para
  /// unirse (al lado en pantalla ancha, arriba en celular).
  Widget _layout(Widget card, {required bool isWide}) {
    if (widget.role == AccountRole.client) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: card,
      );
    }
    if (isWide) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(flex: 4, child: TechnicianBenefits()),
            const SizedBox(width: 28),
            Expanded(flex: 6, child: card),
          ],
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TechnicianBenefits(compact: true),
          const SizedBox(height: 16),
          card,
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(role: widget.role),
            const SizedBox(height: 28),
            if (_controller.errorMessage != null &&
                !_controller.isAccountConflict) ...[
              _ErrorBanner(
                message: _controller.errorMessage!,
                onClose: _controller.dismissError,
              ),
              const SizedBox(height: 20),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final names = [
                  _textField(
                    field: 'firstName',
                    controller: _firstName,
                    label: 'Nombres',
                    icon: Icons.person_outline,
                    capitalization: TextCapitalization.words,
                    maxLength: RegistrationRules.nameMaxLength,
                    autofillHints: const [AutofillHints.givenName],
                    validator: RegistrationRules.firstName,
                  ),
                  _textField(
                    field: 'lastName',
                    controller: _lastName,
                    label: 'Apellidos',
                    icon: Icons.person_outline,
                    capitalization: TextCapitalization.words,
                    maxLength: RegistrationRules.nameMaxLength,
                    autofillHints: const [AutofillHints.familyName],
                    validator: RegistrationRules.lastName,
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
                key: const ValueKey('registration-documentType-field'),
                value: _documentType,
                isExpanded: true,
                autovalidateMode: AutovalidateMode.onUserInteraction,
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
                    : _onDocumentTypeChanged,
                validator: (value) =>
                    _controller.fieldError('documentType') ??
                    (value == null ? 'Selecciona tu tipo de documento.' : null),
              ),
            ),
            _textField(
              field: 'documentNumber',
              controller: _documentNumber,
              label: 'Número de documento',
              icon: Icons.numbers,
              capitalization: TextCapitalization.characters,
              keyboardType: _documentAllowsLetters
                  ? TextInputType.text
                  : TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  _documentAllowsLetters
                      ? RegExp('[A-Za-z0-9]')
                      : RegExp('[0-9]'),
                ),
              ],
              maxLength: RegistrationRules.documentMaxLength,
              validator: (value) =>
                  RegistrationRules.documentNumber(value, _documentType),
            ),
            _textField(
              field: 'email',
              controller: _email,
              label: 'Correo electrónico',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              maxLength: RegistrationRules.emailMaxLength,
              autofillHints: const [AutofillHints.email],
              validator: RegistrationRules.email,
            ),
            _textField(
              field: 'phone',
              controller: _phone,
              label: 'Teléfono celular',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
              ],
              maxLength: 16,
              autofillHints: const [AutofillHints.telephoneNumber],
              validator: RegistrationRules.phone,
            ),
            _textField(
              field: 'password',
              controller: _password,
              label: 'Contraseña',
              icon: Icons.lock_outline,
              obscureText: _obscurePassword,
              onChanged: (_) => _revalidateConfirmPassword(),
              maxLength: RegistrationRules.passwordMaxLength,
              helperText: 'Mínimo 8 caracteres, con letras y números.',
              autofillHints: const [AutofillHints.newPassword],
              suffixIcon: _VisibilityToggle(
                obscured: _obscurePassword,
                label: 'contraseña',
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: RegistrationRules.password,
            ),
            _textField(
              field: 'confirmPassword',
              controller: _confirmPassword,
              label: 'Confirmar contraseña',
              icon: Icons.lock_outline,
              fieldKey: _confirmPasswordKey,
              obscureText: _obscureConfirmPassword,
              suffixIcon: _VisibilityToggle(
                obscured: _obscureConfirmPassword,
                label: 'confirmación',
                onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
              ),
              maxLength: RegistrationRules.passwordMaxLength,
              validator: (value) => RegistrationRules.confirmPassword(
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
              key: const ValueKey('registration-submit'),
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
            if (widget.onSwitchRole != null)
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    widget.role == AccountRole.client
                        ? '¿Ofreces servicios técnicos?'
                        : '¿Buscas un técnico?',
                    style: theme.textTheme.bodyMedium,
                  ),
                  TextButton(
                    key: const ValueKey('registration-switch-role'),
                    onPressed: _controller.isSubmitting
                        ? null
                        : widget.onSwitchRole,
                    child: Text(
                      widget.role == AccountRole.client
                          ? 'Regístrate como técnico'
                          : 'Regístrate como cliente',
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.role});

  final AccountRole role;

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
        if (role == AccountRole.technician) ...[
          const TechnicianBadge(),
          const SizedBox(height: 12),
        ],
        Text(
          switch (role) {
            AccountRole.client => 'Crea tu cuenta',
            AccountRole.technician => 'Crea tu cuenta de técnico',
          },
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          switch (role) {
            AccountRole.client =>
              'Regístrate como cliente y conecta con técnicos verificados.',
            AccountRole.technician =>
              'Regístrate para ofrecer tus servicios y conseguir clientes '
                  'cerca de ti.',
          },
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: FixiaColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        if (role == AccountRole.technician) ...[
          const SizedBox(height: 24),
          const TechnicianSteps(),
        ],
      ],
    );
  }
}

/// Resultado de la acción y siguiente paso (RNF-016).
class _RegistrationSuccess extends StatelessWidget {
  const _RegistrationSuccess({
    required this.role,
    required this.email,
    this.onGoToLogin,
  });

  final AccountRole role;
  final String email;
  final VoidCallback? onGoToLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('registration-success'),
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
          switch (role) {
            AccountRole.client => '¡Tu cuenta fue creada!',
            AccountRole.technician => '¡Tu cuenta de técnico fue creada!',
          },
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          switch (role) {
            AccountRole.client => 'Ya puedes iniciar sesión con $email.',
            // El técnico queda con verificación pendiente (ms-users, GC-254).
            AccountRole.technician =>
              'Inicia sesión con $email para completar tu perfil profesional. '
                  'Tu cuenta queda pendiente de verificación.',
          },
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

/// Botón del ojo para mostrar u ocultar una contraseña.
class _VisibilityToggle extends StatelessWidget {
  const _VisibilityToggle({
    required this.obscured,
    required this.label,
    required this.onPressed,
  });

  final bool obscured;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: obscured ? 'Mostrar $label' : 'Ocultar $label',
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
      onPressed: onPressed,
    );
  }
}

/// Aviso de error visible arriba del formulario.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey('registration-error'),
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFDECEA),
          borderRadius: BorderRadius.circular(FixiaRadii.input),
          border: Border.all(color: theme.colorScheme.error),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: FixiaColors.textPrimary),
              ),
            ),
            IconButton(
              tooltip: 'Cerrar aviso',
              icon: const Icon(Icons.close),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}
