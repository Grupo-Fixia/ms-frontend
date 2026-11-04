import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/layout/app_shell.dart';
import '../../../core/theme/fixia_theme.dart';
import '../../../core/widgets/fixia_ui.dart';
import '../../quotations/presentation/quotation_card.dart';
import '../domain/payments.dart';

/// Operaciones de la billetera que usa la pantalla. En la app las da
/// `HttpPaymentsRepository`; en pruebas, un doble.
abstract interface class WalletGateway {
  Future<Wallet> wallet();
  Future<WalletEntriesPage> entries({String? cursor});
  Future<Wallet> topUp(int amountCents);
  Future<Wallet> withdraw(int amountCents);
}

/// Billetera simulada (GC-489): saldo disponible y retenido, movimientos y,
/// según el rol, recargar (cliente) o retirar (técnico o empresa). Todo es
/// dinero virtual: no hay cobros ni transferencias reales.
class WalletPage extends StatefulWidget {
  const WalletPage({
    super.key,
    required this.gateway,
    required this.role,
    this.onSessionExpired,
  });

  final WalletGateway gateway;
  final ShellRole role;
  final VoidCallback? onSessionExpired;

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  Wallet? _wallet;
  final _entries = <WalletEntry>[];
  String? _cursor;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  bool get _isClient => widget.role == ShellRole.client;

  ShellDestination get _destination => switch (widget.role) {
        ShellRole.client => ShellDestination.clientWallet,
        ShellRole.technician => ShellDestination.technicianWallet,
        ShellRole.company => ShellDestination.companyWallet,
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _handle(Object error) {
    if (error is PaymentsFailure && error.isSessionExpired) {
      widget.onSessionExpired?.call();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        widget.gateway.wallet(),
        widget.gateway.entries(),
      ]);
      final page = results[1] as WalletEntriesPage;
      if (!mounted) return;
      setState(() {
        _wallet = results[0] as Wallet;
        _entries
          ..clear()
          ..addAll(page.items);
        _cursor = page.nextCursor;
        _loading = false;
      });
    } catch (error) {
      _handle(error);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _more() async {
    if (_loadingMore || _cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.gateway.entries(cursor: _cursor);
      if (!mounted) return;
      setState(() {
        _entries.addAll(page.items);
        _cursor = page.nextCursor;
      });
    } catch (error) {
      _handle(error);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _operate() async {
    final wallet = _wallet;
    if (wallet == null) return;
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => WalletAmountDialog(
        topUp: _isClient,
        availableCents: wallet.availableCents,
        currency: wallet.currency,
        submit: (cents) => _isClient
            ? widget.gateway.topUp(cents)
            : widget.gateway.withdraw(cents),
        onError: _handle,
      ),
    );
    if (done == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        key: const ValueKey('wallet-operation-done'),
        content: Text(_isClient ? 'Recarga registrada.' : 'Retiro registrado.'),
      ));
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    final wallet = _wallet;
    if (_loading) {
      body = const SectionLoading();
    } else if (_error != null || wallet == null) {
      body = EmptyState(
        icon: Icons.cloud_off_outlined,
        message: _error ?? HttpPaymentsMessages.unavailable,
        action: OutlinedButton(
          key: const ValueKey('wallet-retry'),
          onPressed: _load,
          child: const Text('Reintentar'),
        ),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Balances(wallet: wallet, isClient: _isClient),
          const SizedBox(height: 28),
          const SectionTitle(title: 'Movimientos'),
          if (_entries.isEmpty)
            EmptyState(
              icon: Icons.receipt_long_outlined,
              message: _isClient
                  ? 'Todavía no tienes movimientos. Recarga tu billetera para pagar servicios.'
                  : 'Todavía no tienes movimientos. Aquí verás lo que recibas por tus servicios.',
            )
          else
            _Movements(entries: _entries, currency: wallet.currency),
          if (_cursor != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: _loadingMore
                    ? const CircularProgressIndicator()
                    : TextButton(
                        key: const ValueKey('wallet-more'),
                        onPressed: _more,
                        child: const Text('Ver más movimientos'),
                      ),
              ),
            ),
        ],
      );
    }
    return AppShell(
      destination: _destination,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Billetera',
            subtitle: _isClient
                ? 'Con tu saldo se retiene el pago al contratar y se le paga al técnico cuando confirmas el cierre.'
                : 'Aquí recibes el pago de cada servicio cuando el cliente confirma el cierre.',
            actions: [
              if (wallet != null)
                FilledButton.icon(
                  key: const ValueKey('wallet-operate'),
                  onPressed: _operate,
                  icon: Icon(
                    _isClient
                        ? Icons.add_card_rounded
                        : Icons.payments_outlined,
                    size: 18,
                  ),
                  label: Text(_isClient ? 'Recargar saldo' : 'Retirar saldo'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const NoticeBanner(
            key: ValueKey('wallet-simulated'),
            message:
                'Billetera simulada: el dinero es virtual y no se hacen cobros ni transferencias reales.',
            tone: PillTone.info,
            icon: Icons.info_outline_rounded,
          ),
          const SizedBox(height: 20),
          body,
        ],
      ),
    );
  }
}

/// Textos compartidos de pagos.
abstract final class HttpPaymentsMessages {
  static const unavailable =
      'Los pagos no están disponibles en este momento. Inténtalo más tarde.';
}

class _Balances extends StatelessWidget {
  const _Balances({required this.wallet, required this.isClient});

  final Wallet wallet;
  final bool isClient;

  @override
  Widget build(BuildContext context) => ResponsiveGrid(
        minItemWidth: 260,
        children: [
          Container(
            key: const ValueKey('wallet-available'),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: FixiaColors.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saldo disponible',
                  style: TextStyle(color: Color(0xFFB7CCE8), fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  formatCents(wallet.availableCents, wallet.currency),
                  style: const TextStyle(
                    color: FixiaColors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isClient
                      ? 'Para pagar nuevos servicios.'
                      : 'Puedes retirarlo cuando quieras.',
                  style:
                      const TextStyle(color: Color(0xFFDCEBFF), fontSize: 12),
                ),
              ],
            ),
          ),
          FixiaPanel(
            key: const ValueKey('wallet-held'),
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Retenido',
                  style:
                      TextStyle(color: FixiaColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  formatCents(wallet.heldCents, wallet.currency),
                  style: const TextStyle(
                    color: FixiaColors.primary,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isClient
                      ? 'Reservado para servicios contratados hasta que confirmes el cierre.'
                      : 'Dinero en espera.',
                  style: const TextStyle(
                    color: FixiaColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _Movements extends StatelessWidget {
  const _Movements({required this.entries, required this.currency});

  final List<WalletEntry> entries;
  final String currency;

  @override
  Widget build(BuildContext context) => FixiaPanel(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            for (var i = 0; i < entries.length; i++)
              _MovementRow(
                entry: entries[i],
                currency: currency,
                divider: i > 0,
              ),
          ],
        ),
      );
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({
    required this.entry,
    required this.currency,
    required this.divider,
  });

  final WalletEntry entry;
  final String currency;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final sign = entry.type.sign;
    final amount = formatCents(entry.amountCents, currency);
    final (IconData icon, Color color) = switch (sign) {
      1 => (Icons.south_west_rounded, const Color(0xFF00745F)),
      -1 => (Icons.north_east_rounded, FixiaColors.primary),
      _ => (Icons.lock_outline_rounded, FixiaColors.textSecondary),
    };
    return Container(
      key: ValueKey('wallet-entry-${entry.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: divider
          ? const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFEEF2F7))),
            )
          : null,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: FixiaColors.supportBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.type.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  formatDateTime(entry.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: FixiaColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${sign > 0 ? '+' : sign < 0 ? '−' : ''}$amount',
                style: TextStyle(fontWeight: FontWeight.w800, color: color),
              ),
              Text(
                'Saldo: ${formatCents(entry.availableAfterCents, currency)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: FixiaColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Recarga (cliente) o retiro (técnico o empresa) con montos rápidos. Lo
/// usan la billetera y el aviso de saldo insuficiente de un servicio.
class WalletAmountDialog extends StatefulWidget {
  const WalletAmountDialog({
    super.key,
    required this.topUp,
    required this.availableCents,
    required this.submit,
    this.currency = 'COP',
    this.suggestedCents,
    this.onError,
  });

  final bool topUp;
  final int availableCents;
  final String currency;
  final Future<Wallet> Function(int amountCents) submit;

  /// Monto inicial (p. ej. lo que falta para pagar un servicio).
  final int? suggestedCents;
  final ValueChanged<Object>? onError;

  @override
  State<WalletAmountDialog> createState() => _WalletAmountDialogState();
}

class _WalletAmountDialogState extends State<WalletAmountDialog> {
  late final _amount = TextEditingController(
    text: widget.suggestedCents == null
        ? ''
        : '${(widget.suggestedCents! + 99) ~/ 100}',
  );
  String? _error;
  bool _sending = false;

  static const _quick = [50000, 100000, 200000, 500000];

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final pesos = int.tryParse(_amount.text.trim());
    if (pesos == null || pesos <= 0) {
      setState(() => _error = 'Escribe un monto mayor que cero, sin puntos.');
      return;
    }
    final cents = pesos * 100;
    if (!widget.topUp && cents > widget.availableCents) {
      setState(() => _error = 'No puedes retirar más de tu saldo disponible.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.submit(cents);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      widget.onError?.call(error);
      if (mounted) {
        setState(() {
          _sending = false;
          _error = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        key: const ValueKey('wallet-amount-dialog'),
        title: Text(widget.topUp ? 'Recargar saldo' : 'Retirar saldo'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Disponible: ${formatCents(widget.availableCents, widget.currency)}',
                style: const TextStyle(color: FixiaColors.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('wallet-amount'),
                controller: _amount,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Monto',
                  prefixText: '${widget.currency} ',
                  errorText: _error,
                  errorMaxLines: 3,
                ),
                onSubmitted: (_) => _send(),
              ),
              if (widget.topUp) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final q in _quick)
                      ActionChip(
                        key: ValueKey('wallet-quick-$q'),
                        label: Text(formatCents(q * 100, widget.currency)),
                        onPressed: () => setState(() => _amount.text = '$q'),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Operación simulada: no se mueve dinero real.',
                style:
                    TextStyle(fontSize: 12, color: FixiaColors.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _sending ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('wallet-amount-confirm'),
            onPressed: _sending ? null : _send,
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            child: Text(
              _sending
                  ? 'Enviando…'
                  : widget.topUp
                      ? 'Recargar'
                      : 'Retirar',
            ),
          ),
        ],
      );
}
