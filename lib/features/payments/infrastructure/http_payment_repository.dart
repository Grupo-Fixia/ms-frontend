import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/http/authorized_http.dart';
import '../application/payment_repository.dart';
import '../domain/payment.dart';

class HttpPaymentRepository implements PaymentRepository {
  HttpPaymentRepository(
      {required http.Client client,
      required Uri baseUrl,
      required AuthorizedHttp authorizedHttp})
      : _client = client,
        _base = baseUrl.resolve('/api/payments/'),
        _http = authorizedHttp;
  final http.Client _client;
  final Uri _base;
  final AuthorizedHttp _http;

  @override
  Future<CommissionQuote> quote(int amountCents, String currency) async {
    if (amountCents <= 0) {
      throw const PaymentFailure('El precio de la cotización no es válido.');
    }
    final amount =
        '${amountCents ~/ 100}.${(amountCents % 100).toString().padLeft(2, '0')}';
    final result = await _request(_base
        .resolve('commission-quote')
        .replace(queryParameters: {'amount': amount, 'currency': currency}));
    final quote = _parse(result!, CommissionQuote.fromJson);
    if (!quote.matches(amountCents, currency)) {
      throw const PaymentFailure(
          'El desglose no corresponde a esta cotización.');
    }
    return quote;
  }

  @override
  Future<ServicePayment?> forRequest(String serviceRequestId) async {
    final result = await _request(
        _base.replace(pathSegments: [
          ..._base.pathSegments.where((s) => s.isNotEmpty),
          'service-request',
          serviceRequestId
        ]),
        allowNotFound: true);
    if (result == null) return null;
    final payment = _parse(result, ServicePayment.fromJson);
    if (payment.serviceRequestId != serviceRequestId) {
      throw const PaymentFailure('El pago no corresponde a este servicio.');
    }
    return payment;
  }

  @override
  Future<WalletBalance> wallet() async => _parse(
      (await _request(_base.resolve('wallets/me')))!, WalletBalance.fromJson);

  @override
  Future<ServicePayment> retryHold(ServicePayment payment) async {
    final current = await forRequest(payment.serviceRequestId);
    if (current == null || current.id != payment.id || !current.canRetryHold) {
      throw const PaymentFailure(
          'No se puede confirmar que este pago permita reintentar una retención.');
    }
    final result = await _request(
        _base.replace(pathSegments: [
          ..._base.pathSegments.where((s) => s.isNotEmpty),
          current.id,
          'process'
        ]),
        post: true);
    final updated = _parse(result!, ServicePayment.fromJson);
    if (updated.id != current.id ||
        updated.serviceRequestId != current.serviceRequestId) {
      throw const PaymentFailure('La respuesta no corresponde a este pago.');
    }
    return updated;
  }

  T _parse<T>(
      Map<String, dynamic> json, T Function(Map<String, dynamic>) parse) {
    try {
      return parse(json);
    } on FormatException {
      throw const PaymentFailure(
          'La respuesta de pagos no es válida. Actualiza para consultar de nuevo.');
    }
  }

  Future<Map<String, dynamic>?> _request(Uri uri,
      {bool post = false, bool allowNotFound = false}) async {
    final http.Response response;
    try {
      response = await _http.send((headers) => post
          ? _client.post(uri, headers: headers)
          : _client.get(uri, headers: headers));
    } on SessionExpiredException {
      throw const PaymentFailure('Tu sesión expiró. Inicia sesión de nuevo.',
          isSessionExpired: true);
    } on BackendUnreachableException {
      throw const PaymentFailure(
          'No pudimos consultar pagos. Revisa tu conexión y actualiza el estado.');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      decoded = null;
    }
    if (response.statusCode == 404 && allowNotFound) return null;
    if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
      return decoded;
    }
    final detail = decoded is Map ? decoded['detail'] : null;
    final title = decoded is Map ? decoded['title'] : null;
    final message = switch (response.statusCode) {
      401 => 'El servicio de pagos no aceptó la sesión. Inténtalo más tarde.',
      403 => 'No tienes permiso para esta operación de pago.',
      404 => 'El pago no está disponible.',
      400 || 409 => detail is String && detail.isNotEmpty
          ? detail
          : 'No se pudo realizar la operación. Actualiza el estado del pago.',
      _ => 'No pudimos consultar pagos. Inténtalo más tarde.',
    };
    throw PaymentFailure(message,
        statusCode: response.statusCode,
        isInsufficientBalance:
            response.statusCode == 409 && title == 'Saldo insuficiente');
  }
}
