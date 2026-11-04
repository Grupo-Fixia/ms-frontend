class ServiceBudget {
  const ServiceBudget._(this.amount);

  /// Valor decimal canónico interno, sin separadores de miles.
  /// No establece por sí mismo el nombre o tipo de un campo del contrato HTTP.
  final String amount;

  static const currency = 'COP';

  static ServiceBudget? tryParse(String input) {
    final text = input.trim();
    if (!RegExp(r'^[0-9]+(?:[.,][0-9]+)?$').hasMatch(text) ||
        !RegExp(r'[1-9]').hasMatch(text)) {
      return null;
    }
    final parts = text.replaceAll(',', '.').split('.');
    if (parts.first.length > 10 || (parts.length == 2 && parts[1].length > 2)) {
      return null;
    }
    final whole = parts.first.replaceFirst(RegExp(r'^0+(?=[0-9])'), '');
    final fraction =
        parts.length == 2 ? parts[1].replaceFirst(RegExp(r'0+$'), '') : '';
    return ServiceBudget._(fraction.isEmpty ? whole : '$whole.$fraction');
  }

  static String? validate(String? input) {
    if (input == null || input.trim().isEmpty) {
      return 'Ingresa un presupuesto aproximado en COP.';
    }
    if (tryParse(input) == null) {
      return 'Ingresa un valor mayor que cero, con máximo 10 dígitos enteros y 2 decimales, sin separadores de miles.';
    }
    return null;
  }

  num get jsonAmount => num.parse(amount);

  static ServiceBudget? fromJson(Object? amount, Object? currency) {
    if (amount == null && currency == null) return null;
    final budget = amount is num && currency == ServiceBudget.currency
        ? tryParse(amount.toString())
        : null;
    if (budget == null) throw const FormatException('Presupuesto inválido');
    return budget;
  }

  String get label {
    final parts = amount.split('.');
    final digits = parts.first;
    final groups = <String>[];
    for (var end = digits.length; end > 0; end -= 3) {
      groups.insert(0, digits.substring(end > 3 ? end - 3 : 0, end));
    }
    final decimals = parts.length == 2 ? parts[1] : '';
    final fraction = decimals.isEmpty ? '' : ',$decimals';
    final grouped = groups.join('.');
    return '$grouped$fraction COP';
  }
}
