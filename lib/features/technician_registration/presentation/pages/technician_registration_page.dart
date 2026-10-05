import 'package:flutter/material.dart';

import '../../domain/entities/technician_registration.dart';
import '../../domain/usecases/register_technician.dart';
import '../controllers/technician_registration_controller.dart';
import '../widgets/technician_consent_checkbox.dart';

class TechnicianRegistrationPage extends StatefulWidget {
  const TechnicianRegistrationPage({
    super.key,
    required this.registerTechnician,
  });

  final RegisterTechnician registerTechnician;

  @override
  State<TechnicianRegistrationPage> createState() =>
      _TechnicianRegistrationPageState();
}

class _TechnicianRegistrationPageState
    extends State<TechnicianRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _documentNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  late final TechnicianRegistrationController _controller;
  TechnicianDocumentType? _documentType;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _controller = TechnicianRegistrationController(
      registerTechnician: widget.registerTechnician,
    )..addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _documentNumberController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await _controller.register(
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      documentType: _documentType,
      documentNumber: _documentNumberController.text,
      email: _emailController.text,
      phone: _phoneController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;
    if (_controller.isRegistered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu cuenta de técnico fue creada.')),
      );
    }
  }

  String? _required(String? value, String field) {
    if (value == null || value.trim().isEmpty) {
      return 'El $field es obligatorio.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24              ),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Image.asset(
                            'assets/brand/fixia-logo.png',
                            width: 196,
                            height: 100,
                            fit: BoxFit.contain,
                            semanticLabel: 'Fixia',
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Crea tu cuenta profesional',
                          style: theme.textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Regístrate como técnico y ofrece tus servicios '
                          'a la comunidad Fixia.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        const InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Tipo de cuenta',
                            prefixIcon: Icon(Icons.build_outlined),
                          ),
                          child: Text('Técnico profesional (PROFESSIONAL)'),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _firstNameController,
                          textCapitalization: TextCapitalization.words,
                          maxLength: 100,
                          decoration: const InputDecoration(
                            labelText: 'Nombres',
                          ),
                          validator: (value) => _required(value, 'nombre'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _lastNameController,
                          textCapitalization: TextCapitalization.words,
                          maxLength: 100,
                          decoration: const InputDecoration(
                            labelText: 'Apellidos',
                          ),
                          validator: (value) => _required(value, 'apellido'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<TechnicianDocumentType>(
                          initialValue: _documentType,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de documento',
                          ),
                          items: TechnicianDocumentType.values
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _documentType = value),
                          validator: (value) => value == null
                              ? 'Selecciona un tipo de documento.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _documentNumberController,
                          maxLength: 30,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Número de documento',
                          ),
                          validator: (value) {
                            final requiredError = _required(
                              value,
                              'número de documento',
                            );
                            if (requiredError != null) return requiredError;
                            if (!RegExp(r'^[A-Za-z0-9]+$')
                                .hasMatch(value!.trim())) {
                              return 'Usa solo letras y números.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                          ),
                          validator: (value) {
                            final requiredError = _required(value, 'correo');
                            if (requiredError != null) return requiredError;
                            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(value!.trim())) {
                              return 'Ingresa un correo electrónico válido.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Teléfono',
                          ),
                          validator: (value) {
                            final requiredError = _required(value, 'teléfono');
                            if (requiredError != null) return requiredError;
                            if (!RegExp(r'^\+?[0-9]{7,15}$')
                                .hasMatch(value!.trim())) {
                              return 'Ingresa un teléfono válido '
                                  '(7 a 15 dígitos).';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            helperText:
                                'Mínimo 8 caracteres, con letras y números.',
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Mostrar contraseña'
                                  : 'Ocultar contraseña',
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            final requiredError = _required(
                              value,
                              'contraseña',
                            );
                            if (requiredError != null) return requiredError;
                            if (value!.length < 8 ||
                                !RegExp(r'^(?=.*[A-Za-z])(?=.*\d).*$')
                                    .hasMatch(value)) {
                              return 'Debe tener al menos 8 caracteres, '
                                  'letras y números.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        TechnicianConsentCheckbox(
                          value: _controller.consentAccepted,
                          policyVersion:
                              TechnicianRegistrationController.policyVersion,
                          acceptedAt: _controller.consentAcceptedAt,
                          onChanged: _controller.setConsentAccepted,
                        ),
                        if (_controller.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              _controller.errorMessage!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _controller.isSubmitting ? null : _submit,
                          child: _controller.isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Crear cuenta de técnico'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
