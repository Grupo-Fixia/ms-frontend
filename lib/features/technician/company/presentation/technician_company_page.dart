import 'package:flutter/material.dart';

import '../../../../core/layout/app_shell.dart';
import '../../../../core/theme/fixia_theme.dart';
import '../../../../core/widgets/fixia_ui.dart';
import '../../../quotations/presentation/quotation_card.dart'
    show formatDateTime;
import '../domain/technician_company.dart';

/// «Mi empresa» del técnico (GC-525, lado del técnico, sobre GC-524):
/// - Independiente: ve las invitaciones que le llegaron y las acepta o
///   rechaza.
/// - Con empresa: ve a cuál pertenece y puede desvincularse si no tiene
///   trabajos pendientes ni dinero retenido.
class TechnicianCompanyPage extends StatefulWidget {
  const TechnicianCompanyPage({
    super.key,
    required this.gateway,
    required this.onSessionExpired,
  });

  final TechnicianCompanyGateway gateway;
  final VoidCallback onSessionExpired;

  @override
  State<TechnicianCompanyPage> createState() => _TechnicianCompanyPageState();
}

class _TechnicianCompanyPageState extends State<TechnicianCompanyPage> {
  bool _loading = true;
  String? _error;
  Membership? _membership;
  List<ReceivedInvitation> _invitations = const [];

  /// Invitación o acción en curso (bloquea botones).
  String? _busy;
  TechnicianCompanyFailure? _leaveFailure;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _message(Object error) {
    if (error is TechnicianCompanyFailure) {
      if (error.isSessionExpired) widget.onSessionExpired();
      return error.message;
    }
    return 'Ocurrió un error inesperado. Inténtalo de nuevo.';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final membership = await widget.gateway.membership();
      final invitations = membership == null
          ? await widget.gateway.invitations()
          : const <ReceivedInvitation>[];
      if (!mounted) return;
      setState(() {
        _membership = membership;
        _invitations = invitations;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _message(e);
        _loading = false;
      });
    }
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirm,
    required String key,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: ValueKey(key),
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              style: _compact,
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Volver'),
            ),
            FilledButton(
              key: ValueKey('$key-confirm'),
              style: _compact,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirm),
            ),
          ],
        ),
      ) ==
      true;

  void _snack(String text, String key) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(key: ValueKey(key), content: Text(text)));
  }

  Future<void> _accept(ReceivedInvitation invitation) async {
    final others = _invitations.length - 1;
    final ok = await _confirm(
      key: 'technician-invitation-accept-dialog',
      title: 'Unirte a ${invitation.companyName}',
      body: 'Desde ahora te postularás a los servicios a través de la empresa.'
          '${others > 0 ? ' Tus otras $others invitaciones se cancelarán.' : ''}',
      confirm: 'Unirme',
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = invitation.id;
      _actionError = null;
    });
    try {
      final membership = await widget.gateway.accept(invitation.id);
      if (!mounted) return;
      _snack('Ahora perteneces a ${membership.companyName}.',
          'technician-invitation-accepted');
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionError = _message(e));
    }
    if (!mounted) return;
    setState(() => _busy = null);
    await _load();
  }

  Future<void> _reject(ReceivedInvitation invitation) async {
    final ok = await _confirm(
      key: 'technician-invitation-reject-dialog',
      title: 'Rechazar invitación',
      body: '${invitation.companyName} verá que rechazaste su invitación.',
      confirm: 'Rechazar',
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = invitation.id;
      _actionError = null;
    });
    try {
      await widget.gateway.reject(invitation.id);
      if (!mounted) return;
      _snack('Invitación rechazada.', 'technician-invitation-rejected');
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionError = _message(e));
    }
    if (!mounted) return;
    setState(() => _busy = null);
    await _load();
  }

  Future<void> _leave() async {
    final company = _membership!.companyName;
    final ok = await _confirm(
      key: 'technician-leave-dialog',
      title: 'Desvincularte de $company',
      body: 'Volverás a ser independiente y te postularás por tu cuenta. '
          'Solo es posible si no tienes trabajos pendientes ni dinero '
          'retenido con la empresa.',
      confirm: 'Desvincularme',
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = 'leave';
      _leaveFailure = null;
      _actionError = null;
    });
    try {
      await widget.gateway.leave();
      if (!mounted) return;
      _snack('Te desvinculaste de $company.', 'technician-left-company');
    } on TechnicianCompanyFailure catch (f) {
      if (!mounted) return;
      if (f.isSessionExpired) widget.onSessionExpired();
      setState(() {
        if (f.statusCode == 409) {
          _leaveFailure = f;
        } else {
          _actionError = f.message;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionError = _message(e));
    }
    if (!mounted) return;
    setState(() => _busy = null);
    if (_leaveFailure == null && _actionError == null) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      destination: ShellDestination.technicianCompany,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(
            title: 'Mi empresa',
            subtitle: 'Las empresas prestadoras pueden invitarte a trabajar '
                'con ellas. Si te unes, te postulas a los servicios a través '
                'de la empresa.',
          ),
          const SizedBox(height: 16),
          if (_actionError != null) ...[
            NoticeBanner(
              key: const ValueKey('technician-company-action-error'),
              message: _actionError!,
            ),
            const SizedBox(height: 12),
          ],
          ..._body(),
        ],
      ),
    );
  }

  List<Widget> _body() {
    if (_loading) return const [SectionLoading()];
    if (_error != null) {
      return [
        NoticeBanner(
          key: const ValueKey('technician-company-error'),
          message: _error!,
        ),
        const SizedBox(height: 8),
        Center(
          child: OutlinedButton(
            key: const ValueKey('technician-company-retry'),
            style: _compact,
            onPressed: _load,
            child: const Text('Reintentar'),
          ),
        ),
      ];
    }
    final membership = _membership;
    if (membership != null) return [_memberCard(membership)];
    return [
      Container(
        key: const ValueKey('technician-independent'),
        padding: const EdgeInsets.all(18),
        decoration: FixiaDecorations.card,
        child: const Row(
          children: [
            Icon(Icons.person_outline_rounded, color: FixiaColors.secondary),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Trabajas como independiente: te postulas por tu cuenta.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const Text('Invitaciones',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      if (_invitations.isEmpty)
        const EmptyState(
          message: 'No tienes invitaciones pendientes. Cuando una empresa te '
              'invite, aparecerá aquí.',
        )
      else
        for (final invitation in _invitations) _invitationRow(invitation),
    ];
  }

  Widget _memberCard(Membership membership) {
    final failure = _leaveFailure;
    return Container(
      key: const ValueKey('technician-membership'),
      padding: const EdgeInsets.all(20),
      decoration: FixiaDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.business_outlined,
                  color: FixiaColors.secondary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(membership.companyName,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    if (membership.joinedAt != null)
                      Text(
                        'Te uniste el ${formatDateTime(membership.joinedAt!)}',
                        style: const TextStyle(
                            color: FixiaColors.textSecondary, fontSize: 13),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Te postulas a los servicios a través de la empresa; ella te '
            'propone en las solicitudes.',
            style: TextStyle(color: FixiaColors.textSecondary),
          ),
          if (failure != null) ...[
            const SizedBox(height: 14),
            Container(
              key: const ValueKey('technician-leave-blocked'),
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4D6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(failure.message,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  for (final b in failure.blockers)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('• ${b.message}'),
                    ),
                  if (failure.serviceRequestIds.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Servicios relacionados: '
                      '${failure.serviceRequestIds.length}.',
                      style: const TextStyle(
                          color: FixiaColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('technician-leave-company'),
              style: _compact,
              onPressed: _busy == null ? _leave : null,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Desvincularme de la empresa'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _invitationRow(ReceivedInvitation invitation) {
    final busy = _busy != null;
    return Padding(
      key: ValueKey('technician-invitation-${invitation.id}'),
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: FixiaDecorations.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(invitation.companyName,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              'Te invitó el ${formatDateTime(invitation.createdAt)} · '
              'vence el ${formatDateTime(invitation.expiresAt)}',
              style: const TextStyle(
                  color: FixiaColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton(
                  key:
                      ValueKey('technician-invitation-accept-${invitation.id}'),
                  style: _compact,
                  onPressed: busy ? null : () => _accept(invitation),
                  child: const Text('Aceptar'),
                ),
                OutlinedButton(
                  key:
                      ValueKey('technician-invitation-reject-${invitation.id}'),
                  style: _compact,
                  onPressed: busy ? null : () => _reject(invitation),
                  child: const Text('Rechazar'),
                ),
              ],
            ),
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
