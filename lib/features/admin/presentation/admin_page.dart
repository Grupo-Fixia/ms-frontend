import 'package:flutter/material.dart';

import '../../../core/theme/fixia_theme.dart';
import '../../../core/widgets/fixia_ui.dart';
import '../../payments/domain/payments.dart';
import '../../quotations/presentation/quotation_card.dart'
    show formatCents, formatDateTime;
import '../domain/admin.dart';

/// Secciones del panel ADMIN (GC-536).
enum AdminSection {
  users('Usuarios', Icons.people_outline_rounded),
  payments('Pagos', Icons.payments_outlined),
  audit('Registro', Icons.fact_check_outlined);

  const AdminSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Panel web mínimo del ADMIN de Fixia (GC-536, contrato GC-534 §6):
/// usuarios, pagos con reembolso y registro de acciones. La autorización real
/// la hace cada servicio (`ROLE_ADMIN`); la ruta además tiene su guardia.
class AdminPage extends StatefulWidget {
  const AdminPage({
    super.key,
    required this.gateway,
    required this.adminName,
    required this.onLogout,
    required this.onSessionExpired,
    this.initialSection = AdminSection.users,
    this.newKey = newIdempotencyKey,
  });

  final AdminGateway gateway;
  final String adminName;
  final VoidCallback onLogout;
  final VoidCallback onSessionExpired;
  final AdminSection initialSection;

  /// Genera la `Idempotency-Key` de cada intento de reembolso.
  final String Function() newKey;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late AdminSection _section = widget.initialSection;

  /// Convierte un error en mensaje; si la sesión venció, sale al login.
  String _handle(Object error) {
    if (error is AdminFailure) {
      if (error.isSessionExpired) widget.onSessionExpired();
      return error.message;
    }
    return 'Ocurrió un error inesperado. Inténtalo de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (_section) {
      AdminSection.users =>
        _UsersSection(gateway: widget.gateway, onError: _handle),
      AdminSection.payments => _PaymentsSection(
          gateway: widget.gateway, onError: _handle, newKey: widget.newKey),
      AdminSection.audit =>
        _AuditSection(gateway: widget.gateway, onError: _handle),
    };
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      return Scaffold(
        key: const ValueKey('admin-panel'),
        backgroundColor: FixiaColors.neutralBackground,
        appBar: AppBar(
          backgroundColor: FixiaColors.primary,
          foregroundColor: FixiaColors.white,
          title: const Text('Fixia · Administración'),
          actions: [
            if (wide)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(widget.adminName),
                ),
              ),
            IconButton(
              key: const ValueKey('admin-logout'),
              tooltip: 'Cerrar sesión',
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: Row(
          children: [
            if (wide)
              NavigationRail(
                selectedIndex: _section.index,
                labelType: NavigationRailLabelType.all,
                onDestinationSelected: (i) =>
                    setState(() => _section = AdminSection.values[i]),
                destinations: [
                  for (final s in AdminSection.values)
                    NavigationRailDestination(
                      icon: Icon(s.icon, key: ValueKey('admin-nav-${s.name}')),
                      label: Text(s.label),
                    ),
                ],
              ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: body,
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _section.index,
                onDestinationSelected: (i) =>
                    setState(() => _section = AdminSection.values[i]),
                destinations: [
                  for (final s in AdminSection.values)
                    NavigationDestination(
                      icon: Icon(s.icon, key: ValueKey('admin-nav-${s.name}')),
                      label: s.label,
                    ),
                ],
              ),
      );
    });
  }
}

typedef AdminErrorHandler = String Function(Object error);

// -----------------------------------------------------------------------------
// Lista paginada por cursor, compartida por las tres secciones.

class _PagedList<T> extends StatefulWidget {
  const _PagedList({
    super.key,
    required this.load,
    required this.itemBuilder,
    required this.onError,
    required this.emptyMessage,
    this.header,
  });

  final Future<AdminList<T>> Function(String? cursor) load;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final AdminErrorHandler onError;
  final String emptyMessage;
  final Widget? header;

  @override
  State<_PagedList<T>> createState() => _PagedListState<T>();
}

class _PagedListState<T> extends State<_PagedList<T>> {
  final _items = <T>[];
  String? _next;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final cursor = _items.isEmpty ? null : _next;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.load(cursor);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _next = page.nextCursor;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = widget.onError(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        if (widget.header != null) widget.header!,
        for (final item in _items) widget.itemBuilder(context, item),
        if (_loading) const SectionLoading(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                NoticeBanner(
                  key: const ValueKey('admin-list-error'),
                  message: _error!,
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const ValueKey('admin-list-retry'),
                  onPressed: _fetch,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        if (!_loading && _error == null && _items.isEmpty)
          EmptyState(message: widget.emptyMessage),
        if (!_loading && _error == null && _next != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: OutlinedButton(
                key: const ValueKey('admin-load-more'),
                onPressed: _fetch,
                child: const Text('Cargar más'),
              ),
            ),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.title,
    required this.subtitle,
    this.pills = const [],
    this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final List<Widget> pills;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: FixiaColors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: const TextStyle(
                                color: FixiaColors.textSecondary,
                                fontSize: 13)),
                        if (pills.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(spacing: 6, runSpacing: 6, children: pills),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}

/// El tema hace los botones de ancho completo; en filas y diálogos van a su
/// tamaño.
final _compact = ButtonStyle(
  minimumSize: WidgetStateProperty.all(const Size(0, 44)),
);

String _date(DateTime? date) => date == null ? '—' : formatDateTime(date);

String _shortId(String? id) =>
    id == null ? '—' : (id.length > 8 ? '${id.substring(0, 8)}…' : id);

// -----------------------------------------------------------------------------
// Usuarios

class _UsersSection extends StatefulWidget {
  const _UsersSection({required this.gateway, required this.onError});

  final AdminGateway gateway;
  final AdminErrorHandler onError;

  @override
  State<_UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends State<_UsersSection> {
  AdminUserRole? _role;
  AdminUserStatus? _status;
  String? _query;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _applySearch() =>
      setState(() => _query = normalizeUserQuery(_search.text));

  Future<void> _openDetail(AdminUser user) => showDialog<void>(
        context: context,
        builder: (_) => _UserDetailDialog(
            gateway: widget.gateway, userId: user.id, onError: widget.onError),
      );

  @override
  Widget build(BuildContext context) {
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeader(
          title: 'Usuarios',
          subtitle: 'Cuentas registradas en Fixia. El documento se muestra '
              'enmascarado.',
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('admin-users-search'),
          controller: _search,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _applySearch(),
          decoration: InputDecoration(
            hintText: 'Buscar por correo, nombre o apellido (mínimo 2 letras)',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(
              key: const ValueKey('admin-users-search-submit'),
              tooltip: 'Buscar',
              onPressed: _applySearch,
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilterPills<AdminUserRole?>(
          keyPrefix: 'admin-role',
          options: [
            (null, 'Todos los roles'),
            for (final r in AdminUserRole.values) (r, r.label),
          ],
          selected: _role,
          onSelected: (r) => setState(() => _role = r),
        ),
        const SizedBox(height: 8),
        FilterPills<AdminUserStatus?>(
          keyPrefix: 'admin-status',
          options: [
            (null, 'Todos los estados'),
            for (final s in AdminUserStatus.values) (s, s.label),
          ],
          selected: _status,
          onSelected: (s) => setState(() => _status = s),
        ),
        const SizedBox(height: 16),
      ],
    );
    return _PagedList<AdminUser>(
      key: ValueKey('users-$_role-$_status-$_query'),
      header: header,
      onError: widget.onError,
      emptyMessage: 'No hay usuarios con esos filtros.',
      load: (cursor) => widget.gateway
          .users(role: _role, status: _status, query: _query, cursor: cursor),
      itemBuilder: (context, user) => _Row(
        key: ValueKey('admin-user-${user.id}'),
        title: user.fullName,
        subtitle: '${user.email} · desde ${_date(user.createdAt)}',
        pills: [
          StatusPill(label: user.role?.label ?? 'Rol desconocido'),
          StatusPill(
            label: user.status?.label ?? 'Estado desconocido',
            tone: user.status == AdminUserStatus.active
                ? PillTone.success
                : PillTone.warning,
          ),
        ],
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _openDetail(user),
      ),
    );
  }
}

class _UserDetailDialog extends StatelessWidget {
  const _UserDetailDialog(
      {required this.gateway, required this.userId, required this.onError});

  final AdminGateway gateway;
  final String userId;
  final AdminErrorHandler onError;

  @override
  Widget build(BuildContext context) => AlertDialog(
        key: const ValueKey('admin-user-detail'),
        title: const Text('Detalle del usuario'),
        content: SizedBox(
          width: 460,
          child: FutureBuilder<AdminUserDetail>(
            future: gateway.user(userId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return NoticeBanner(message: onError(snapshot.error!));
              }
              final user = snapshot.data;
              if (user == null) return const SectionLoading();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InfoRow(label: 'Nombre', value: user.fullName),
                  InfoRow(label: 'Correo', value: user.email),
                  InfoRow(label: 'Rol', value: user.role?.label ?? '—'),
                  InfoRow(label: 'Estado', value: user.status?.label ?? '—'),
                  InfoRow(label: 'Teléfono', value: user.phone ?? '—'),
                  InfoRow(
                    label: 'Documento',
                    value: [user.documentType, user.documentNumberMasked]
                        .whereType<String>()
                        .join(' '),
                  ),
                  if (user.verificationStatus != null)
                    InfoRow(
                        label: 'Verificación', value: user.verificationStatus!),
                  if (user.companyName != null)
                    InfoRow(label: 'Empresa', value: user.companyName!),
                  InfoRow(label: 'Registro', value: _date(user.createdAt)),
                  InfoRow(label: 'ID', value: user.id),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            style: _compact,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      );
}

// -----------------------------------------------------------------------------
// Pagos y reembolso

class _PaymentsSection extends StatefulWidget {
  const _PaymentsSection(
      {required this.gateway, required this.onError, required this.newKey});

  final AdminGateway gateway;
  final AdminErrorHandler onError;
  final String Function() newKey;

  @override
  State<_PaymentsSection> createState() => _PaymentsSectionState();
}

class _PaymentsSectionState extends State<_PaymentsSection> {
  HoldStatus? _hold;
  String? _userId;
  int _reloads = 0;
  final _user = TextEditingController();

  @override
  void dispose() {
    _user.dispose();
    super.dispose();
  }

  void _applyUser() {
    final value = _user.text.trim();
    setState(() => _userId = value.isEmpty ? null : value);
  }

  Future<void> _refund(AdminPayment payment) async {
    final refunded = await showDialog<ServicePayment>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RefundDialog(
        payment: payment,
        idempotencyKey: widget.newKey(),
        onError: widget.onError,
        refund: widget.gateway.refund,
      ),
    );
    if (refunded == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const ValueKey('admin-refund-done'),
        content: Text('Reembolso aplicado: ${refunded.holdStatus.label}.'),
      ),
    );
    setState(() => _reloads++);
  }

  @override
  Widget build(BuildContext context) {
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeader(
          title: 'Pagos',
          subtitle: 'Pagos con billetera simulada. Solo se puede reembolsar lo '
              'que el servicio de pagos marca como reembolsable.',
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('admin-payments-user'),
          controller: _user,
          onSubmitted: (_) => _applyUser(),
          decoration: InputDecoration(
            hintText: 'ID de usuario (cliente o prestador)',
            prefixIcon: const Icon(Icons.person_search_outlined),
            suffixIcon: IconButton(
              key: const ValueKey('admin-payments-user-submit'),
              tooltip: 'Filtrar',
              onPressed: _applyUser,
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilterPills<HoldStatus?>(
          keyPrefix: 'admin-hold',
          options: const [
            (null, 'Todos'),
            (HoldStatus.held, 'Retenidos'),
            (HoldStatus.captured, 'Cobrados'),
            (HoldStatus.failed, 'Retención fallida'),
            (HoldStatus.released, 'Liberados'),
            (HoldStatus.reversed, 'Revertidos'),
          ],
          selected: _hold,
          onSelected: (h) => setState(() => _hold = h),
        ),
        const SizedBox(height: 16),
      ],
    );
    return _PagedList<AdminPayment>(
      key: ValueKey('payments-$_hold-$_userId-$_reloads'),
      header: header,
      onError: widget.onError,
      emptyMessage: 'No hay pagos con esos filtros.',
      load: (cursor) => widget.gateway
          .payments(holdStatus: _hold, userId: _userId, cursor: cursor),
      itemBuilder: (context, item) {
        final p = item.payment;
        return _Row(
          key: ValueKey('admin-payment-${p.id}'),
          title: formatCents(p.amountCents, p.currency),
          subtitle: 'Solicitud ${_shortId(p.serviceRequestId)} · '
              'cliente ${_shortId(item.clientId)} · '
              'prestador ${_shortId(item.providerId)} · '
              '${_date(item.createdAt)}',
          pills: [
            StatusPill(label: p.label, tone: PillTone.neutral),
            if (p.isWalletPayment)
              StatusPill(
                label: p.holdStatus.label,
                tone: switch (p.holdStatus) {
                  HoldStatus.held => PillTone.info,
                  HoldStatus.captured => PillTone.success,
                  HoldStatus.failed => PillTone.warning,
                  _ => PillTone.neutral,
                },
              ),
          ],
          trailing: item.refundable
              ? FilledButton.tonal(
                  key: ValueKey('admin-refund-${p.id}'),
                  style: _compact,
                  onPressed: () => _refund(item),
                  child: const Text('Reembolsar'),
                )
              : null,
        );
      },
    );
  }
}

/// Diálogo de reembolso: motivo obligatorio y confirmación. La clave de
/// idempotencia es la misma en todos los reintentos de este diálogo, así un
/// reintento tras un corte no devuelve el dinero dos veces (contrato §6).
class RefundDialog extends StatefulWidget {
  const RefundDialog({
    super.key,
    required this.payment,
    required this.idempotencyKey,
    required this.refund,
    required this.onError,
  });

  final AdminPayment payment;
  final String idempotencyKey;
  final Future<ServicePayment> Function(String paymentId,
      {required String reason, required String idempotencyKey}) refund;
  final AdminErrorHandler onError;

  @override
  State<RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<RefundDialog> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final result = await widget.refund(
        widget.payment.id,
        reason: _reason.text.trim(),
        idempotencyKey: widget.idempotencyKey,
      );
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = widget.onError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payment.payment;
    final breakdown = p.breakdown;
    return AlertDialog(
      key: const ValueKey('admin-refund-dialog'),
      title: const Text('Reembolsar pago'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.payment.refundKind?.description ?? '',
                key: const ValueKey('admin-refund-kind'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              InfoRow(
                  label: 'Total',
                  value: formatCents(p.amountCents, p.currency)),
              if (breakdown != null) ...[
                InfoRow(
                    label: 'Precio',
                    value: formatCents(breakdown.priceCents, p.currency)),
                InfoRow(
                    label: 'Comisión Fixia',
                    value: formatCents(breakdown.commissionCents, p.currency)),
              ],
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('admin-refund-reason'),
                controller: _reason,
                enabled: !_sending,
                maxLength: 500,
                maxLines: 3,
                validator: validateRefundReason,
                decoration: const InputDecoration(
                  labelText: 'Motivo del reembolso',
                  hintText: 'Queda en el registro de acciones del ADMIN.',
                ),
              ),
              if (_error != null)
                NoticeBanner(
                  key: const ValueKey('admin-refund-error'),
                  message: _error!,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          style: _compact,
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('admin-refund-confirm'),
          style: _compact,
          onPressed: _sending ? null : _submit,
          child: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Confirmar reembolso'),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Registro de acciones

class _AuditSection extends StatefulWidget {
  const _AuditSection({required this.gateway, required this.onError});

  final AdminGateway gateway;
  final AdminErrorHandler onError;

  @override
  State<_AuditSection> createState() => _AuditSectionState();
}

class _AuditSectionState extends State<_AuditSection> {
  AuditSource _source = AuditSource.payments;

  @override
  Widget build(BuildContext context) {
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeader(
          title: 'Registro de acciones',
          subtitle: 'Todo lo que hace un administrador queda registrado en el '
              'servicio dueño del dato. No se puede editar ni borrar.',
        ),
        const SizedBox(height: 12),
        FilterPills<AuditSource>(
          keyPrefix: 'admin-audit',
          options: [for (final s in AuditSource.values) (s, s.label)],
          selected: _source,
          onSelected: (s) => setState(() => _source = s),
        ),
        const SizedBox(height: 16),
      ],
    );
    return _PagedList<AdminAuditEvent>(
      key: ValueKey('audit-$_source'),
      header: header,
      onError: widget.onError,
      emptyMessage: 'Todavía no hay acciones registradas.',
      load: (cursor) => widget.gateway.auditEvents(_source, cursor: cursor),
      itemBuilder: (context, e) => _Row(
        key: ValueKey('admin-audit-${e.id}'),
        title: e.actionLabel,
        subtitle: [
          _date(e.occurredAt),
          'admin ${_shortId(e.adminId)}',
          if (e.targetId != null)
            '${e.targetType ?? 'objetivo'} ${_shortId(e.targetId)}',
          if (e.details != null && e.details != '{}') e.details!,
        ].join(' · '),
        pills: [
          StatusPill(
            label: e.outcomeLabel,
            tone: e.outcome == 'OK' ? PillTone.success : PillTone.warning,
          ),
        ],
      ),
    );
  }
}
