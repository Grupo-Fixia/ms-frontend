import 'package:flutter/material.dart';

import '../../../../core/theme/fixia_theme.dart';
import '../application/logout_user.dart';
import '../application/session_store.dart';

/// Pantalla mínima de sesión iniciada (GC-236): muestra la cuenta que
/// devolvió `/me` y permite cerrar sesión. Hasta que exista el inicio de la
/// app, es el destino del login.
class SessionPage extends StatefulWidget {
  const SessionPage({
    super.key,
    required this.store,
    required this.logoutUser,
    this.onLoggedOut,
  });

  final SessionStore store;
  final LogoutUser logoutUser;

  /// Se llama cuando la sesión ya se cerró.
  final VoidCallback? onLoggedOut;

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  bool _isLoggingOut = false;

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    await widget.logoutUser();
    if (!mounted) return;
    setState(() => _isLoggingOut = false);
    widget.onLoggedOut?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = widget.store.profile;
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
                  child: Column(
                    key: const ValueKey('session-card'),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset(
                        'assets/brand/fixia_logo.png',
                        height: 48,
                        semanticLabel: 'Fixia',
                      ),
                      const SizedBox(height: 24),
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 64,
                        color: FixiaColors.accent,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Hola, ${profile?.firstName ?? ''}'.trim(),
                        key: const ValueKey('session-greeting'),
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sesión iniciada correctamente.',
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(color: FixiaColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      _Detail(label: 'Nombre', value: profile?.fullName),
                      _Detail(label: 'Correo', value: profile?.email),
                      _Detail(label: 'Rol', value: profile?.role?.label),
                      const SizedBox(height: 24),
                      FilledButton(
                        key: const ValueKey('session-logout'),
                        onPressed: _isLoggingOut ? null : _logout,
                        child: _isLoggingOut
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: FixiaColors.white,
                                ),
                              )
                            : const Text('Cerrar sesión'),
                      ),
                    ],
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

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value == null || value!.isEmpty ? '—' : value!,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
