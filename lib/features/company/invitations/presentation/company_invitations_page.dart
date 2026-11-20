import 'package:flutter/material.dart';

import '../../../../core/layout/app_shell.dart';
import '../../../../core/theme/fixia_theme.dart';
import '../../../../core/widgets/fixia_ui.dart';
import '../../../quotations/presentation/quotation_card.dart'
    show formatDateTime;
import '../domain/company_invitation.dart';

/// Invitaciones de la empresa a técnicos independientes (GC-525): invitar por
/// correo, ver el estado y cancelar las pendientes. El técnico acepta o
/// rechaza desde su cuenta (GC-524).
class CompanyInvitationsPage extends StatefulWidget {
  const CompanyInvitationsPage({
    super.key,
    required this.gateway,
    required this.onSessionExpired,
  });

  final CompanyInvitationsGateway gateway;
  final VoidCallback onSessionExpired;

  @override
  State<CompanyInvitationsPage> createState() => _CompanyInvitationsPageState();
}

class _CompanyInvitationsPageState extends State<CompanyInvitationsPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  InvitationStatus? _filter;
  List<CompanyInvitation> _items = const [];
  bool _loading = true;
  String? _listError;
  bool _sending = false;
  String? _sendError;
  String? _sent;
  final Set<String> _cancelling = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  String _message(Object error) {
    if (error is InvitationFailure) {
      if (error.isSessionExpired) widget.onSessionExpired();
      return error.message;
    }
    return 'Ocurrió un error inesperado. Inténtalo de nuevo.';
  }

  Future<void> _load() async {
    final filter = _filter;
    setState(() {
      _loading = true;
      _listError = null;
    });
    try {
      final items = await widget.gateway.list(status: filter);
      if (!mounted || filter != _filter) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || filter != _filter) return;
      setState(() {
        _listError = _message(e);
        _loading = false;
      });
    }
  }

  Future<void> _invite() async {
    if (_sending || !_form.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _sendError = null;
      _sent = null;
    });
    try {
      final invitation = await widget.gateway.invite(_email.text.trim());
      if (!mounted) return;
      _email.clear();
      setState(() {
        _sending = false;
        _sent = 'Invitación enviada a ${invitation.technicianName}. '
            'Vence el ${formatDateTime(invitation.expiresAt)}.';
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sendError = _message(e);
      });
    }
  }

  Future<void> _cancel(CompanyInvitation invitation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('company-invitation-cancel-dialog'),
        title: const Text('Cancelar invitación'),
        content: Text('${invitation.technicianName} ya no podrá aceptarla.'),
        actions: [
          TextButton(
            style: _compact,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            key: const ValueKey('company-invitation-cancel-confirm'),
            style: _compact,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancelar invitación'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling.add(invitation.id));
    try {
      await widget.gateway.cancel(invitation.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        key: ValueKey('company-invitation-cancelled'),
        content: Text('Invitación cancelada.'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        key: const ValueKey('company-invitation-cancel-error'),
        content: Text(_message(e)),
      ));
    }
    if (!mounted) return;
    setState(() => _cancelling.remove(invitation.id));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      destination: ShellDestination.companyInvitations,
      userCaption: 'Empresa',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(
            title: 'Invitaciones',
            subtitle: 'Invita a técnicos independientes con el correo de su '
                'cuenta de Fixia. Tienen 7 días para aceptar; al hacerlo '
                'quedan asociados a tu empresa.',
          ),
          const SizedBox(height: 16),
          _inviteCard(),
          const SizedBox(height: 24),
          FilterPills<InvitationStatus?>(
            keyPrefix: 'company-invitations-filter',
            options: const [
              (null, 'Todas'),
              (InvitationStatus.pending, 'Pendientes'),
              (InvitationStatus.accepted, 'Aceptadas'),
              (InvitationStatus.rejected, 'Rechazadas'),
              (InvitationStatus.cancelled, 'Canceladas'),
              (InvitationStatus.expired, 'Vencidas'),
            ],
            selected: _filter,
            onSelected: (status) {
              setState(() => _filter = status);
              _load();
            },
          ),
          const SizedBox(height: 16),
          ..._list(),
        ],
      ),
    );
  }

  Widget _inviteCard() => Container(
        padding: const EdgeInsets.all(20),
        decoration: FixiaDecorations.card,
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Invitar a un técnico',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, constraints) {
                final field = TextFormField(
                  key: const ValueKey('company-invite-email'),
                  controller: _email,
                  enabled: !_sending,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  validator: validateTechnicianEmail,
                  onFieldSubmitted: (_) => _invite(),
                  decoration: const InputDecoration(
                    labelText: 'Correo del técnico',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                );
                final button = FilledButton.icon(
                  key: const ValueKey('company-invite-submit'),
                  style: _compact,
                  onPressed: _sending ? null : _invite,
                  icon: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Enviar invitación'),
                );
                if (constraints.maxWidth < 520) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [field, const SizedBox(height: 12), button],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: field),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: button,
                    ),
                  ],
                );
              }),
              if (_sendError != null) ...[
                const SizedBox(height: 12),
                NoticeBanner(
                  key: const ValueKey('company-invite-error'),
                  message: _sendError!,
                ),
              ],
              if (_sent != null) ...[
                const SizedBox(height: 12),
                NoticeBanner(
                  key: const ValueKey('company-invite-sent'),
                  message: _sent!,
                  tone: PillTone.success,
                  icon: Icons.check_circle_outline_rounded,
                ),
              ],
            ],
          ),
        ),
      );

  List<Widget> _list() {
    if (_loading) return const [SectionLoading()];
    if (_listError != null) {
      return [
        NoticeBanner(
          key: const ValueKey('company-invitations-error'),
          message: _listError!,
        ),
        const SizedBox(height: 8),
        Center(
          child: OutlinedButton(
            key: const ValueKey('company-invitations-retry'),
            style: _compact,
            onPressed: _load,
            child: const Text('Reintentar'),
          ),
        ),
      ];
    }
    if (_items.isEmpty) {
      return [
        EmptyState(
          message: _filter == null
              ? 'Todavía no has invitado a ningún técnico.'
              : 'No hay invitaciones ${_filter!.label.toLowerCase()}s.',
        ),
      ];
    }
    return [for (final invitation in _items) _row(invitation)];
  }

  Widget _row(CompanyInvitation invitation) {
    final cancelling = _cancelling.contains(invitation.id);
    final when = invitation.status == InvitationStatus.pending
        ? 'Enviada el ${formatDateTime(invitation.createdAt)} · '
            'vence el ${formatDateTime(invitation.expiresAt)}'
        : invitation.respondedAt != null
            ? 'Enviada el ${formatDateTime(invitation.createdAt)} · '
                '${invitation.status.label.toLowerCase()} el '
                '${formatDateTime(invitation.respondedAt!)}'
            : 'Enviada el ${formatDateTime(invitation.createdAt)}';
    return Padding(
      key: ValueKey('company-invitation-${invitation.id}'),
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: FixiaDecorations.card,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(invitation.technicianName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      StatusPill(
                        label: invitation.status.label,
                        tone: switch (invitation.status) {
                          InvitationStatus.pending => PillTone.info,
                          InvitationStatus.accepted => PillTone.success,
                          InvitationStatus.rejected ||
                          InvitationStatus.expired =>
                            PillTone.warning,
                          InvitationStatus.cancelled => PillTone.neutral,
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(when,
                      style: const TextStyle(
                          color: FixiaColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            if (invitation.cancellable) ...[
              const SizedBox(width: 12),
              OutlinedButton(
                key: ValueKey('company-invitation-cancel-${invitation.id}'),
                style: _compact,
                onPressed: cancelling ? null : () => _cancel(invitation),
                child: const Text('Cancelar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// El tema hace los botones de ancho completo; aquí van a su tamaño.
final _compact = ButtonStyle(
  minimumSize: WidgetStateProperty.all(const Size(0, 44)),
);
