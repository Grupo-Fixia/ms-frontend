import 'package:flutter/foundation.dart';

import '../application/company_use_cases.dart';
import '../domain/associated_technician.dart';
import '../domain/company_exceptions.dart';

/// En qué punto está la consulta de técnicos de la empresa.
enum CompanyTechniciansStatus { idle, loading, ready, failure }

/// Estado del listado de técnicos asociados a la empresa autenticada
/// (GC-467). Lo usan la pantalla «Mis técnicos» y el selector de la
/// postulación empresarial (GC-469), para que ambos lean la misma fuente
/// real y no haya una lista de técnicos independiente.
class CompanyTechniciansController extends ChangeNotifier {
  CompanyTechniciansController(this._listTechnicians);

  final ListCompanyTechnicians _listTechnicians;

  CompanyTechniciansStatus _status = CompanyTechniciansStatus.idle;
  List<AssociatedTechnician> _technicians = const [];
  String? _errorMessage;
  bool _sessionExpired = false;
  int _request = 0;

  CompanyTechniciansStatus get status => _status;
  bool get isLoading => _status == CompanyTechniciansStatus.loading;

  /// Técnicos de la última consulta exitosa, en el orden en que se asociaron.
  List<AssociatedTechnician> get technicians => _technicians;

  /// Mensaje listo para mostrar cuando [status] es `failure`.
  String? get errorMessage => _errorMessage;

  /// La sesión venció durante la consulta: hay que volver al login.
  bool get sessionExpired => _sessionExpired;

  /// Consulta (o vuelve a consultar) los técnicos en el backend. Si llega
  /// una respuesta de una consulta anterior, se descarta.
  Future<void> load() async {
    final request = ++_request;
    _status = CompanyTechniciansStatus.loading;
    _errorMessage = null;
    _sessionExpired = false;
    notifyListeners();
    try {
      final technicians = await _listTechnicians();
      if (request != _request) return;
      _technicians = technicians;
      _status = CompanyTechniciansStatus.ready;
    } on CompanyFailure catch (failure) {
      if (request != _request) return;
      _errorMessage = failure.message;
      _sessionExpired = failure.isSessionExpired;
      _status = CompanyTechniciansStatus.failure;
    } catch (_) {
      if (request != _request) return;
      _errorMessage = unexpectedErrorMessage;
      _status = CompanyTechniciansStatus.failure;
    }
    notifyListeners();
  }

  static const unexpectedErrorMessage =
      'No pudimos cargar tus técnicos. Inténtalo de nuevo.';

  /// Técnicos de la empresa que una oportunidad admite, según los
  /// `eligibleTechnicianIds` que entrega ms-services (GC-468), en el orden de
  /// la empresa. Un id que no está en la lista de la empresa se ignora: el
  /// backend vuelve a validar la asociación al postular.
  List<AssociatedTechnician> eligibleFor(Iterable<String> eligibleIds) {
    final ids = eligibleIds.toSet();
    return List.unmodifiable(
      _technicians.where((technician) => ids.contains(technician.userId)),
    );
  }

  /// El técnico de la empresa con ese id, o `null` si no está en la lista.
  AssociatedTechnician? byId(String userId) {
    for (final technician in _technicians) {
      if (technician.userId == userId) return technician;
    }
    return null;
  }
}
