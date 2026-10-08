import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/service_category.dart';
import '../../../../core/theme/fixia_theme.dart';
import '../../../../core/widgets/technician_steps.dart';
import '../application/get_technician_profile.dart';
import '../application/update_technician_profile.dart';
import '../domain/technician_profile.dart';
import '../domain/technician_profile_rules.dart';
import '../domain/verification_status.dart';
import 'technician_profile_controller.dart';

/// Perfil profesional del técnico (GC-263, historia GC-237).
///
/// Si el perfil está incompleto muestra el paso 2, "Completa tu perfil
/// profesional"; si ya está completo muestra el resumen con la verificación
/// (paso 3) y permite editarlo.
class TechnicianProfilePage extends StatefulWidget {
  const TechnicianProfilePage({
    super.key,
    required this.getProfile,
    required this.updateProfile,
    this.firstName,
    this.onLogout,
    this.onSessionExpired,
  });

  final GetTechnicianProfile getProfile;
  final UpdateTechnicianProfile updateProfile;

  /// Nombre del técnico para el saludo.
  final String? firstName;

  /// Cierra la sesión. Si es `null` el botón no se muestra.
  final Future<void> Function()? onLogout;

  /// La sesión venció mientras se usaba el perfil.
  final VoidCallback? onSessionExpired;

  @override
  State<TechnicianProfilePage> createState() => _TechnicianProfilePageState();
}

class _TechnicianProfilePageState extends State<TechnicianProfilePage> {
  late final TechnicianProfileController _controller;
  bool _isLoggingOut = false;
  bool _sessionExpiredNotified = false;

  @override
  void initState() {
    super.initState();
    _controller = TechnicianProfileController(
      getProfile: widget.getProfile,
      updateProfile: widget.updateProfile,
    )..addListener(_refresh);
    _controller.load();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
    if (_controller.isSessionExpired && !_sessionExpiredNotified) {
      _sessionExpiredNotified = true;
      widget.onSessionExpired?.call();
    }
  }

  Future<void> _logout() async {
    final logout = widget.onLogout;
    if (logout == null || _isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    try {
      await logout();
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _controller.profile;
    final Widget content;
    switch (_controller.status) {
      case TechnicianProfileStatus.loading:
        content = const _Loading();
      case TechnicianProfileStatus.loadError:
        content = _LoadError(
          message: _controller.loadErrorMessage ??
              TechnicianProfileController.unexpectedErrorMessage,
          onRetry: _controller.load,
        );
      case TechnicianProfileStatus.ready:
        content = _controller.showForm
            ? _ProfileForm(
                // Al entrar a editar se vuelve a llenar con lo guardado.
                key: ValueKey('form-${_controller.isEditing}'),
                profile: profile!,
                controller: _controller,
              )
            : _ProfileSummary(
                profile: profile!,
                firstName: widget.firstName,
                justSaved: _controller.justSaved,
                onEdit: _controller.startEditing,
              );
    }
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(
                    isLoggingOut: _isLoggingOut,
                    onLogout: widget.onLogout == null ? null : _logout,
                  ),
                  const SizedBox(height: 24),
                  DecoratedBox(
                    decoration: FixiaDecorations.card,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 32,
                      ),
                      child: content,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.isLoggingOut, required this.onLogout});

  final bool isLoggingOut;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Image.asset(
              'assets/brand/fixia_logo.png',
              height: 32,
              semanticLabel: 'Fixia',
            ),
          ),
        ),
        if (onLogout != null)
          TextButton.icon(
            key: const ValueKey('technician-profile-logout'),
            onPressed: isLoggingOut ? null : onLogout,
            icon: isLoggingOut
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded, size: 20),
            label: const Text('Cerrar sesión'),
          ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('technician-profile-loading'),
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          'Cargando tu perfil…',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('technician-profile-load-error'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.cloud_off_rounded, size: 48, color: theme.colorScheme.error),
        const SizedBox(height: 16),
        Text(
          message,
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const ValueKey('technician-profile-retry'),
          onPressed: onRetry,
          child: const Text('Reintentar'),
        ),
      ],
    );
  }
}

/// Paso 2 (perfil incompleto) o edición del perfil.
class _ProfileForm extends StatefulWidget {
  const _ProfileForm({
    super.key,
    required this.profile,
    required this.controller,
  });

  final TechnicianProfile profile;
  final TechnicianProfileController controller;

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _years;
  late final TextEditingController _description;
  late Set<ServiceCategory> _categories;

  TechnicianProfileController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _years = TextEditingController(
      text: profile.yearsOfExperience?.toString() ?? '',
    );
    _description = TextEditingController(
      text: profile.professionalDescription ?? '',
    );
    _categories = {...profile.categories};
  }

  @override
  void dispose() {
    _years.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final saved = await _controller.save(
      professionalDescription: _description.text,
      yearsOfExperience: _years.text,
      categories: _categories,
    );
    // Muestra debajo de cada campo los errores que devolvió el backend.
    if (!saved && mounted) _formKey.currentState?.validate();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleting = !widget.profile.isComplete;
    final isSaving = _controller.isSaving;
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('technician-profile-form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isCompleting
                ? 'Completa tu perfil profesional'
                : 'Edita tu perfil profesional',
            key: const ValueKey('technician-profile-title'),
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isCompleting
                ? 'Así los clientes sabrán qué haces. Puedes cambiarlo '
                    'cuando quieras.'
                : 'Los cambios se ven en tu perfil apenas los guardes.',
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: FixiaColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          if (isCompleting) ...[
            const SizedBox(height: 24),
            const TechnicianSteps(currentStep: 2),
          ],
          const SizedBox(height: 28),
          if (_controller.saveErrorMessage != null) ...[
            _ErrorBanner(
              message: _controller.saveErrorMessage!,
              onClose: _controller.dismissSaveError,
            ),
            const SizedBox(height: 20),
          ],
          _CategoriesField(
            selected: _categories,
            enabled: !isSaving,
            serverError: _controller.fieldError('categories'),
            onChanged: (categories) {
              _controller.clearFieldError('categories');
              setState(() => _categories = categories);
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            key: const ValueKey('profile-years-field'),
            controller: _years,
            enabled: !isSaving,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 2,
            onChanged: (_) => _controller.clearFieldError('yearsOfExperience'),
            decoration: const InputDecoration(
              labelText: 'Años de experiencia',
              prefixIcon: Icon(Icons.workspace_premium_outlined),
              counterText: '',
            ),
            validator: (value) =>
                _controller.fieldError('yearsOfExperience') ??
                TechnicianProfileRules.yearsOfExperience(
                  TechnicianProfileRules.parseYears(value),
                ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: const ValueKey('profile-description-field'),
            controller: _description,
            enabled: !isSaving,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            minLines: 4,
            maxLines: 8,
            maxLength: TechnicianProfileRules.descriptionMaxLength,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) =>
                _controller.clearFieldError('professionalDescription'),
            decoration: const InputDecoration(
              labelText: 'Descripción profesional',
              alignLabelWithHint: true,
              helperText: 'Qué trabajos haces, tu experiencia y en qué zonas '
                  'trabajas.',
              helperMaxLines: 2,
            ),
            validator: (value) =>
                _controller.fieldError('professionalDescription') ??
                TechnicianProfileRules.description(value),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey('profile-save'),
            onPressed: isSaving ? null : _save,
            child: isSaving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: FixiaColors.white,
                    ),
                  )
                : const Text('Guardar perfil'),
          ),
          if (!isCompleting) ...[
            const SizedBox(height: 8),
            TextButton(
              key: const ValueKey('profile-cancel'),
              onPressed: isSaving ? null : _controller.cancelEditing,
              child: const Text('Cancelar'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Selección de categorías (al menos una), con las 6 de ms-users.
class _CategoriesField extends StatelessWidget {
  const _CategoriesField({
    required this.selected,
    required this.enabled,
    required this.serverError,
    required this.onChanged,
  });

  final Set<ServiceCategory> selected;
  final bool enabled;
  final String? serverError;
  final ValueChanged<Set<ServiceCategory>> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FormField<Set<ServiceCategory>>(
      key: const ValueKey('profile-categories-field'),
      initialValue: selected,
      validator: (_) =>
          serverError ?? TechnicianProfileRules.categories(selected),
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Qué servicios ofreces?',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: FixiaColors.primary),
          ),
          const SizedBox(height: 4),
          Text(
            'Elige una o varias categorías.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in ServiceCategory.values)
                FilterChip(
                  key: ValueKey('profile-category-${category.apiValue}'),
                  label: Text(category.label),
                  selected: selected.contains(category),
                  selectedColor: FixiaColors.supportBackground,
                  checkmarkColor: FixiaColors.secondary,
                  onSelected: enabled
                      ? (isSelected) {
                          final next = {...selected};
                          if (isSelected) {
                            next.add(category);
                          } else {
                            next.remove(category);
                          }
                          onChanged(next);
                          field.didChange(next);
                        }
                      : null,
                ),
            ],
          ),
          if (field.errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 12),
              child: Text(
                field.errorText!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

/// Perfil completo: resumen, estado de verificación y botón para editar.
class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({
    required this.profile,
    required this.firstName,
    required this.justSaved,
    required this.onEdit,
  });

  final TechnicianProfile profile;
  final String? firstName;
  final bool justSaved;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = firstName?.trim() ?? '';
    final status = profile.verificationStatus;
    final years = profile.yearsOfExperience ?? 0;
    return Column(
      key: const ValueKey('technician-profile-summary'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (justSaved) ...[
          const _SavedBanner(),
          const SizedBox(height: 20),
        ],
        Text(
          name.isEmpty ? 'Tu perfil profesional' : 'Hola, $name',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Center(child: _VerificationBadge(status: status)),
        if (status == VerificationStatus.pending) ...[
          const SizedBox(height: 24),
          const TechnicianSteps(currentStep: 3),
          const SizedBox(height: 12),
          Text(
            'Fixia está revisando tu información. Te avisaremos cuando tu '
            'cuenta quede verificada.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: FixiaColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 28),
        _Section(
          title: 'Servicios que ofreces',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in ServiceCategory.values)
                if (profile.categories.contains(category))
                  Chip(
                    key: ValueKey('profile-summary-${category.apiValue}'),
                    label: Text(category.label),
                    backgroundColor: FixiaColors.supportBackground,
                    side: BorderSide.none,
                    labelStyle: theme.textTheme.bodyMedium
                        ?.copyWith(color: FixiaColors.primary),
                  ),
            ],
          ),
        ),
        _Section(
          title: 'Experiencia',
          child: Text(
            years == 1 ? '1 año' : '$years años',
            key: const ValueKey('profile-summary-years'),
            style: theme.textTheme.bodyLarge,
          ),
        ),
        _Section(
          title: 'Descripción',
          child: Text(
            profile.professionalDescription ?? '',
            key: const ValueKey('profile-summary-description'),
            style: theme.textTheme.bodyLarge,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const ValueKey('profile-edit'),
          onPressed: onEdit,
          style: OutlinedButton.styleFrom(
            foregroundColor: FixiaColors.secondary,
            minimumSize: const Size.fromHeight(52),
            side: const BorderSide(color: FixiaColors.secondary, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FixiaRadii.input),
            ),
          ),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar perfil'),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  const _VerificationBadge({required this.status});

  final VerificationStatus? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color background, Color foreground, IconData icon) = switch (status) {
      VerificationStatus.valid => (
          const Color(0xFFE0F6F2),
          FixiaColors.accent,
          Icons.verified_rounded,
        ),
      VerificationStatus.rejected || VerificationStatus.expired => (
          const Color(0xFFFDECEA),
          theme.colorScheme.error,
          Icons.error_outline,
        ),
      _ => (
          FixiaColors.supportBackground,
          FixiaColors.secondary,
          Icons.hourglass_top_rounded,
        ),
    };
    return DecoratedBox(
      key: const ValueKey('profile-verification-badge'),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                status?.label ?? VerificationStatus.pending.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedBanner extends StatelessWidget {
  const _SavedBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey('profile-saved'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F6F2),
          borderRadius: BorderRadius.circular(FixiaRadii.input),
          border: Border.all(color: FixiaColors.accent),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: FixiaColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '¡Perfil guardado!',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: FixiaColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
        key: const ValueKey('profile-error'),
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
