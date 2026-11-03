import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/http/authorized_http.dart';
import '../domain/payments.dart';
import '../presentation/wallet_page.dart';

/// Billetera y pagos simulados contra ms-payments (GC-476, pantallas GC-489
/// y GC-491). Rutas bajo `/api/payments` con el token de login:
/// - `GET /wallets/me`, `GET /wallets/me/entries?limit=&cursor=`.
/// - `POST /wallets/me/top-ups` (cliente) y `POST /wallets/me/withdrawals`
///   (técnico o empresa) con `{amount}` e `Idempotency-Key`.
/// - `GET /commission-quote?amount=`.
/// - `GET /service-request/{id}` (`404` si aún no hay pago) y
///   `POST /{id}/process` para reintentar la retención.
/// Errores como ProblemDetails; se muestra su `detail`.
class HttpPaymentsRepository implements WalletGateway {
  HttpPaymentsRepository({
    required http.Client client,
    required Uri baseUrl,
    required AuthorizedHttp authorizedHttp,
  })  : _client = client,
        _base = baseUrl.resolve('/api/payments/'),
        _http = authorizedHttp;

  static const connectionErrorMessage =
      'No pudimos conectar con Fixia. Revisa tu conexión e inténtalo de nuevo.';
  static const sessionExpiredMessage =
      'Tu sesión expiró. Inicia sesión de nuevo.';
  static const unavailableMessage =
      'Los pagos no están disponibles en este momento. Inténtalo más tarde.';
  static const forbiddenMessage = 'Tu cuenta no puede hacer esta operación.';

  final http.Client _client;
  final Uri _base;
  final AuthorizedHttp _http;

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = _base.resolve(path);
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  @override
  Future<Wallet> wallet() async {
    final json = _object(await _get(_uri('wallets/me')));
    return _wallet(json);
  }

  @override
  Future<WalletEntriesPage> entries({String? cursor, int limit = 20}) async {
    final json = _object(await _get(_uri('wallets/me/entries', {
      'limit': '$limit',
      if (cursor != null) 'cursor': cursor,
    })));
    final items = json['items'];
    if (items is! List) throw const PaymentsFailure(unavailableMessage);
    final next = json['nextCursor'];
    return WalletEntriesPage(
      items: List.unmodifiable([
        for (final item in items)
          if (_entry(item) case final entry?) entry,
      ]),
      nextCursor: next is String && next.isNotEmpty ? next : null,
    );
  }

  @override
  Future<Wallet> topUp(int amountCents) =>
      _walletOperation('wallets/me/top-ups', amountCents);

  @override
  Future<Wallet> withdraw(int amountCents) =>
      _walletOperation('wallets/me/withdrawals', amountCents);

  Future<CommissionQuote> commissionQuote(int priceCents,
      {String currency = 'COP'}) async {
    final quote = _parse(
        _object(await _get(_uri('commission-quote',
            {'amount': _pesos(priceCents), 'currency': currency}))),
        CommissionQuote.fromJson);
    if (!quote.matches(priceCents, currency)) {
      throw const PaymentsFailure(
          'El desglose no corresponde a esta cotización.');
    }
    return quote;
  }

  Future<ServicePayment?> paymentForRequest(String serviceRequestId) async {
    final response = await _send((h) => _client.get(
        _base.replace(pathSegments: [
          ..._base.pathSegments.where((s) => s.isNotEmpty),
          'service-request',
          serviceRequestId
        ]),
        headers: h));
    if (response.statusCode == 404) return null;
    _check(response);
    final payment = _payment(_object(response));
    if (payment.serviceRequestId != serviceRequestId) {
      throw const PaymentsFailure('El pago no corresponde a este servicio.');
    }
    return payment;
  }

  Future<ServicePayment> retryHold(String paymentId) async {
    final currentResponse = await _get(_base.replace(pathSegments: [
      ..._base.pathSegments.where((s) => s.isNotEmpty),
      paymentId
    ]));
    final current = _payment(_object(currentResponse));
    if (current.id != paymentId || !current.canRetryHold) {
      throw const PaymentsFailure(
          'El reintento de retención no está disponible para este pago.');
    }
    final response = await _send((h) => _client.post(
        _base.replace(pathSegments: [
          ..._base.pathSegments.where((s) => s.isNotEmpty),
          paymentId,
          'process'
        ]),
        headers: h));
    _check(response);
    final updated = _payment(_object(response));
    if (updated.id != current.id ||
        updated.serviceRequestId != current.serviceRequestId) {
      throw const PaymentsFailure('La respuesta no corresponde a este pago.');
    }
    return updated;
  }

  T _parse<T>(Map json, T Function(Map<String, dynamic>) parse) {
    try {
      return parse(Map<String, dynamic>.from(json));
    } on FormatException {
      throw const PaymentsFailure(unavailableMessage);
    }
  }

  Future<Wallet> _walletOperation(String path, int amountCents) async {
    final key = newIdempotencyKey();
    final response = await _send((h) => _client.post(
          _uri(path),
          headers: {
            ...h,
            'Content-Type': 'application/json',
            'Idempotency-Key': key,
          },
          body: jsonEncode({'amount': num.parse(_pesos(amountCents))}),
        ));
    _check(response, success: 201);
    final json = _object(response);
    return _wallet(json);
  }

  Wallet _wallet(Map json) => _parse(
      json,
      (data) => Wallet(
          availableCents: moneyInCents(data['availableBalance']),
          heldCents: moneyInCents(data['heldBalance']),
          currency: requiredText(data, 'currency')));

  ServicePayment _payment(Map json) => _parse(json, ServicePayment.fromJson);

  WalletEntry? _entry(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final type = WalletEntryType.fromApi(json['type']);
    final created = DateTime.tryParse('${json['createdAt']}');
    if (id is! String ||
        type == null ||
        created == null ||
        json['amount'] is! num) {
      return null;
    }
    final reference = json['reference'];
    return WalletEntry(
      id: id,
      type: type,
      amountCents: pesosToCents(json['amount'] as num),
      availableAfterCents: pesosToCents(_num(json['availableAfter'])),
      heldAfterCents: pesosToCents(_num(json['heldAfter'])),
      createdAt: created,
      reference: reference is String ? reference : null,
    );
  }

  Future<http.Response> _get(Uri uri) async {
    final response = await _send((h) => _client.get(uri, headers: h));
    _check(response);
    return response;
  }

  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    try {
      return await _http.send(request);
    } on SessionExpiredException {
      throw const PaymentsFailure(sessionExpiredMessage,
          isSessionExpired: true);
    } on BackendUnreachableException {
      throw const PaymentsFailure(connectionErrorMessage);
    }
  }

  void _check(http.Response response, {int success = 200}) {
    final status = response.statusCode;
    if (status == success || status == 200) return;
    if (status == 403) {
      throw const PaymentsFailure(forbiddenMessage, statusCode: 403);
    }
    if (status >= 400 && status < 500) {
      final body = _decode(response);
      final detail = body is Map ? body['detail'] ?? body['title'] : null;
      throw PaymentsFailure(
        detail is String && detail.trim().isNotEmpty
            ? detail.trim()
            : unavailableMessage,
        statusCode: status,
        isInsufficientBalance: status == 409 &&
            body is Map &&
            body['title'] == 'Saldo insuficiente',
      );
    }
    throw PaymentsFailure(unavailableMessage, statusCode: status);
  }

  Object? _decode(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      return null;
    }
  }

  Map _object(http.Response response) {
    final json = _decode(response);
    if (json is! Map) throw const PaymentsFailure(unavailableMessage);
    return json;
  }

  static num _num(Object? value) => value is num ? value : 0;

  /// 15000050 centavos → «150000.5».
  static String _pesos(int cents) {
    final whole = cents ~/ 100;
    final rest = cents % 100;
    if (rest == 0) return '$whole';
    return '$whole.${rest.toString().padLeft(2, '0')}';
  }
}
