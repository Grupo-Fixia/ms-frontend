import 'package:flutter/material.dart';

import '../theme/fixia_theme.dart';

/// Piezas comunes de las pantallas con sesión, con el mismo lenguaje visual
/// del login y la landing (tarjetas blancas con borde suave, títulos en el
/// azul oscuro de la marca y acentos en azul).

const _border = Color(0xFFE3EAF4);

/// Encabezado de página: título grande, subtítulo y acciones a la derecha
/// (debajo en pantallas angostas).
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.titleKey,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Key? titleKey;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 640;
          final heading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                key: titleKey,
                style: TextStyle(
                  fontSize: narrow ? 24 : 30,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: FixiaColors.primary,
                  letterSpacing: -0.5,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 15,
                    color: FixiaColors.textSecondary,
                  ),
                ),
              ],
            ],
          );
          final buttons = Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          );
          if (actions.isEmpty) return heading;
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, const SizedBox(height: 14), buttons],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: heading),
              const SizedBox(width: 16),
              Flexible(child: buttons),
            ],
          );
        },
      );
}

/// Tarjeta blanca con borde suave.
class FixiaPanel extends StatelessWidget {
  const FixiaPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.highlight,
    this.color = FixiaColors.white,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Color del borde resaltado (p. ej. la versión vigente); `null` = normal.
  final Color? highlight;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlight ?? _border,
            width: highlight == null ? 1 : 2,
          ),
        ),
        child: child,
      );
}

/// Indicador del resumen: un número real (o «–» mientras carga).
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.emphasis = false,
    this.compact = false,
  });

  final String label;
  final String value;
  final String? caption;
  final bool emphasis;

  /// Versión pequeña para celular: varias en una fila, sin la descripción.
  final bool compact;

  StatCard _compact() => StatCard(
        key: key,
        label: label,
        value: value,
        emphasis: emphasis,
        compact: true,
      );

  @override
  Widget build(BuildContext context) => FixiaPanel(
        padding: compact ? const EdgeInsets.all(12) : const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            if (!compact)
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: FixiaColors.textSecondary,
                ),
              ),
            if (!compact) const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: compact ? 22 : 30,
                fontWeight: FontWeight.w800,
                color: emphasis ? FixiaColors.secondary : FixiaColors.primary,
              ),
            ),
            if (compact)
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: FixiaColors.textSecondary,
                ),
              ),
            if (!compact && caption != null) ...[
              const SizedBox(height: 2),
              Text(
                caption!,
                style: const TextStyle(
                  fontSize: 12,
                  color: FixiaColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      );
}

/// Varios [StatCard] en fila. En celular se muestran en versión pequeña,
/// todos en una fila, para no ocupar la pantalla.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.children, this.minItemWidth = 200});

  final List<StatCard> children;
  final double minItemWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final fits = constraints.maxWidth >=
              children.length * minItemWidth + (children.length - 1) * 14;
          if (fits || constraints.maxWidth >= 600) {
            return ResponsiveGrid(
              minItemWidth: minItemWidth,
              children: children,
            );
          }
          return Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: children[i]._compact()),
              ],
            ],
          );
        },
      );
}

/// Cuadrícula de ancho fluido: tantas columnas como quepan con
/// [minItemWidth]. En celular, [compactColumns] (por defecto una).
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 280,
    this.spacing = 14,
    this.compactColumns = 1,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final int compactColumns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          var columns = ((width + spacing) / (minItemWidth + spacing)).floor();
          if (columns < 1) columns = compactColumns.clamp(1, children.length);
          columns = columns.clamp(1, children.isEmpty ? 1 : children.length);
          final itemWidth = (width - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final child in children)
                SizedBox(width: itemWidth, child: child),
            ],
          );
        },
      );
}

/// Contenido principal y una columna lateral; en pantallas angostas la
/// lateral pasa debajo.
class TwoColumns extends StatelessWidget {
  const TwoColumns({
    super.key,
    required this.main,
    required this.side,
    this.sideWidth = 340,
    this.breakpoint = 900,
    this.sideFirstWhenStacked = false,
  });

  final Widget main;
  final Widget side;
  final double sideWidth;
  final double breakpoint;
  final bool sideFirstWhenStacked;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= breakpoint) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: main),
                const SizedBox(width: 24),
                SizedBox(width: sideWidth, child: side),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: sideFirstWhenStacked
                ? [side, const SizedBox(height: 20), main]
                : [main, const SizedBox(height: 20), side],
          );
        },
      );
}

/// Título de sección con una acción opcional a la derecha.
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: FixiaColors.primary,
                ),
              ),
            ),
            if (action != null) action!,
          ],
        ),
      );
}

/// Tono de una etiqueta de estado.
enum PillTone { neutral, info, success, warning }

/// Etiqueta redondeada de estado.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.tone = PillTone.info});

  final String label;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      PillTone.neutral => (const Color(0xFFEEF2F7), FixiaColors.textSecondary),
      PillTone.info => (FixiaColors.supportBackground, FixiaColors.primary),
      PillTone.success => (const Color(0xFFDCF5EF), const Color(0xFF00745F)),
      PillTone.warning => (const Color(0xFFFFF4DF), const Color(0xFF7A4B00)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

/// Aviso de una línea o dos (verificación pendiente, información).
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.message,
    this.tone = PillTone.warning,
    this.icon,
  });

  final String message;
  final PillTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg) = switch (tone) {
      PillTone.warning => (
          const Color(0xFFFFF4DF),
          const Color(0xFFE8B25A),
          const Color(0xFF5C3B00)
        ),
      PillTone.success => (
          const Color(0xFFE5F7F3),
          FixiaColors.accent,
          const Color(0xFF00574A)
        ),
      PillTone.info => (
          FixiaColors.supportBackground,
          const Color(0xFF9CC3FF),
          FixiaColors.primary
        ),
      PillTone.neutral => (
          const Color(0xFFEEF2F7),
          _border,
          FixiaColors.textSecondary
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: fg, size: 20),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(message, style: TextStyle(color: fg, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

/// Mensaje cuando no hay datos o hubo un error; nunca datos de ejemplo.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => FixiaPanel(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF9AAABB), size: 32),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: FixiaColors.textSecondary),
            ),
            if (action != null) ...[
              const SizedBox(height: 12),
              action!,
            ],
          ],
        ),
      );
}

/// Indicador de carga dentro de una sección.
class SectionLoading extends StatelessWidget {
  const SectionLoading({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
}
