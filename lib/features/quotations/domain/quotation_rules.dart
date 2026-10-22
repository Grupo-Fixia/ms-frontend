import 'quotation.dart';

/// Reglas para enviar una cotización.
///
/// Replican las de ms-services (`CreateQuotationRequest` y `Quotation`) para
/// que el prestador vea el error antes de enviar. Las claves de los errores
/// son los nombres de campo del backend.
abstract final class QuotationRules {
  static const textMaxLength = 2000;
  static const currencies = {'COP'};

  /// Hasta 10 dígitos enteros y 2 decimales (`@Digits(10, 2)`).
  static const maxAmountInCents = 9999999999 * 100 + 99;

  static final _amountPattern = RegExp(r'^\d{1,10}([.,]\d{1,2})?$');

  /// Convierte el valor escrito ("150000", "150000.5", "150.000,50" no) a
  /// centavos. Acepta punto o coma como separador decimal y hasta dos
  /// decimales; `null` si no es un número válido.
  static int? parseAmount(String text) {
    final value = text.trim();
    if (!_amountPattern.hasMatch(value)) return null;
    final parts = value.replaceAll(',', '.').split('.');
    final pesos = int.parse(parts[0]);
    final cents = parts.length > 1 ? int.parse(parts[1].padRight(2, '0')) : 0;
    return pesos * 100 + cents;
  }

  /// Errores por campo; vacío si la cotización es válida. [now] es el
  /// momento del envío.
  static Map<String, String> validate(NewQuotation quotation,
      {required DateTime now}) {
    final errors = <String, String>{};

    if (quotation.serviceRequestId.trim().isEmpty) {
      errors['serviceRequestId'] = 'Falta la solicitud que cotizas.';
    }

    final amount = quotation.amountInCents;
    if (amount == null) {
      errors['amount'] = 'Escribe el valor con máximo dos decimales.';
    } else if (amount <= 0) {
      errors['amount'] = 'El valor debe ser mayor que cero.';
    } else if (amount > maxAmountInCents) {
      errors['amount'] = 'El valor admite máximo 10 dígitos enteros.';
    }

    if (!currencies.contains(quotation.currency)) {
      errors['currency'] = 'La moneda debe ser pesos colombianos (COP).';
    }

    _text(errors, 'scope', quotation.scope, 'Describe el alcance del trabajo.',
        'El alcance');
    _text(errors, 'conditions', quotation.conditions,
        'Escribe las condiciones.', 'Las condiciones');

    final agreedAt = quotation.agreedAt;
    final validUntil = quotation.validUntil;
    if (agreedAt == null) {
      errors['agreedAt'] = 'Indica la fecha acordada para el servicio.';
    } else if (!agreedAt.isAfter(now)) {
      errors['agreedAt'] = 'La fecha acordada debe ser posterior a ahora.';
    }
    if (validUntil == null) {
      errors['validUntil'] = 'Indica hasta cuándo es válida la cotización.';
    } else if (!validUntil.isAfter(now)) {
      errors['validUntil'] = 'La vigencia debe ser posterior a ahora.';
    } else if (agreedAt != null && validUntil.isAfter(agreedAt)) {
      errors['validUntil'] =
          'La vigencia no puede ser posterior a la fecha acordada.';
    }
    return errors;
  }

  static void _text(Map<String, String> errors, String field, String value,
      String emptyMessage, String label) {
    final text = value.trim();
    if (text.isEmpty) {
      errors[field] = emptyMessage;
    } else if (text.length > textMaxLength) {
      errors[field] = '$label no puede superar $textMaxLength caracteres.';
    }
  }
}
