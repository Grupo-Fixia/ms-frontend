import '../domain/quotation.dart';

/// Valor en pesos con separador de miles: `$1.250.000` o `$1.250.000,50`.
String formatMoney(int cents) {
  final negative = cents < 0;
  final absolute = cents.abs();
  final pesos = (absolute ~/ 100).toString();
  final decimals = absolute % 100;
  final grouped = pesos.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  final suffix = decimals == 0 ? '' : ',${decimals.toString().padLeft(2, '0')}';
  return '${negative ? '-' : ''}\$$grouped$suffix';
}

/// Fecha `dd/MM/aaaa`.
String formatDate(DateTime date) {
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}';
}

/// Texto del estado visible para el cliente: `ACEPTADA`, `RECHAZADA`,
/// `VENCIDA`, etc. Una cotización enviada cuya vigencia pasó se muestra
/// como vencida.
String quotationStatusText(Quotation quotation) {
  if (quotation.status == QuotationStatus.sent && quotation.isExpired) {
    return QuotationStatus.expired.label;
  }
  return quotation.statusName;
}
