import 'dart:convert';

/// Lexema numérico exacto: un importe de JSON no se convierte a double.
class JsonApplicationAmount {
  const JsonApplicationAmount(this.lexeme);
  final String lexeme;
}

Object? decodeApplicationJson(String source) {
  final decoded = jsonDecode(source);
  // Se reconocen textos completos con escapes para no modificar sus números.
  final tokens = RegExp(
    r'"(?:[^"\\]|\\.)*"|-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?',
  );
  final exact = jsonDecode(source.replaceAllMapped(tokens, (match) {
    final token = match[0]!;
    return token.startsWith('"') ? token : jsonEncode(token);
  }));
  return _restore(decoded, exact);
}

Object? _restore(Object? value, Object? exact, [String? key]) {
  if (key == 'proposedAmount' && value is num && exact is String) {
    return JsonApplicationAmount(exact);
  }
  if (value is Map && exact is Map) {
    return {
      for (final entry in value.entries)
        entry.key: _restore(entry.value, exact[entry.key], entry.key as String)
    };
  }
  if (value is List && exact is List) {
    return [
      for (var i = 0; i < value.length; i++) _restore(value[i], exact[i])
    ];
  }
  return value;
}

/// amount proviene de ProposedPrice: número JSON sin redondear/entrecomillar.
/// La identidad del técnico autenticado nunca se añade al cuerpo.
String encodeApplicationJson({
  required String serviceRequestId,
  required String amount,
  required String currency,
}) {
  final fields = [
    '"serviceRequestId":${jsonEncode(serviceRequestId)}',
    '"proposedAmount":$amount',
    '"currency":${jsonEncode(currency)}',
  ];
  return '{${fields.join(',')}}';
}
