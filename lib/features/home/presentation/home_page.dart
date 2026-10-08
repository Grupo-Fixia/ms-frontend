import 'package:flutter/material.dart';

import '../../../core/theme/fixia_theme.dart';

/// Página de inicio pública: presenta Fixia y lleva al registro según el rol
/// (cliente o técnico) o al inicio de sesión.
///
/// Orden de secciones, como en otros marketplaces de servicios: propuesta de
/// valor con confianza, servicios, cómo funciona y elección de perfil.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.onRegisterClient,
    required this.onLogin,
    this.onRegisterTechnician,
  });

  /// Lleva al registro de cliente.
  final VoidCallback onRegisterClient;

  /// Lleva al inicio de sesión.
  final VoidCallback onLogin;

  /// Lleva al registro de técnico. Mientras sea `null` la tarjeta del técnico
  /// se muestra como "Próximamente".
  final VoidCallback? onRegisterTechnician;

  /// Ancho desde el que el contenido se reparte en columnas.
  static const wideBreakpoint = 880.0;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _roleSectionKey = GlobalKey();

  /// "Registrarse" baja hasta la elección de perfil (cliente o técnico).
  Future<void> _goToRoleSection() async {
    final context = _roleSectionKey.currentContext;
    if (context == null) return;
    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= HomePage.wideBreakpoint;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Band(
                    isWide: isWide,
                    top: 16,
                    bottom: isWide ? 72 : 40,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TopBar(
                          isWide: isWide,
                          onLogin: widget.onLogin,
                          onRegister: _goToRoleSection,
                        ),
                        SizedBox(height: isWide ? 56 : 32),
                        _Hero(
                          isWide: isWide,
                          onFindTechnician: widget.onRegisterClient,
                        ),
                      ],
                    ),
                  ),
                  _Band(
                    isWide: isWide,
                    color: FixiaColors.white,
                    child: _ServicesSection(isWide: isWide),
                  ),
                  _Band(
                    isWide: isWide,
                    child: _HowItWorksSection(isWide: isWide),
                  ),
                  _Band(
                    key: _roleSectionKey,
                    isWide: isWide,
                    color: FixiaColors.white,
                    child: _RoleSection(
                      isWide: isWide,
                      onRegisterClient: widget.onRegisterClient,
                      onRegisterTechnician: widget.onRegisterTechnician,
                    ),
                  ),
                  _Band(
                    isWide: isWide,
                    color: FixiaColors.primary,
                    top: 28,
                    bottom: 28,
                    child: const _Footer(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Franja de ancho completo con el contenido centrado y limitado.
class _Band extends StatelessWidget {
  const _Band({
    super.key,
    required this.isWide,
    required this.child,
    this.color,
    this.top,
    this.bottom,
  });

  static const _maxContentWidth = 1080.0;

  final bool isWide;
  final Widget child;
  final Color? color;
  final double? top;
  final double? bottom;

  @override
  Widget build(BuildContext context) {
    final vertical = isWide ? 72.0 : 44.0;
    return ColoredBox(
      color: color ?? FixiaColors.neutralBackground,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isWide ? 40 : 16,
          top ?? vertical,
          isWide ? 40 : 16,
          bottom ?? vertical,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Encabezado de cada sección: título y bajada centrados.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: FixiaColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.isWide,
    required this.onLogin,
    required this.onRegister,
  });

  final bool isWide;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(FixiaRadii.input),
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          key: const ValueKey('home-login'),
          onPressed: onLogin,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: buttonShape,
          ),
          child: const Text('Iniciar sesión'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          key: const ValueKey('home-register'),
          onPressed: onRegister,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shape: buttonShape,
          ),
          child: const Text('Registrarse'),
        ),
      ],
    );
    return Row(
      children: [
        // El logo cede espacio en pantallas angostas.
        Flexible(
          flex: 2,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Image.asset(
              'assets/brand/fixia_logo.png',
              height: isWide ? 36 : 30,
              semanticLabel: 'Fixia',
            ),
          ),
        ),
        const SizedBox(width: 12),
        // En celulares muy angostos los botones se reducen en vez de desbordar.
        Flexible(
          flex: 5,
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(fit: BoxFit.scaleDown, child: actions),
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.isWide, required this.onFindTechnician});

  final bool isWide;
  final VoidCallback onFindTechnician;

  @override
  Widget build(BuildContext context) {
    final intro =
        _HeroIntro(isWide: isWide, onFindTechnician: onFindTechnician);
    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [intro, const SizedBox(height: 32), const _WhyFixiaPanel()],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(flex: 6, child: intro),
        const SizedBox(width: 48),
        const Expanded(flex: 5, child: _WhyFixiaPanel()),
      ],
    );
  }
}

class _HeroIntro extends StatelessWidget {
  const _HeroIntro({required this.isWide, required this.onFindTechnician});

  final bool isWide;
  final VoidCallback onFindTechnician;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.headlineLarge?.copyWith(
      fontSize: isWide ? 44 : 32,
      height: isWide ? 52 / 44 : 40 / 32,
    );
    final cta = FilledButton.icon(
      key: const ValueKey('home-hero-cta'),
      onPressed: onFindTechnician,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 28),
      ),
      icon: const Icon(Icons.search_rounded, size: 20),
      label: const Text('Encontrar un técnico'),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Eyebrow(text: 'Servicios técnicos para tu hogar'),
        const SizedBox(height: 16),
        Text(
          'El técnico que necesitas, cuando lo necesitas.',
          key: const ValueKey('home-title'),
          style: titleStyle,
        ),
        const SizedBox(height: 16),
        Text(
          'Fixia conecta a personas que necesitan una reparación con técnicos '
          'verificados de su zona. Pides el servicio, eliges al técnico y '
          'sigues todo desde un solo lugar.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: FixiaColors.textSecondary,
            fontSize: isWide ? 18 : 16,
            height: isWide ? 28 / 18 : 24 / 16,
          ),
        ),
        const SizedBox(height: 28),
        if (isWide) cta else SizedBox(width: double.infinity, child: cta),
      ],
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FixiaColors.supportBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: FixiaColors.secondary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

/// Tarjeta oscura con las tres razones para usar Fixia.
class _WhyFixiaPanel extends StatelessWidget {
  const _WhyFixiaPanel();

  static const _reasons = [
    (
      icon: Icons.verified_user_outlined,
      title: 'Técnicos verificados',
      text: 'Revisamos la identidad de cada técnico antes de que preste '
          'servicios.',
    ),
    (
      icon: Icons.place_outlined,
      title: 'Cerca de ti',
      text: 'Te mostramos técnicos que trabajan en tu zona.',
    ),
    (
      icon: Icons.star_outline_rounded,
      title: 'Opiniones reales',
      text: 'Cada servicio se califica, así eliges con confianza.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      key: const ValueKey('home-why-fixia'),
      decoration: BoxDecoration(
        color: FixiaColors.primary,
        borderRadius: BorderRadius.circular(FixiaRadii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Por qué Fixia?',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(color: FixiaColors.white),
            ),
            const SizedBox(height: 20),
            for (var i = 0; i < _reasons.length; i++) ...[
              if (i > 0) const SizedBox(height: 18),
              _Reason(
                icon: _reasons[i].icon,
                title: _reasons[i].title,
                text: _reasons[i].text,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Reason extends StatelessWidget {
  const _Reason({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            // Blanco al 12 % sobre el azul oscuro de la marca.
            color: const Color(0x1FFFFFFF),
            borderRadius: BorderRadius.circular(FixiaRadii.input),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: FixiaColors.accent, size: 22),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: FixiaColors.white),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: FixiaColors.supportBackground),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Oficios de muestra (los mismos del formulario de técnico, aún
/// provisionales). Es informativo: no es un buscador.
class _ServicesSection extends StatelessWidget {
  const _ServicesSection({required this.isWide});

  final bool isWide;

  static const _services = [
    (icon: Icons.electrical_services_outlined, label: 'Electricidad'),
    (icon: Icons.plumbing_outlined, label: 'Plomería'),
    (icon: Icons.carpenter_outlined, label: 'Carpintería'),
    (icon: Icons.format_paint_outlined, label: 'Pintura'),
    (icon: Icons.key_outlined, label: 'Cerrajería'),
    (icon: Icons.foundation_outlined, label: 'Albañilería'),
    (icon: Icons.ac_unit_outlined, label: 'Refrigeración'),
    (icon: Icons.yard_outlined, label: 'Jardinería'),
  ];

  @override
  Widget build(BuildContext context) {
    final columns = isWide ? 4 : 2;
    const gap = 16.0;
    return Column(
      key: const ValueKey('home-services'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeading(
          title: 'Servicios para cada arreglo',
          subtitle: 'Técnicos de los oficios que más se necesitan en casa.',
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final service in _services)
                  SizedBox(
                    width: tileWidth,
                    child: _ServiceTile(
                      icon: service.icon,
                      label: service.label,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FixiaColors.neutralBackground,
        borderRadius: BorderRadius.circular(FixiaRadii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 22),
        child: Column(
          children: [
            Icon(icon, color: FixiaColors.secondary, size: 32),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: FixiaColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection({required this.isWide});

  final bool isWide;

  static const _steps = [
    (
      title: 'Cuéntanos qué necesitas',
      text: 'Describe el arreglo y dónde lo necesitas.',
    ),
    (
      title: 'Elige a tu técnico',
      text: 'Compara perfiles y calificaciones de técnicos de tu zona.',
    ),
    (
      title: 'Listo y calificado',
      text: 'Recibe el servicio y califica al técnico para ayudar a otros.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final steps = [
      for (var i = 0; i < _steps.length; i++)
        _Step(number: i + 1, title: _steps[i].title, text: _steps[i].text),
    ];
    return Column(
      key: const ValueKey('home-how-it-works'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeading(
          title: 'Así funciona',
          subtitle: 'Tres pasos y tu arreglo queda en buenas manos.',
        ),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0) const SizedBox(width: 32),
                Expanded(child: steps[i]),
              ],
            ],
          )
        else
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(height: 24),
            steps[i],
          ],
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.text});

  final int number;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: FixiaColors.secondary,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: FixiaColors.white),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: FixiaColors.primary,
                  fontSize: 17,
                  height: 24 / 17,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                text,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: FixiaColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoleSection extends StatelessWidget {
  const _RoleSection({
    required this.isWide,
    required this.onRegisterClient,
    required this.onRegisterTechnician,
  });

  final bool isWide;
  final VoidCallback onRegisterClient;
  final VoidCallback? onRegisterTechnician;

  @override
  Widget build(BuildContext context) {
    final clientCard = _RoleCard(
      key: const ValueKey('home-role-client'),
      icon: Icons.home_repair_service_outlined,
      title: 'Necesito un técnico',
      description: 'Crea tu cuenta, pide un servicio y recibe ayuda de '
          'técnicos verificados cerca de ti.',
      actionLabel: 'Registrarme como cliente',
      actionKey: const ValueKey('home-register-client'),
      onPressed: onRegisterClient,
      highlighted: true,
      fillHeight: isWide,
    );
    final technicianCard = _RoleCard(
      key: const ValueKey('home-role-technician'),
      icon: Icons.handyman_outlined,
      title: 'Soy técnico',
      description: 'Ofrece tus servicios, consigue nuevos clientes y haz '
          'crecer tu trabajo.',
      actionLabel: 'Registrarme como técnico',
      actionKey: const ValueKey('home-register-technician'),
      onPressed: onRegisterTechnician,
      fillHeight: isWide,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeading(
          title: '¿Cómo quieres usar Fixia?',
          subtitle: 'Elige tu perfil para crear la cuenta.',
        ),
        if (isWide)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: clientCard),
                const SizedBox(width: 20),
                Expanded(child: technicianCard),
              ],
            ),
          )
        else ...[
          clientCard,
          const SizedBox(height: 16),
          technicianCard,
        ],
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.actionKey,
    required this.onPressed,
    this.highlighted = false,
    this.fillHeight = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final Key actionKey;

  /// Si es `null` la opción aún no está disponible.
  final VoidCallback? onPressed;

  /// La opción principal lleva el botón relleno; la otra, con borde.
  final bool highlighted;

  /// En dos columnas ambas tarjetas miden lo mismo y el botón queda abajo.
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAvailable = onPressed != null;
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(FixiaRadii.input),
    );

    final Widget action;
    if (!isAvailable) {
      action = OutlinedButton(
        key: actionKey,
        onPressed: null,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: buttonShape,
        ),
        child: const Text('Próximamente'),
      );
    } else if (highlighted) {
      action = FilledButton(
        key: actionKey,
        onPressed: onPressed,
        child: Text(actionLabel),
      );
    } else {
      action = OutlinedButton(
        key: actionKey,
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: FixiaColors.secondary,
          minimumSize: const Size.fromHeight(52),
          shape: buttonShape,
          side: const BorderSide(color: FixiaColors.secondary, width: 1.5),
          textStyle: theme.textTheme.labelLarge,
        ),
        child: Text(actionLabel),
      );
    }

    return DecoratedBox(
      decoration: FixiaDecorations.card,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: FixiaColors.supportBackground,
                borderRadius: BorderRadius.circular(FixiaRadii.input),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(icon, color: FixiaColors.secondary, size: 28),
              ),
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: FixiaColors.textSecondary),
            ),
            const SizedBox(height: 24),
            if (fillHeight) const Spacer(),
            action,
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          'Fixia',
          style: theme.textTheme.headlineSmall
              ?.copyWith(color: FixiaColors.white),
        ),
        const SizedBox(height: 6),
        Text(
          'Técnicos de confianza para tu hogar.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: FixiaColors.supportBackground),
        ),
        const SizedBox(height: 14),
        Text(
          '© ${DateTime.now().year} Fixia',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: FixiaColors.supportBackground),
        ),
      ],
    );
  }
}
