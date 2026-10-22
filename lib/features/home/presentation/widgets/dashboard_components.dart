import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import '../../../../core/theme/fixia_theme.dart';

/// Permite desplazar listas horizontales también con mouse (web/escritorio).
class DragScrollBehavior extends MaterialScrollBehavior {
  const DragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class DashboardShell extends StatelessWidget {
  const DashboardShell({
    required this.child,
    this.bottomNavigationBar,
    this.contentPadding = const EdgeInsets.fromLTRB(18, 16, 18, 24),
    super.key,
  });

  final Widget child;
  final Widget? bottomNavigationBar;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FixiaColors.neutralBackground,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 440;
          final height =
              constraints.maxHeight > 900 ? 900.0 : constraints.maxHeight;
          return Center(
            child: Container(
              width: isDesktop ? 440 : constraints.maxWidth,
              height: isDesktop ? height : constraints.maxHeight,
              decoration: BoxDecoration(
                color: FixiaColors.white,
                borderRadius:
                    isDesktop ? BorderRadius.circular(28) : BorderRadius.zero,
                border: isDesktop
                    ? Border.all(color: const Color(0xFFDCE5F0))
                    : null,
                boxShadow: isDesktop
                    ? const [
                        BoxShadow(
                          color: Color(0x1201255D),
                          blurRadius: 32,
                          offset: Offset(0, 12),
                        ),
                      ]
                    : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Expanded(
                    child: SafeArea(
                      bottom: bottomNavigationBar == null,
                      child: SingleChildScrollView(
                        padding: contentPadding,
                        child: child,
                      ),
                    ),
                  ),
                  if (bottomNavigationBar != null)
                    SafeArea(
                      top: false,
                      child: bottomNavigationBar!,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class MobileFeatureShell extends StatelessWidget {
  const MobileFeatureShell({
    required this.title,
    required this.child,
    required this.onBack,
    this.bottomNavigationItems = const [],
    this.maxWidth = 440,
    super.key,
  });

  final String title;
  final Widget child;
  final VoidCallback onBack;
  final List<MobileNavigationItem> bottomNavigationItems;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FixiaColors.neutralBackground,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > maxWidth;
          final height =
              constraints.maxHeight > 900 ? 900.0 : constraints.maxHeight;
          return Center(
            child: Container(
              width: isWide ? maxWidth : constraints.maxWidth,
              height: isWide ? height : constraints.maxHeight,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: FixiaColors.white,
                borderRadius:
                    isWide ? BorderRadius.circular(28) : BorderRadius.zero,
                border:
                    isWide ? Border.all(color: const Color(0xFFDCE5F0)) : null,
                boxShadow: isWide
                    ? const [
                        BoxShadow(
                          color: Color(0x1201255D),
                          blurRadius: 32,
                          offset: Offset(0, 12),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                children: [
                  SafeArea(
                    bottom: false,
                    child: _MobileFeatureHeader(
                      title: title,
                      onBack: onBack,
                    ),
                  ),
                  Expanded(child: child),
                  if (bottomNavigationItems.isNotEmpty)
                    SafeArea(
                      top: false,
                      child: MobileNavigationBar(
                        items: bottomNavigationItems,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class MobileNavigationItem {
  const MobileNavigationItem({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.isAction = false,
    this.itemKey,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool selected;
  final bool isAction;
  final Key? itemKey;
}

class MobileNavigationBar extends StatelessWidget {
  const MobileNavigationBar({
    required this.items,
    super.key,
  });

  final List<MobileNavigationItem> items;

  @override
  Widget build(BuildContext context) {
    final hasAction = items.any((item) => item.isAction);
    return Container(
      height: hasAction ? 76 : 64,
      decoration: const BoxDecoration(
        color: FixiaColors.white,
        border: Border(top: BorderSide(color: FixiaColors.supportBackground)),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: InkWell(
                key: item.itemKey ??
                    ValueKey('mobile-nav-${item.label.toLowerCase()}'),
                onTap: item.onPressed,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: hasAction ? 44 : 24,
                      child: Center(
                        child: item.isAction
                            ? Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: item.selected
                                      ? FixiaColors.white
                                      : FixiaColors.secondary,
                                  shape: BoxShape.circle,
                                  border: item.selected
                                      ? Border.all(
                                          color: FixiaColors.secondary,
                                          width: 2.5)
                                      : null,
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x30006DFD),
                                      blurRadius: 12,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(item.icon,
                                    size: 26,
                                    color: item.selected
                                        ? FixiaColors.secondary
                                        : FixiaColors.white),
                              )
                            : Icon(
                                item.icon,
                                size: 22,
                                color: item.selected
                                    ? FixiaColors.secondary
                                    : const Color(0xFF9AAABD),
                              ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: item.selected
                            ? FixiaColors.secondary
                            : FixiaColors.textSecondary,
                        fontSize: 10,
                        fontWeight:
                            item.selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MobileFeatureHeader extends StatelessWidget {
  const _MobileFeatureHeader({
    required this.title,
    required this.onBack,
  });

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      color: FixiaColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver',
            onPressed: onBack,
            color: FixiaColors.white,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: FixiaColors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardSectionHeading extends StatelessWidget {
  const DashboardSectionHeading({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.headlineSmall),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

class ApproximateLocationLabel extends StatelessWidget {
  const ApproximateLocationLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FixiaColors.supportBackground,
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on_outlined, size: 15),
            SizedBox(width: 4),
            Flexible(
              child: Text(
                'Ubicación aproximada',
                softWrap: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardCard extends StatelessWidget {
  const DashboardCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: FixiaDecorations.card,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }
}
