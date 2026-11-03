import 'package:flutter/material.dart';

import '../theme/fixia_theme.dart';

/// Rol de la cuenta: decide el menú y el estilo del marco.
enum ShellRole { client, technician, company }

/// Destinos principales de cada rol. Cada uno es una pantalla de primer
/// nivel; las demás (detalles, formularios) se abren encima.
enum ShellDestination {
  clientHome(
      ShellRole.client, 'Inicio', Icons.home_outlined, 'client-nav-inicio'),
  clientRequests(ShellRole.client, 'Mis solicitudes', Icons.assignment_outlined,
      'client-nav-historial'),
  clientProfile(ShellRole.client, 'Mi perfil', Icons.person_outline_rounded,
      'client-nav-perfil'),
  technicianHome(ShellRole.technician, 'Inicio', Icons.home_outlined,
      'technician-nav-inicio'),
  technicianOpportunities(ShellRole.technician, 'Oportunidades',
      Icons.search_rounded, 'technician-nav-oportunidades'),
  technicianJobs(ShellRole.technician, 'Mis trabajos',
      Icons.work_outline_rounded, 'technician-nav-trabajos'),
  technicianProfile(ShellRole.technician, 'Perfil profesional',
      Icons.person_outline_rounded, 'technician-nav-perfil'),
  companyHome(
      ShellRole.company, 'Inicio', Icons.home_outlined, 'company-nav-inicio'),
  companyTechnicians(ShellRole.company, 'Mis técnicos', Icons.groups_outlined,
      'company-nav-tecnicos'),
  companyOpportunities(ShellRole.company, 'Oportunidades', Icons.search_rounded,
      'company-nav-oportunidades');

  const ShellDestination(this.role, this.label, this.icon, this.keyName);

  final ShellRole role;
  final String label;
  final IconData icon;

  /// Clave estable para pruebas y automatización.
  final String keyName;

  static List<ShellDestination> of(ShellRole role) => [
        for (final d in values)
          if (d.role == role) d
      ];
}

/// Anchos donde cambia el marco.
abstract final class ShellBreakpoints {
  /// Desde aquí, barra lateral completa.
  static const desktop = 1024.0;

  /// Desde aquí, riel lateral con solo íconos; por debajo, barra inferior.
  static const tablet = 700.0;

  /// Ancho máximo del contenido, centrado.
  static const contentMaxWidth = 1120.0;
}

/// Datos de la sesión y navegación que la app entrega a todas las pantallas
/// (lo arma `main.dart`). Sin él, el marco se dibuja igual y usa lo que la
/// pantalla le pase.
class FixiaShellScope extends InheritedWidget {
  const FixiaShellScope({
    super.key,
    required super.child,
    this.userName,
    this.userCaption,
    this.onNavigate,
    this.onLogout,
    this.onPrimaryAction,
  });

  final String? userName;
  final String? userCaption;
  final ValueChanged<ShellDestination>? onNavigate;
  final VoidCallback? onLogout;

  /// Acción principal del rol (cliente: publicar un problema).
  final VoidCallback? onPrimaryAction;

  static FixiaShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FixiaShellScope>();

  @override
  bool updateShouldNotify(FixiaShellScope oldWidget) =>
      userName != oldWidget.userName ||
      userCaption != oldWidget.userCaption ||
      onNavigate != oldWidget.onNavigate ||
      onLogout != oldWidget.onLogout ||
      onPrimaryAction != oldWidget.onPrimaryAction;
}

/// Marco de la app con sesión: barra lateral en escritorio, riel en tablet y
/// barra inferior en celular. El contenido se centra con un ancho máximo
/// para que en navegador no se vea como una pantalla de celular estirada.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.destination,
    required this.child,
    this.userName,
    this.userCaption,
    this.onNavigate,
    this.onLogout,
    this.onPrimaryAction,
    this.mobileTitle,
    this.mobileActions = const [],
  });

  /// Destino activo; también define el rol y su menú.
  final ShellDestination destination;
  final Widget child;
  final String? userName;
  final String? userCaption;
  final ValueChanged<ShellDestination>? onNavigate;
  final VoidCallback? onLogout;
  final VoidCallback? onPrimaryAction;

  /// Título de la barra superior en celular; si es `null`, el logo.
  final String? mobileTitle;
  final List<Widget> mobileActions;

  ShellRole get role => destination.role;

  @override
  Widget build(BuildContext context) {
    final scope = FixiaShellScope.maybeOf(context);
    final config = _ShellConfig(
      role: role,
      current: destination,
      userName: userName ?? scope?.userName ?? '',
      userCaption: userCaption ?? scope?.userCaption ?? _roleLabel(role),
      onNavigate: onNavigate ?? scope?.onNavigate,
      onLogout: onLogout ?? scope?.onLogout,
      onPrimaryAction: onPrimaryAction ?? scope?.onPrimaryAction,
    );
    return Scaffold(
      backgroundColor: FixiaColors.neutralBackground,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final content =
              _Content(compact: width < ShellBreakpoints.tablet, child: child);
          if (width >= ShellBreakpoints.desktop) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Sidebar(config: config),
                Expanded(child: content),
              ],
            );
          }
          if (width >= ShellBreakpoints.tablet) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Rail(config: config),
                Expanded(child: content),
              ],
            );
          }
          return Column(
            children: [
              _MobileTopBar(
                config: config,
                title: mobileTitle,
                actions: mobileActions,
              ),
              Expanded(child: content),
              _BottomBar(config: config),
            ],
          );
        },
      ),
    );
  }
}

String _roleLabel(ShellRole role) => switch (role) {
      ShellRole.client => 'Cliente',
      ShellRole.technician => 'Técnico',
      ShellRole.company => 'Empresa',
    };

String _logoutKey(ShellRole role) => switch (role) {
      ShellRole.client => 'client-dashboard-logout',
      ShellRole.technician => 'technician-dashboard-logout',
      ShellRole.company => 'company-logout',
    };

/// Iniciales para el avatar, sin inventar un nombre.
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+'))
    ..removeWhere((p) => p.isEmpty);
  if (parts.isEmpty) return '·';
  return parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
}

class _ShellConfig {
  const _ShellConfig({
    required this.role,
    required this.current,
    required this.userName,
    required this.userCaption,
    required this.onNavigate,
    required this.onLogout,
    required this.onPrimaryAction,
  });

  final ShellRole role;
  final ShellDestination current;
  final String userName;
  final String userCaption;
  final ValueChanged<ShellDestination>? onNavigate;
  final VoidCallback? onLogout;
  final VoidCallback? onPrimaryAction;

  /// Cliente: marco claro con el logo. Técnico y empresa: marco oscuro
  /// «PRO», para distinguir de un vistazo el lado del prestador.
  bool get dark => role != ShellRole.client;

  List<ShellDestination> get destinations => ShellDestination.of(role);

  void go(ShellDestination d) {
    if (d == current) return;
    onNavigate?.call(d);
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.compact, required this.child});

  final bool compact;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // El tema global estira los botones a todo el ancho (pensado para
    // formularios de celular). Dentro del marco miden lo que su texto pide;
    // quien necesite ancho completo lo pide con su propio contenedor.
    final theme = Theme.of(context);
    const size = Size(64, 46);
    const padding = EdgeInsets.symmetric(horizontal: 18, vertical: 12);
    return Theme(
      data: theme.copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(minimumSize: size, padding: padding)
              .merge(theme.filledButtonTheme.style),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(minimumSize: size, padding: padding)
              .merge(theme.outlinedButtonTheme.style),
        ),
      ),
      child: SingleChildScrollView(
        padding: compact
            ? const EdgeInsets.fromLTRB(16, 20, 16, 28)
            : const EdgeInsets.fromLTRB(40, 32, 40, 48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
                maxWidth: ShellBreakpoints.contentMaxWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.dark, this.compact = false});

  final bool dark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!dark) {
      return Image.asset(
        'assets/brand/fixia_logo.png',
        width: compact ? 44 : 104,
        height: 38,
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        semanticLabel: 'Fixia',
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          compact ? 'F' : 'Fixia',
          style: const TextStyle(
            color: FixiaColors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: FixiaColors.accent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'PRO',
              style: TextStyle(
                color: FixiaColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.config});

  final _ShellConfig config;

  @override
  Widget build(BuildContext context) {
    final dark = config.dark;
    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: dark ? FixiaColors.primary : FixiaColors.white,
        border: dark
            ? null
            : const Border(right: BorderSide(color: Color(0xFFE3EAF4))),
      ),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _Brand(dark: dark),
            ),
          ),
          const SizedBox(height: 28),
          Semantics(
            container: true,
            label: 'Navegación principal',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final d in config.destinations)
                  _SideItem(
                    destination: d,
                    selected: d == config.current,
                    dark: dark,
                    onTap: () => config.go(d),
                  ),
              ],
            ),
          ),
          if (config.role == ShellRole.client &&
              config.onPrimaryAction != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('client-publish-problem'),
              onPressed: config.onPrimaryAction,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Publicar un problema'),
            ),
          ],
          const Spacer(),
          _UserCard(config: config),
        ],
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({
    required this.destination,
    required this.selected,
    required this.dark,
    required this.onTap,
  });

  final ShellDestination destination;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = dark
        ? (selected ? FixiaColors.white : const Color(0xFFB7CCE8))
        : (selected ? FixiaColors.primary : FixiaColors.textSecondary);
    final bg = selected
        ? (dark ? const Color(0x1FFFFFFF) : FixiaColors.supportBackground)
        : Colors.transparent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            key: ValueKey(destination.keyName),
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Icon(destination.icon, size: 21, color: fg),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      destination.label,
                      style: TextStyle(
                        color: fg,
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
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

class _UserCard extends StatelessWidget {
  const _UserCard({required this.config});

  final _ShellConfig config;

  @override
  Widget build(BuildContext context) {
    final dark = config.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? const Color(0x14FFFFFF) : FixiaColors.white,
        borderRadius: BorderRadius.circular(12),
        border: dark ? null : Border.all(color: const Color(0xFFE3EAF4)),
      ),
      child: Row(
        children: [
          _Avatar(name: config.userName, dark: dark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.userName.isEmpty ? 'Mi cuenta' : config.userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: dark ? FixiaColors.white : FixiaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  config.userCaption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: dark
                        ? const Color(0xFFB7CCE8)
                        : FixiaColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (config.onLogout != null)
            IconButton(
              key: ValueKey(_logoutKey(config.role)),
              tooltip: 'Cerrar sesión',
              onPressed: config.onLogout,
              icon: Icon(
                Icons.logout_rounded,
                size: 20,
                color:
                    dark ? const Color(0xFFB7CCE8) : FixiaColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.dark, this.size = 38});

  final String name;
  final bool dark;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: dark ? FixiaColors.supportBackground : FixiaColors.primary,
          shape: BoxShape.circle,
        ),
        child: Text(
          initialsOf(name),
          style: TextStyle(
            color: dark ? FixiaColors.primary : FixiaColors.white,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.36,
          ),
        ),
      );
}

class _Rail extends StatelessWidget {
  const _Rail({required this.config});

  final _ShellConfig config;

  @override
  Widget build(BuildContext context) {
    final dark = config.dark;
    final fgIdle = dark ? const Color(0xFFB7CCE8) : FixiaColors.textSecondary;
    return Container(
      width: 84,
      decoration: BoxDecoration(
        color: dark ? FixiaColors.primary : FixiaColors.white,
        border: dark
            ? null
            : const Border(right: BorderSide(color: Color(0xFFE3EAF4))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          _Brand(dark: dark, compact: true),
          const SizedBox(height: 24),
          for (final d in config.destinations)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Tooltip(
                message: d.label,
                child: Material(
                  color: d == config.current
                      ? (dark
                          ? const Color(0x1FFFFFFF)
                          : FixiaColors.supportBackground)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    key: ValueKey(d.keyName),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => config.go(d),
                    child: SizedBox(
                      width: 56,
                      height: 48,
                      child: Icon(
                        d.icon,
                        semanticLabel: d.label,
                        color: d == config.current
                            ? (dark ? FixiaColors.white : FixiaColors.primary)
                            : fgIdle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (config.role == ShellRole.client && config.onPrimaryAction != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: IconButton.filled(
                key: const ValueKey('client-publish-problem'),
                tooltip: 'Publicar un problema',
                onPressed: config.onPrimaryAction,
                icon: const Icon(Icons.add_rounded),
              ),
            ),
          const Spacer(),
          _Avatar(name: config.userName, dark: dark, size: 40),
          if (config.onLogout != null)
            IconButton(
              key: ValueKey(_logoutKey(config.role)),
              tooltip: 'Cerrar sesión',
              onPressed: config.onLogout,
              icon: Icon(Icons.logout_rounded, color: fgIdle),
            ),
        ],
      ),
    );
  }
}

class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar({
    required this.config,
    required this.title,
    required this.actions,
  });

  final _ShellConfig config;
  final String? title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final dark = config.dark;
    return Material(
      color: dark ? FixiaColors.primary : FixiaColors.white,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: dark
              ? null
              : const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE3EAF4))),
                ),
          child: Row(
            children: [
              const SizedBox(width: 4),
              if (title == null)
                _Brand(dark: dark)
              else
                Expanded(
                  child: Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: dark ? FixiaColors.white : FixiaColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (title == null) const Spacer(),
              ...actions,
              if (config.onLogout != null)
                IconButton(
                  key: ValueKey(_logoutKey(config.role)),
                  tooltip: 'Cerrar sesión',
                  onPressed: config.onLogout,
                  icon: Icon(
                    Icons.logout_rounded,
                    color: dark ? FixiaColors.white : FixiaColors.textSecondary,
                  ),
                ),
              _Avatar(name: config.userName, dark: dark, size: 34),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.config});

  final _ShellConfig config;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    final destinations = config.destinations;
    for (var i = 0; i < destinations.length; i++) {
      final d = destinations[i];
      items.add(_BottomItem(
        keyName: d.keyName,
        icon: d.icon,
        label: _shortLabel(d),
        selected: d == config.current,
        onTap: () => config.go(d),
      ));
      // El botón de publicar del cliente va en el centro.
      if (config.role == ShellRole.client &&
          config.onPrimaryAction != null &&
          i == 1) {
        items.add(_BottomItem(
          keyName: 'client-publish-problem',
          icon: Icons.add_rounded,
          label: 'Publicar',
          selected: false,
          primary: true,
          onTap: config.onPrimaryAction!,
        ));
      }
    }
    return Material(
      color: FixiaColors.white,
      child: SafeArea(
        top: false,
        child: Container(
          height: 66,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE3EAF4))),
          ),
          child: Row(children: [for (final w in items) Expanded(child: w)]),
        ),
      ),
    );
  }

  String _shortLabel(ShellDestination d) => switch (d) {
        ShellDestination.clientRequests => 'Solicitudes',
        ShellDestination.clientProfile ||
        ShellDestination.technicianProfile =>
          'Perfil',
        ShellDestination.technicianJobs => 'Trabajos',
        ShellDestination.companyTechnicians => 'Técnicos',
        _ => d.label,
      };
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.keyName,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.primary = false,
  });

  final String keyName;
  final IconData icon;
  final String label;
  final bool selected;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        selected || primary ? FixiaColors.secondary : FixiaColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        key: ValueKey(keyName),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (primary)
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: FixiaColors.secondary,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: FixiaColors.white, size: 22),
              )
            else
              Icon(icon, color: color, size: 23),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
