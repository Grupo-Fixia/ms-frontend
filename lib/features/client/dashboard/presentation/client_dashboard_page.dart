import 'package:flutter/material.dart';

import '../../../../core/theme/fixia_theme.dart';
import '../../../home/presentation/widgets/dashboard_components.dart';

class ClientDashboardPage extends StatefulWidget {
  const ClientDashboardPage({
    super.key,
    this.firstName,
    this.onPublishProblem,
    this.onOpenSettings,
    this.onOpenHistory,
    this.onOpenProfile,
    this.onLogout,
    this.onRequestTechnician,
    this.onOpenChat,
    this.onReviewQuote,
    this.onOpenApplicants,
    this.onOpenTechnicianProfile,
    this.receivedQuotes = const [],
    this.onOpenQuote,
    this.onConfirmClosure,
  });

  final String? firstName;
  final VoidCallback? onPublishProblem;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onLogout;
  final ValueChanged<String>? onRequestTechnician;
  final VoidCallback? onOpenChat;
  final VoidCallback? onReviewQuote;

  /// Abre los postulantes de la solicitud publicada (GC-349).
  final VoidCallback? onOpenApplicants;

  /// Abre el perfil público de un técnico recomendado (GC-350).
  final ValueChanged<String>? onOpenTechnicianProfile;

  /// Cotizaciones recibidas por el cliente y acción para abrir cada una
  /// (GC-355 y GC-360).
  final List<ReceivedQuoteSummary> receivedQuotes;
  final ValueChanged<String>? onOpenQuote;
  final VoidCallback? onConfirmClosure;

  static const _technicians = [
    _TechnicianCardData(
      id: 'ana-garcia',
      initials: 'AG',
      name: 'Ana García',
      profession: 'Plomera',
      neighborhood: 'Usaquén',
      category: 'Plomería',
      rating: '4.8',
      reviews: 64,
      distance: '2.5 km',
      rate: '\$70.000',
    ),
    _TechnicianCardData(
      id: 'pedro-rojas',
      initials: 'PR',
      name: 'Pedro Rojas',
      profession: 'Pintor',
      neighborhood: 'Teusaquillo',
      category: 'Pintura',
      rating: '4.7',
      reviews: 112,
      distance: '3.1 km',
      rate: '\$55.000',
    ),
    _TechnicianCardData(
      id: 'laura-torres',
      initials: 'LT',
      name: 'Laura Torres',
      profession: 'Especialista en limpieza',
      neighborhood: 'Suba',
      category: 'Limpieza',
      rating: '5.0',
      reviews: 203,
      distance: '0.8 km',
      rate: '\$45.000',
    ),
    _TechnicianCardData(
      id: 'camilo-diaz',
      initials: 'CD',
      name: 'Camilo Díaz',
      profession: 'Electricista',
      neighborhood: 'Chapinero',
      category: 'Electricidad',
      rating: '4.9',
      reviews: 87,
      distance: '1.2 km',
      rate: '\$85.000',
    ),
  ];

  @override
  State<ClientDashboardPage> createState() => _ClientDashboardPageState();
}

class _ClientDashboardPageState extends State<ClientDashboardPage> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'Todos';
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_TechnicianCardData> get _visibleTechnicians {
    final query = _searchQuery.trim().toLowerCase();
    return ClientDashboardPage._technicians.where((technician) {
      final matchesCategory = _selectedCategory == 'Todos' ||
          technician.category == _selectedCategory;
      final searchableText =
          '${technician.name} ${technician.profession} ${technician.category} '
                  '${technician.neighborhood}'
              .toLowerCase();
      return matchesCategory &&
          (query.isEmpty || searchableText.contains(query));
    }).toList();
  }

  void _showClientProfileUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Inicia sesión como cliente para consultar y editar tu perfil.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      bottomNavigationBar: _ClientNavigationBar(
        onOpenHistory: widget.onOpenHistory,
        onPublishProblem: widget.onPublishProblem,
        onOpenProfile: widget.onOpenProfile ??
            widget.onOpenSettings ??
            _showClientProfileUnavailable,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ClientHeader(onLogout: widget.onLogout),
          const SizedBox(height: 22),
          Text(
            widget.firstName == null || widget.firstName!.trim().isEmpty
                ? 'Encuentra tu técnico'
                : 'Hola, ${widget.firstName}',
            key: const ValueKey('client-dashboard-greeting'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 26,
                  height: 1.2,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            'Profesionales verificados cerca de ti',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: FixiaColors.textSecondary,
                ),
          ),
          const SizedBox(height: 16),
          const _LocationSummary(),
          const SizedBox(height: 12),
          _SearchField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            onClear: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _selectedCategory = 'Todos';
              });
            },
          ),
          const SizedBox(height: 16),
          _CategoryFilters(
            selectedCategory: _selectedCategory,
            onSelected: (category) =>
                setState(() => _selectedCategory = category),
          ),
          const SizedBox(height: 22),
          DashboardSectionHeading(
            title: 'Recomendados para ti',
            subtitle: 'Técnicos con buenas calificaciones en tu zona.',
            trailing: TextButton(
              onPressed: () => setState(() {
                _searchController.clear();
                _searchQuery = '';
                _selectedCategory = 'Todos';
              }),
              child: const Text('Ver todos'),
            ),
          ),
          const SizedBox(height: 12),
          if (_visibleTechnicians.isEmpty)
            const _NoTechniciansFound()
          else
            for (var index = 0;
                index < _visibleTechnicians.length;
                index++) ...[
              _TechnicianCard(
                data: _visibleTechnicians[index],
                onRequest: () => widget.onRequestTechnician
                    ?.call(_visibleTechnicians[index].id),
                onOpenProfile: widget.onOpenTechnicianProfile == null
                    ? null
                    : () => widget.onOpenTechnicianProfile!
                        .call(_visibleTechnicians[index].id),
              ),
              if (index < _visibleTechnicians.length - 1)
                const SizedBox(height: 12),
            ],
          const SizedBox(height: 26),
          DashboardSectionHeading(
            title: 'Mis publicaciones activas',
            trailing: TextButton(
              onPressed: widget.onOpenHistory ?? _noop,
              child: const Text('Ver todas'),
            ),
          ),
          const SizedBox(height: 12),
          _RequestSummaryCard(onOpenApplicants: widget.onOpenApplicants),
          const SizedBox(height: 26),
          DashboardSectionHeading(
            title: 'Tus servicios en curso',
            trailing: TextButton(
              onPressed: widget.onOpenHistory ?? _noop,
              child: const Text('Historial'),
            ),
          ),
          const SizedBox(height: 12),
          _ActiveServiceCard(
            title: 'Mantenimiento de calentador',
            technician: 'Andrés Rojas · En curso',
            action: 'Abrir chat',
            icon: Icons.chat_bubble_outline_rounded,
            onPressed: widget.onOpenChat,
          ),
          const SizedBox(height: 10),
          _ActiveServiceCard(
            title: 'Pintura de habitación',
            technician: 'Sofía Méndez · Cotización pendiente',
            action: 'Revisar cotización',
            icon: Icons.request_quote_outlined,
            onPressed: widget.onReviewQuote,
          ),
          const SizedBox(height: 10),
          _ActiveServiceCard(
            title: 'Cambio de grifo',
            technician: 'Luis Herrera · Por confirmar cierre',
            action: 'Confirmar cierre',
            icon: Icons.task_alt_rounded,
            onPressed: widget.onConfirmClosure,
          ),
          if (widget.receivedQuotes.isNotEmpty) ...[
            const SizedBox(height: 16),
            const DashboardSectionHeading(title: 'Cotizaciones recibidas'),
            const SizedBox(height: 12),
            for (final quote in widget.receivedQuotes) ...[
              _ReceivedQuoteCard(
                quote: quote,
                onOpen: () => widget.onOpenQuote?.call(quote.requestId),
              ),
              const SizedBox(height: 10),
            ],
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _TechnicianCardData {
  const _TechnicianCardData({
    required this.id,
    required this.initials,
    required this.name,
    required this.profession,
    required this.neighborhood,
    required this.category,
    required this.rating,
    required this.reviews,
    required this.distance,
    required this.rate,
  });

  final String id;
  final String initials;
  final String name;
  final String profession;
  final String neighborhood;
  final String category;
  final String rating;
  final int reviews;
  final String distance;
  final String rate;
}

class _ClientHeader extends StatelessWidget {
  const _ClientHeader({this.onLogout});

  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          'assets/brand/fixia_logo.png',
          width: 90,
          height: 34,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          semanticLabel: 'Fixia',
        ),
        const Spacer(),
        if (onLogout != null)
          IconButton(
            key: const ValueKey('client-dashboard-logout'),
            tooltip: 'Cerrar sesión',
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
            style: IconButton.styleFrom(
              backgroundColor: FixiaColors.supportBackground,
              foregroundColor: FixiaColors.primary,
            ),
          ),
      ],
    );
  }
}

class _LocationSummary extends StatelessWidget {
  const _LocationSummary();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              color: FixiaColors.secondary,
              size: 19,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Usaquén, Bogotá',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: FixiaColors.primary,
                    ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 25, top: 2),
          child: Text(
            'Ubicación aproximada',
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('client-technician-search'),
      controller: controller,
      onChanged: onChanged,
      decoration: const InputDecoration(
        hintText: '¿Qué servicio necesitas?',
        prefixIcon: Icon(Icons.search_rounded),
        contentPadding: EdgeInsets.symmetric(vertical: 12),
      ).copyWith(
        suffixIcon: IconButton(
          key: const ValueKey('client-clear-filters'),
          tooltip: 'Limpiar búsqueda y filtros',
          onPressed: onClear,
          icon: const Icon(Icons.tune_rounded),
        ),
      ),
    );
  }
}

class _CategoryFilters extends StatelessWidget {
  const _CategoryFilters({
    required this.selectedCategory,
    required this.onSelected,
  });

  final String selectedCategory;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    const categories = [
      'Todos',
      'Plomería',
      'Pintura',
      'Limpieza',
      'Electricidad'
    ];
    return SizedBox(
      height: 38,
      child: ScrollConfiguration(
        behavior: const DragScrollBehavior(),
        child: ListView.separated(
          key: const ValueKey('client-technician-categories'),
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final selected = categories[index] == selectedCategory;
            return ChoiceChip(
              key: ValueKey('client-category-${categories[index]}'),
              label: Text(categories[index]),
              selected: selected,
              onSelected: (_) => onSelected(categories[index]),
              showCheckmark: false,
              selectedColor: FixiaColors.secondary,
              backgroundColor: FixiaColors.white,
              side: BorderSide(
                color:
                    selected ? FixiaColors.secondary : const Color(0xFFDCE5F0),
              ),
              labelStyle: TextStyle(
                color: selected ? FixiaColors.white : FixiaColors.textSecondary,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6),
            );
          },
        ),
      ),
    );
  }
}

class _NoTechniciansFound extends StatelessWidget {
  const _NoTechniciansFound();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('client-no-technicians-found'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FixiaColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE5F0)),
      ),
      child: Text(
        'No encontramos técnicos con esos filtros. Prueba otra búsqueda.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _TechnicianCard extends StatelessWidget {
  const _TechnicianCard({
    required this.data,
    required this.onRequest,
    this.onOpenProfile,
  });

  final _TechnicianCardData data;
  final VoidCallback onRequest;
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: ValueKey('client-technician-${data.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FixiaColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3EAF4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C01255D),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TechnicianAvatar(initials: data.initials),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${data.profession} · ${data.neighborhood}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _CategoryBadge(label: data.category),
            ],
          ),
          const SizedBox(height: 10),
          _RatingAndDistance(data: data),
          const SizedBox(height: 12),
          const Divider(height: 1, color: FixiaColors.supportBackground),
          if (onOpenProfile != null)
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                key: ValueKey('client-technician-profile-${data.id}'),
                onPressed: onOpenProfile,
                icon: const Icon(Icons.person_search_outlined),
                label: const Text('Ver perfil'),
              ),
            ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 5,
                  children: [
                    Text(
                      data.rate,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: FixiaColors.secondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '/ hora',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 96,
                height: 42,
                child: FilledButton(
                  key: ValueKey('client-request-${data.id}'),
                  onPressed: onRequest,
                  style: FilledButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    backgroundColor: FixiaColors.secondary,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Solicitar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TechnicianAvatar extends StatelessWidget {
  const _TechnicianAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 27,
          backgroundColor: FixiaColors.supportBackground,
          child: Text(
            initials,
            style: const TextStyle(
              color: FixiaColors.secondary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 19,
            height: 19,
            decoration: BoxDecoration(
              color: FixiaColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: FixiaColors.white, width: 2),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: FixiaColors.white,
              size: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _RatingAndDistance extends StatelessWidget {
  const _RatingAndDistance({required this.data});

  final _TechnicianCardData data;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 5,
      runSpacing: 3,
      children: [
        ...List.generate(
          5,
          (index) => Icon(
            index < 4 ? Icons.star_rounded : Icons.star_half_rounded,
            color: const Color(0xFFF4A11A),
            size: 16,
          ),
        ),
        Text('${data.rating} (${data.reviews})', style: style),
        const Icon(
          Icons.location_on_outlined,
          size: 15,
          color: FixiaColors.textSecondary,
        ),
        Text(data.distance, style: style),
        Text(
          'Ubicación aproximada',
          style: style?.copyWith(fontSize: 10),
        ),
      ],
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: FixiaColors.supportBackground,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: FixiaColors.secondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Resumen de una cotización recibida para mostrarla en el inicio.
class ReceivedQuoteSummary {
  const ReceivedQuoteSummary({
    required this.requestId,
    required this.title,
    required this.providerName,
  });

  final String requestId;
  final String title;
  final String providerName;
}

class _ReceivedQuoteCard extends StatelessWidget {
  const _ReceivedQuoteCard({required this.quote, required this.onOpen});

  final ReceivedQuoteSummary quote;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Row(
        children: [
          const Icon(
            Icons.request_quote_outlined,
            color: FixiaColors.secondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quote.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Cotización de ${quote.providerName}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(
            key: ValueKey('client-quote-${quote.requestId}'),
            onPressed: onOpen,
            child: const Text('Ver cotización'),
          ),
        ],
      ),
    );
  }
}

class _ActiveServiceCard extends StatelessWidget {
  const _ActiveServiceCard({
    required this.title,
    required this.technician,
    required this.action,
    required this.icon,
    required this.onPressed,
  });

  final String title;
  final String technician;
  final String action;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Row(
        children: [
          const Icon(
            Icons.handyman_outlined,
            color: FixiaColors.secondary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 3),
                Text(technician, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                const ApproximateLocationLabel(),
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: action,
            onPressed: onPressed ?? _noop,
            icon: Icon(icon, color: FixiaColors.secondary),
          ),
        ],
      ),
    );
  }
}

class _RequestSummaryCard extends StatelessWidget {
  const _RequestSummaryCard({this.onOpenApplicants});

  final VoidCallback? onOpenApplicants;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reparación de fuga en cocina',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _CategoryBadge(label: 'Plomería'),
              Text('Publicado hoy'),
              ApproximateLocationLabel(),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Icon(
                Icons.people_alt_outlined,
                size: 18,
                color: FixiaColors.secondary,
              ),
              SizedBox(width: 6),
              Text(
                '3 postulantes',
                style: TextStyle(
                  color: FixiaColors.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (onOpenApplicants != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('client-view-applicants'),
                onPressed: onOpenApplicants,
                icon: const Icon(Icons.people_alt_outlined),
                label: const Text('Ver postulantes'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClientNavigationBar extends StatelessWidget {
  const _ClientNavigationBar({
    required this.onOpenHistory,
    required this.onPublishProblem,
    required this.onOpenProfile,
  });

  final VoidCallback? onOpenHistory;
  final VoidCallback? onPublishProblem;
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return MobileNavigationBar(
      items: [
        const MobileNavigationItem(
          itemKey: ValueKey('client-nav-inicio'),
          icon: Icons.home_rounded,
          label: 'Inicio',
          selected: true,
          onPressed: _noop,
        ),
        MobileNavigationItem(
          itemKey: const ValueKey('client-nav-historial'),
          icon: Icons.history_rounded,
          label: 'Historial',
          onPressed: onOpenHistory ?? _noop,
        ),
        MobileNavigationItem(
          itemKey: const ValueKey('client-publish-problem'),
          icon: Icons.add_rounded,
          label: 'Publicar',
          isAction: true,
          onPressed: onPublishProblem ?? _noop,
        ),
        MobileNavigationItem(
          itemKey: const ValueKey('client-nav-perfil'),
          icon: Icons.person_outline_rounded,
          label: 'Perfil',
          onPressed: onOpenProfile ?? _noop,
        ),
      ],
    );
  }
}

void _noop() {}
