/// Precio propuesto, distinto del presupuesto y del importe contractual.
/// Decimal exacto en COP, sin máximo de negocio ni redondeo implícito.
class ProposedPrice {
  const ProposedPrice._(this.amount);
  final String amount;
  static const currency = 'COP';

  static ProposedPrice? tryParse(String input) {
    final text = input.trim();
    if (!RegExp(r'^[0-9]+(?:[.,][0-9]{1,2})?$').hasMatch(text) ||
        !RegExp(r'[1-9]').hasMatch(text)) return null;
    final parts = text.replaceAll(',', '.').split('.');
    final whole = parts.first.replaceFirst(RegExp(r'^0+(?=[0-9])'), '');
    final fraction =
        parts.length == 2 ? parts[1].replaceFirst(RegExp(r'0+$'), '') : '';
    return ProposedPrice._(fraction.isEmpty ? whole : '$whole.$fraction');
  }

  static String? validate(String? input) {
    if (input == null || input.trim().isEmpty) {
      return 'Ingresa el precio que propones en COP.';
    }
    return tryParse(input) == null
        ? 'Ingresa un número mayor que cero, con máximo dos decimales y sin separadores de miles.'
        : null;
  }

  String get label {
    final parts = amount.split('.');
    final groups = <String>[];
    final digits = parts.first;
    for (var end = digits.length; end > 0; end -= 3) {
      groups.insert(0, digits.substring(end > 3 ? end - 3 : 0, end));
    }
    final whole = groups.join('.');
    final decimals = parts.length == 2 ? ',${parts[1]}' : '';
    return '$whole$decimals COP';
  }
}
