import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/fixia_theme.dart';
import '../../../home/presentation/widgets/dashboard_components.dart';
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

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      contentPadding: EdgeInsets.zero,
      bottomNavigationBar: _ProfileNavigationBar(
        onHome: widget.onOpenHome ?? () => _showDemoActionMessage(context),
        onHistory: () => _showDemoActionMessage(context),
        onPublish:
            widget.onOpenPublish ?? () => _showDemoActionMessage(context),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProfileHero(
                  firstName: _firstName,
                  lastName: _lastName,
                  onBack:
                      widget.onBack ?? () => Navigator.of(context).maybePop(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -18),
                        child: const _ProfileStats(),
                      ),
                      const SizedBox(height: 2),
                      _SectionTitle(
                        title: 'Información personal',
                        trailing: IconButton(
                          key: const ValueKey('client-profile-edit'),
                          tooltip:
                              _isEditing ? 'Cancelar edición' : 'Editar perfil',
                          onPressed: _toggleEditing,
                          icon: Icon(
                            _isEditing
                                ? Icons.close_rounded
                                : Icons.edit_outlined,
                          ),
                          color: FixiaColors.secondary,
                        ),
                      ),
                      if (_isEditing)
                        DecoratedBox(
                          decoration: FixiaDecorations.card,
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: _editForm(Theme.of(context)),
                          ),
                        )
                      else
                        _profileSummary(),
                      if (_isEditing) ...[
                        const SizedBox(height: 10),
                        OutlinedButton(
                          key: const ValueKey('client-profile-cancel'),
                          onPressed: _cancelEditing,
                          child: const Text('Cancelar'),
                        ),
                      ],
                      if (_justSavedLocally) ...[
                        const SizedBox(height: 12),
                        const _LocalSaveNotice(),
                      ],
                      const SizedBox(height: 22),
                      const _SectionTitle(
                        title: 'Métodos de pago',
                        trailing: _DemoDataTag(),
                      ),
                      const _PaymentMethodsCard(),
                      const SizedBox(height: 20),
                      _WalletSummary(
                        onWithdraw: () => _showDemoActionMessage(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileSummary() {
    return Column(
      key: const ValueKey('client-profile-summary'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
          decoration: FixiaDecorations.card,
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
    required this.onBack,
  });

  final String firstName;
  final String lastName;
  final VoidCallback onBack;

  String get _initials {
    final first = firstName.trim().isEmpty ? '' : firstName.trim()[0];
    final last = lastName.trim().isEmpty ? '' : lastName.trim()[0];
    return '$first$last'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 34),
      decoration: const BoxDecoration(
        color: FixiaColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                key: const ValueKey('client-profile-back'),
                tooltip: 'Volver',
                onPressed: onBack,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: FixiaColors.white,
                ),
              ),
              const Spacer(),
              const Text(
                'Mi perfil',
                key: ValueKey('client-profile-title'),
                style: TextStyle(
                  color: FixiaColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 14),
          CircleAvatar(
            radius: 44,
            backgroundColor: FixiaColors.supportBackground,
            child: Text(
              _initials.isEmpty ? 'FX' : _initials,
              style: const TextStyle(
                color: FixiaColors.primary,
                fontSize: 28,
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
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star_rounded, color: Color(0xFFFFB323), size: 18),
              SizedBox(width: 4),
              Text(
                'Resumen de perfil',
                style: TextStyle(color: Color(0xFFDCEBFF), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileStats extends StatelessWidget {
  const _ProfileStats();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: FixiaColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3EAF4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1401255D),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Column(
        children: [
          Row(
            children: [
              _ProfileStat(value: '23', label: 'Trabajos'),
              _StatDivider(),
              _ProfileStat(value: '4.7', label: 'Rating'),
              _StatDivider(),
              _ProfileStat(value: '\$24.5K', label: 'Saldo'),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Datos de demostración',
            key: ValueKey('client-profile-demo-label'),
            style: TextStyle(
              color: FixiaColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: FixiaColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
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

class _DemoDataTag extends StatelessWidget {
  const _DemoDataTag();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'EJEMPLO',
      style: TextStyle(
        color: FixiaColors.secondary,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _PaymentMethodsCard extends StatelessWidget {
  const _PaymentMethodsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('client-profile-payment-methods'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: FixiaDecorations.card,
      child: const Column(
        children: [
          _PaymentMethod(
            initials: 'V',
            method: 'Débito •••• 4582',
            provider: 'Banco de ejemplo',
            color: Color(0xFF202B87),
          ),
          Divider(height: 1, color: Color(0xFFE8EEF6)),
          _PaymentMethod(
            initials: 'MC',
            method: 'Crédito •••• 7893',
            provider: 'Emisor de ejemplo',
            color: Color(0xFFEF3340),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethod extends StatelessWidget {
  const _PaymentMethod({
    required this.initials,
    required this.method,
    required this.provider,
    required this.color,
  });

  final String initials;
  final String method;
  final String provider;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              initials,
              style: const TextStyle(
                color: FixiaColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  method,
                  style: const TextStyle(
                    color: FixiaColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  provider,
                  style: const TextStyle(
                    color: FixiaColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletSummary extends StatelessWidget {
  const _WalletSummary({required this.onWithdraw});

  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('client-profile-wallet'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [FixiaColors.secondary, Color(0xFF0348C5)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SALDO DISPONIBLE · EJEMPLO',
                  style: TextStyle(
                    color: Color(0xFFDCEBFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  '\$24.500',
                  style: TextStyle(
                    color: FixiaColors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 92,
            child: FilledButton(
              key: const ValueKey('client-profile-withdraw'),
              onPressed: onWithdraw,
              style: FilledButton.styleFrom(
                backgroundColor: FixiaColors.white,
                foregroundColor: FixiaColors.secondary,
              ),
              child: const Text('Retirar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileNavigationBar extends StatelessWidget {
  const _ProfileNavigationBar({
    required this.onHome,
    required this.onHistory,
    required this.onPublish,
  });

  final VoidCallback onHome;
  final VoidCallback onHistory;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    return MobileNavigationBar(
      items: [
        MobileNavigationItem(
          itemKey: const ValueKey('client-profile-nav-home'),
          icon: Icons.home_outlined,
          label: 'Inicio',
          onPressed: onHome,
        ),
        MobileNavigationItem(
          itemKey: const ValueKey('client-profile-nav-history'),
          icon: Icons.history_rounded,
          label: 'Historial',
          onPressed: onHistory,
        ),
        MobileNavigationItem(
          itemKey: const ValueKey('client-profile-nav-publish'),
          icon: Icons.add_rounded,
          label: 'Publicar',
          isAction: true,
          onPressed: onPublish,
        ),
        MobileNavigationItem(
          itemKey: const ValueKey('client-profile-nav-profile'),
          icon: Icons.person_rounded,
          label: 'Perfil',
          selected: true,
          onPressed: () {},
        ),
      ],
    );
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
