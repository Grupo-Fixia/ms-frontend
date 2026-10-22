import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/http/authorized_http.dart';
import '../application/ports/technician_availability_repository.dart';
import '../domain/clock_time.dart';
import '../domain/coverage_zone.dart';
import '../domain/technician_availability_exceptions.dart';
import '../domain/weekday.dart';
import '../domain/weekly_availability.dart';

/// Disponibilidad y zona de atención del técnico contra ms-users (GC-330,
/// API de GC-327).
///
/// Contrato (`docs/openapi.yaml` de ms-users):
/// - `GET/PUT /api/users/technicians/me/availability` con
///   `{slots: [{dayOfWeek, startTime, endTime}]}`; horas `"HH:mm"` de
///   Colombia. El `PUT` reemplaza todas las franjas.
/// - `GET/PUT/DELETE /api/users/technicians/me/coverage-zone` con
///   `{city, latitude, longitude, radiusKm}`; `DELETE` → `204`.
/// - `400` con `errors[{field, message}]` o, para reglas de negocio (franjas
///   que se cruzan, círculo incompleto), solo con `detail`.
/// - `403` el rol no es técnico, `404` sin perfil de técnico, `409` otra
///   solicitud modificó los datos.
class HttpTechnicianAvailabilityRepository
    implements TechnicianAvailabilityRepository {
  HttpTechnicianAvailabilityRepository({
    required http.Client client,
    required Uri baseUrl,
    required AuthorizedHttp authorizedHttp,
  })  : _client = client,
        _availabilityEndpoint = baseUrl.resolve(availabilityPath),
        _zoneEndpoint = baseUrl.resolve(coverageZonePath),
        _http = authorizedHttp;

  static const availabilityPath = '/api/users/technicians/me/availability';
  static const coverageZonePath = '/api/users/technicians/me/coverage-zone';

  static const connectionErrorMessage =
      'No pudimos conectar con Fixia. Revisa tu conexión e inténtalo de nuevo.';
  static const sessionExpiredMessage =
      'Tu sesión expiró. Inicia sesión de nuevo.';
  static const forbiddenMessage = 'Esta sección es solo para técnicos.';
  static const notFoundMessage =
      'No encontramos tu perfil de técnico. Escríbenos a soporte.';
  static const invalidDataMessage = 'Revisa los datos marcados.';
  static const conflictMessage =
      'Tus datos cambiaron en otra pestaña o dispositivo. Recarga e inténtalo de nuevo.';
  static const unexpectedErrorMessage =
      'No pudimos completar la acción. Inténtalo más tarde.';

  static const _jsonHeaders = {
    'Content-Type': 'application/json; charset=utf-8',
  };

  final http.Client _client;
  final Uri _availabilityEndpoint;
  final Uri _zoneEndpoint;
  final AuthorizedHttp _http;

  @override
  Future<WeeklyAvailability> fetchAvailability() async {
    final response = await _send(
      (headers) => _client.get(_availabilityEndpoint, headers: headers),
    );
    return _availabilityFrom(response);
  }

  @override
  Future<WeeklyAvailability> replaceAvailability(
    List<AvailabilitySlot> slots,
  ) async {
    final body = jsonEncode({
      'slots': [
        for (final slot in slots)
          {
            'dayOfWeek': slot.day.apiValue,
            'startTime': slot.start.format(),
            'endTime': slot.end.format(),
          },
      ],
    });
    final response = await _send(
      (headers) => _client.put(
        _availabilityEndpoint,
        headers: {...headers, ..._jsonHeaders},
        body: body,
      ),
    );
    return _availabilityFrom(response);
  }

  @override
  Future<CoverageZone?> fetchCoverageZone() async {
    final response = await _send(
      (headers) => _client.get(_zoneEndpoint, headers: headers),
    );
    return _zoneFrom(response);
  }

  @override
  Future<CoverageZone> updateCoverageZone(CoverageZoneUpdate zone) async {
    final body = jsonEncode({
      'city': zone.city,
      'latitude': zone.latitude,
      'longitude': zone.longitude,
      'radiusKm': zone.radiusKm,
    });
    final response = await _send(
      (headers) => _client.put(
        _zoneEndpoint,
        headers: {...headers, ..._jsonHeaders},
        body: body,
      ),
    );
    final saved = _zoneFrom(response);
    if (saved == null) {
      throw const TechnicianAvailabilityFailure(unexpectedErrorMessage);
    }
    return saved;
  }

  @override
  Future<void> clearCoverageZone() async {
    final response = await _send(
      (headers) => _client.delete(_zoneEndpoint, headers: headers),
    );
    if (response.statusCode == 204 || response.statusCode == 200) return;
    _throwOnError(response);
  }

  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    try {
      return await _http.send(request);
    } on SessionExpiredException {
      throw const TechnicianAvailabilityFailure(
        sessionExpiredMessage,
        isSessionExpired: true,
      );
    } on BackendUnreachableException {
      throw const TechnicianAvailabilityFailure(connectionErrorMessage);
    }
  }

  WeeklyAvailability _availabilityFrom(http.Response response) {
    _throwOnError(response);
    final json = _decode(response);
    if (json is! Map) {
      throw const TechnicianAvailabilityFailure(unexpectedErrorMessage);
    }
    final rawSlots = json['slots'];
    if (rawSlots is! List) {
      throw const TechnicianAvailabilityFailure(unexpectedErrorMessage);
    }
    final slots = <AvailabilitySlot>[];
    for (final raw in rawSlots) {
      if (raw is! Map) continue;
      final day = Weekday.fromApi(_string(raw['dayOfWeek']));
      final start = ClockTime.tryParse(_string(raw['startTime']));
      final end = ClockTime.tryParse(_string(raw['endTime']));
      if (day == null || start == null || end == null) continue;
      slots.add(AvailabilitySlot(day: day, start: start, end: end));
    }
    slots.sort((a, b) {
      final byDay = a.day.index.compareTo(b.day.index);
      return byDay != 0 ? byDay : a.start.compareTo(b.start);
    });
    final timeZone = json['timeZone'];
    return WeeklyAvailability(
      slots: List.unmodifiable(slots),
      timeZone: timeZone is String && timeZone.isNotEmpty
          ? timeZone
          : 'America/Bogota',
      updatedAt: _date(json['updatedAt']),
    );
  }

  /// `null` si el técnico no ha declarado zona (el backend responde la
  /// ciudad en `null`).
  CoverageZone? _zoneFrom(http.Response response) {
    _throwOnError(response);
    final json = _decode(response);
    if (json is! Map) {
      throw const TechnicianAvailabilityFailure(unexpectedErrorMessage);
    }
    final city = json['city'];
    if (city is! String || city.trim().isEmpty) return null;
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    final radius = json['radiusKm'];
    return CoverageZone(
      city: city,
      latitude: latitude is num ? latitude.toDouble() : null,
      longitude: longitude is num ? longitude.toDouble() : null,
      radiusKm: radius is num ? radius.toInt() : null,
      updatedAt: _date(json['updatedAt']),
    );
  }

  void _throwOnError(http.Response response) {
    switch (response.statusCode) {
      case 200:
        return;
      case 400:
        final body = _decode(response);
        final fieldErrors = _fieldErrors(body);
        final detail = body is Map ? body['detail'] : null;
        throw TechnicianAvailabilityFailure(
          fieldErrors.isEmpty && detail is String && detail.trim().isNotEmpty
              ? detail.trim()
              : invalidDataMessage,
          fieldErrors: fieldErrors,
        );
      case 403:
        throw const TechnicianAvailabilityFailure(forbiddenMessage);
      case 404:
        throw const TechnicianAvailabilityFailure(notFoundMessage);
      case 409:
        throw const TechnicianAvailabilityFailure(conflictMessage);
      default:
        throw const TechnicianAvailabilityFailure(unexpectedErrorMessage);
    }
  }

  /// `errors[{field, message}]` del ProblemDetail. `slots[0].startTime` se
  /// agrupa en `slots`; si un campo trae varios errores, se muestra el
  /// primero.
  Map<String, String> _fieldErrors(Object? body) {
    final fieldErrors = <String, String>{};
    final errors = body is Map ? body['errors'] : null;
    if (errors is List) {
      for (final error in errors) {
        if (error is! Map) continue;
        final field = error['field'];
        final message = error['message'];
        if (field is String && message is String && message.trim().isNotEmpty) {
          final name = field.split(RegExp(r'[\[.]')).first;
          fieldErrors.putIfAbsent(name, () => message.trim());
        }
      }
    }
    return fieldErrors;
  }

  String? _string(Object? value) => value is String ? value : null;

  DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  /// Siempre UTF-8, para que las tildes no lleguen dañadas (TD V1, DEF-02).
  Object? _decode(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      return null;
    }
  }
}
