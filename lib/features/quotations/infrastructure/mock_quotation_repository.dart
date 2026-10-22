import '../application/ports/quotation_decision_repository.dart';
import '../application/ports/quotation_repository.dart';
import '../domain/quotation.dart';
import '../domain/quotation_exceptions.dart';

/// Cotizaciones en memoria para pruebas sin red y para el flujo E2E
/// (GC-355). Imita al backend: al enviar una nueva, la anterior que seguía
/// enviada queda reemplazada.
class MockQuotationRepository
    implements QuotationRepository, QuotationDecisionRepository {
  MockQuotationRepository({
    required this.providerId,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Prestador que envía las cotizaciones (el técnico de la sesión simulada).
  final String providerId;
  final DateTime Function() _now;

  final List<Quotation> _items = [];
  int _sequence = 0;

  @override
  Future<Quotation> send(NewQuotation quotation) async {
    final amount = quotation.amountInCents;
    final agreedAt = quotation.agreedAt;
    final validUntil = quotation.validUntil;
    if (amount == null || agreedAt == null || validUntil == null) {
      throw const QuotationFailure('Revisa los datos marcados.');
    }
    final now = _now();
    for (var i = 0; i < _items.length; i++) {
      final previous = _items[i];
      if (previous.serviceRequestId == quotation.serviceRequestId &&
          previous.status == QuotationStatus.sent) {
        _items[i] = _copy(previous, status: QuotationStatus.superseded);
      }
    }
    final created = Quotation(
      id: 'cotizacion-${++_sequence}',
      serviceRequestId: quotation.serviceRequestId,
      providerId: providerId,
      amountInCents: amount,
      currency: quotation.currency,
      scope: quotation.scope,
      conditions: quotation.conditions,
      agreedAt: agreedAt,
      validUntil: validUntil,
      status: QuotationStatus.sent,
      statusName: QuotationStatus.sent.label,
      materials: quotation.materials,
      createdAt: now,
      updatedAt: now,
    );
    _items.insert(0, created);
    return created;
  }

  @override
  Future<List<Quotation>> listMine({String? serviceRequestId}) async =>
      List.unmodifiable(
        _items
            .where((q) =>
                serviceRequestId == null ||
                q.serviceRequestId == serviceRequestId)
            .map(_view),
      );

  @override
  Future<Quotation> getMine(String id) async => _view(_find(id));

  @override
  Future<List<Quotation>> listForRequest(String serviceRequestId) async =>
      List.unmodifiable(
        _items.where((q) => q.serviceRequestId == serviceRequestId).map(_view),
      );

  @override
  Future<Quotation> accept(String quotationId) =>
      _decide(quotationId, QuotationStatus.accepted);

  @override
  Future<Quotation> reject(String quotationId, {String? reason}) =>
      _decide(quotationId, QuotationStatus.rejected, reason: reason);

  Future<Quotation> _decide(
    String id,
    QuotationStatus status, {
    String? reason,
  }) async {
    final index = _items.indexWhere((q) => q.id == id);
    if (index < 0) {
      throw const QuotationFailure('No encontramos esa cotización.');
    }
    if (!_view(_items[index]).isOpen) {
      throw const QuotationFailure(
          'La cotización ya no está disponible para responder.');
    }
    return _items[index] = _copy(
      _items[index],
      status: status,
      rejectionReason: reason,
      respondedAt: _now(),
    );
  }

  /// Simula que pasó la vigencia (para probar el estado "Vencida").
  void expire(String id) {
    final index = _items.indexWhere((q) => q.id == id);
    if (index < 0) return;
    _items[index] = _copy(_items[index], status: QuotationStatus.expired);
  }

  Quotation _find(String id) {
    for (final quotation in _items) {
      if (quotation.id == id) return quotation;
    }
    throw const QuotationFailure('No encontramos esa cotización.');
  }

  /// Marca como vencida la enviada cuya vigencia ya pasó.
  Quotation _view(Quotation quotation) {
    if (quotation.status == QuotationStatus.sent &&
        !quotation.validUntil.isAfter(_now())) {
      return _copy(quotation, isExpired: true);
    }
    return quotation;
  }

  Quotation _copy(
    Quotation q, {
    QuotationStatus? status,
    bool? isExpired,
    String? rejectionReason,
    DateTime? respondedAt,
  }) {
    final newStatus = status ?? q.status;
    return Quotation(
      id: q.id,
      serviceRequestId: q.serviceRequestId,
      providerId: q.providerId,
      amountInCents: q.amountInCents,
      currency: q.currency,
      scope: q.scope,
      conditions: q.conditions,
      agreedAt: q.agreedAt,
      validUntil: q.validUntil,
      status: newStatus,
      statusName: newStatus.label,
      materials: q.materials,
      isExpired: isExpired ?? q.isExpired,
      rejectionReason: rejectionReason ?? q.rejectionReason,
      respondedAt: respondedAt ?? q.respondedAt,
      createdAt: q.createdAt,
      updatedAt: _now(),
    );
  }
}
