import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/fixia_theme.dart';
import '../../../../core/layout/app_shell.dart';
import '../../../../core/widgets/fixia_ui.dart';
import '../domain/client_profile_rules.dart';
import '../domain/client_profile_update.dart';

class ClientProfilePage extends StatefulWidget {
  const ClientProfilePage({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.onSaved,
    this.onBack,
    this.onOpenHome,
    this.onOpenPublish,
    this.saveProfile,
    this.loadStats,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final ValueChanged<ClientProfileUpdate>? onSaved;
  final VoidCallback? onBack;
  final VoidCallback? onOpenHome;
  final VoidCallback? onOpenPublish;

  /// Guarda los cambios en el servidor (GC-320). Si es `null`, los cambios
  /// se conservan solo en esta vista. Si falla, lanza una excepción con el
  /// mensaje para el usuario.
  final Future<void> Function(ClientProfileUpdate update)? saveProfile;

  /// Resumen real de sus solicitudes en ms-services. Sin conexión es `null`
  /// y se muestra «–» en lugar de cifras de ejemplo.
  final Future<ClientActivityStats> Function()? loadStats;

  @override
  State<ClientProfilePage> createState() => _ClientProfilePageState();
}

class _ClientProfilePageState extends State<ClientProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final _firstNameController =
      TextEditingController(text: widget.firstName);
  late final _lastNameController = TextEditingController(text: widget.lastName);
  late final _phoneController = TextEditingController(text: widget.phone ?? '');
  late String _firstName = widget.firstName;
  late String _lastName = widget.lastName;
  late String? _phone = widget.phone;
  bool _isEditing = false;
  bool _justSavedLocally = false;
  bool _saving = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _firstNameController.text = _firstName;
      _lastNameController.text = _lastName;
      _phoneController.text = _phone ?? '';
      _isEditing = true;
      _justSavedLocally = false;
    });
  }

  void _cancelEditing() {
    setState(() => _isEditing = false);
  }

  void _toggleEditing() {
    if (_isEditing) {
      _cancelEditing();
    } else {
      _startEditing();
    }
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final update = ClientProfileUpdate(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phone: _phoneController.text.trim(),
    );
    final saveProfile = widget.saveProfile;
    if (saveProfile != null) {
      setState(() => _saving = true);
      try {
        await saveProfile(update);
      } catch (error) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: const ValueKey('client-profile-save-error'),
            content: Text('$error'),
          ),
        );
        return;
      }
      if (!mounted) return;
    }
    widget.onSaved?.call(update);
    setState(() {
      _saving = false;
      _firstName = update.firstName;
      _lastName = update.lastName;
      _phone = update.phone;
      _isEditing = false;
      _justSavedLocally = saveProfile == null;
    });
    if (saveProfile != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: ValueKey('client-profile-saved'),
          content: Text('Tus datos se guardaron.'),
        ),
      );
    }
  }

  void _navigate(ShellDestination destination) {
    final own = switch (destination) {
      ShellDestination.clientHome => widget.onOpenHome,
      _ => null,
    };
    if (own != null) return own();
    final scope = FixiaShellScope.maybeOf(context);
    if (scope?.onNavigate != null) return scope!.onNavigate!(destination);
    if (destination != ShellDestination.clientProfile) {
      _showDemoActionMessage(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final personal = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          title: 'Información personal',
          action: _isEditing
              ? TextButton.icon(
                  key: const ValueKey('client-profile-edit'),
                  onPressed: _toggleEditing,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Cancelar edición'),
                )
              : OutlinedButton.icon(
                  key: const ValueKey('client-profile-edit'),
                  onPressed: _toggleEditing,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar perfil'),
                ),
        ),
        if (_isEditing)
          FixiaPanel(
            padding: const EdgeInsets.all(24),
            child: _editForm(Theme.of(context)),
          )
        else
          _profileSummary(),
        if (_isEditing) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              key: const ValueKey('client-profile-cancel'),
              onPressed: _cancelEditing,
              child: const Text('Cancelar'),
            ),
          ),
        ],
        if (_justSavedLocally) ...[
          const SizedBox(height: 12),
          const _LocalSaveNotice(),
        ],
        const SizedBox(height: 20),
        const NoticeBanner(
          key: ValueKey('client-profile-payments-note'),
          message: 'Los pagos se acuerdan directamente con el técnico; '
              'Fixia no guarda métodos de pago en esta versión.',
          tone: PillTone.neutral,
          icon: Icons.payments_outlined,
        ),
      ],
    );
    return AppShell(
      destination: ShellDestination.clientProfile,
      userName: '$_firstName $_lastName'.trim(),
      onNavigate: _navigate,
      onPrimaryAction: widget.onOpenPublish,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BackLink(
            buttonKey: const ValueKey('client-profile-back'),
            onPressed: widget.onBack,
          ),
          const PageHeader(
            title: 'Mi perfil',
            titleKey: ValueKey('client-profile-title'),
            subtitle: 'Tus datos de contacto y el resumen de tu actividad.',
          ),
          const SizedBox(height: 24),
          TwoColumns(
            sideWidth: 320,
            sideFirstWhenStacked: true,
            main: personal,
            side: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProfileHero(firstName: _firstName, lastName: _lastName),
                const SizedBox(height: 16),
                _ProfileStats(load: widget.loadStats),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileSummary() {
    return Column(
      key: const ValueKey('client-profile-summary'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FixiaPanel(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
          child: Column(
            children: [
              _PersonalInfoRow(
                label: 'Nombre',
                value: '$_firstName $_lastName'.trim(),
              ),
              const _ProfileDivider(),
              _PersonalInfoRow(
                label: 'Teléfono',
                value: _phone == null || _phone!.isEmpty
                    ? 'No registrado'
                    : _phone!,
              ),
              const _ProfileDivider(),
              _PersonalInfoRow(label: 'Email', value: widget.email),
              const _ProfileDivider(),
              const _PersonalInfoRow(
                label: 'Dirección',
                value: 'No registrada',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _editForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('client-profile-form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Edita tu información',
            style: theme.textTheme.titleLarge?.copyWith(
              color: FixiaColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            key: const ValueKey('client-profile-first-name'),
            controller: _firstNameController,
            textCapitalization: TextCapitalization.words,
            maxLength: ClientProfileRules.nameMaxLength,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (value) =>
                ClientProfileRules.name(value, label: 'nombre'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: const ValueKey('client-profile-last-name'),
            controller: _lastNameController,
            textCapitalization: TextCapitalization.words,
            maxLength: ClientProfileRules.nameMaxLength,
            decoration: const InputDecoration(
              labelText: 'Apellido',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (value) =>
                ClientProfileRules.name(value, label: 'apellido'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: const ValueKey('client-profile-email'),
            initialValue: widget.email,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              helperText: 'El correo no se puede cambiar desde esta pantalla.',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: const ValueKey('client-profile-phone'),
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
            ],
            maxLength: 16,
            decoration: InputDecoration(
              labelText: 'Teléfono',
              // Admite el «+» y hasta 15 dígitos: el contador de 16 confundía.
              counterText: '',
              prefixIcon: const Icon(Icons.phone_outlined),
              helperText: widget.phone == null && widget.saveProfile == null
                  ? 'No disponible en la sesión actual; se conserva solo en esta vista.'
                  : null,
            ),
            validator: ClientProfileRules.phone,
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const ValueKey('client-profile-save'),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Guardando…' : 'Guardar cambios'),
          ),
        ],
      ),
    );
  }

  void _showDemoActionMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Esta sección se conectará en una siguiente tarea.'),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.firstName,
    required this.lastName,
  });

  final String firstName;
  final String lastName;

  String get _initials {
    final first = firstName.trim().isEmpty ? '' : firstName.trim()[0];
    final last = lastName.trim().isEmpty ? '' : lastName.trim()[0];
    return '$first$last'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FixiaColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: FixiaColors.supportBackground,
            child: Text(
              _initials.isEmpty ? '·' : _initials,
              style: const TextStyle(
                color: FixiaColors.primary,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$firstName $lastName'.trim(),
            key: const ValueKey('client-profile-full-name'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: FixiaColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Cliente Fixia · Cuenta personal',
            style: TextStyle(
              color: Color(0xFFB7CCE8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Actividad real del cliente, calculada con sus solicitudes.
class ClientActivityStats {
  const ClientActivityStats({
    required this.requests,
    required this.active,
    required this.closed,
  });

  final int requests;

  /// Contratadas, en ejecución o esperando su confirmación de cierre.
  final int active;
  final int closed;
}

class _ProfileStats extends StatefulWidget {
  const _ProfileStats({required this.load});

  final Future<ClientActivityStats> Function()? load;

  @override
  State<_ProfileStats> createState() => _ProfileStatsState();
}

class _ProfileStatsState extends State<_ProfileStats> {
  late final Future<ClientActivityStats>? _stats = widget.load?.call();

  @override
  Widget build(BuildContext context) {
    return FixiaPanel(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: FutureBuilder<ClientActivityStats>(
        future: _stats,
        builder: (context, snapshot) {
          final stats = snapshot.hasData ? snapshot.data : null;
          String show(int? value) => value == null ? '–' : '$value';
          return Row(
            children: [
              _ProfileStat(value: show(stats?.requests), label: 'Solicitudes'),
              const _StatDivider(),
              _ProfileStat(value: show(stats?.active), label: 'En curso'),
              const _StatDivider(),
              _ProfileStat(value: show(stats?.closed), label: 'Cerradas'),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: FixiaColors.primary,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: FixiaColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 34,
      child: VerticalDivider(
        width: 1,
        thickness: 1,
        color: FixiaColors.supportBackground,
      ),
    );
  }
}

class _PersonalInfoRow extends StatelessWidget {
  const _PersonalInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF91A2B7),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                color: FixiaColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileDivider extends StatelessWidget {
  const _ProfileDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: Color(0xFFE8EEF6));
  }
}

class _LocalSaveNotice extends StatelessWidget {
  const _LocalSaveNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('client-profile-saved-local'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FixiaColors.supportBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              color: FixiaColors.primary, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cambios guardados solo en esta sesión de prueba. Aún no se sincronizan con el servidor.',
            ),
          ),
        ],
      ),
    );
  }
}
