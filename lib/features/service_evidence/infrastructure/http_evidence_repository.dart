import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../../../core/http/authorized_http.dart';
import '../application/ports/evidence_repository.dart';
import '../domain/service_evidence.dart';

class HttpEvidenceRepository implements EvidenceContentRepository {
  HttpEvidenceRepository(
      {required http.Client client,
      required Uri baseUrl,
      required AuthorizedHttp authorizedHttp,
      required this.access})
      : _client = client,
        _base = baseUrl,
        _http = authorizedHttp;
  final http.Client _client;
  final Uri _base;
  final AuthorizedHttp _http;
  final EvidenceAccess access;
  static const uncertain =
      'No pudimos confirmar la carga. Actualiza las evidencias antes de volver a enviar el archivo.';
  String get _path => access.actor == EvidenceActor.professional
      ? '/api/services/contracts/${Uri.encodeComponent(access.contractId)}/evidences'
      : '/api/services/requests/${Uri.encodeComponent(access.serviceRequestId)}/evidences';
  Uri get _url => _base.resolve(_path);

  void _scope(String id) {
    if (id.isEmpty ||
        id != access.serviceRequestId ||
        access.contractId.isEmpty) {
      throw const EvidenceFailure(
          'La evidencia no corresponde al servicio seleccionado.');
    }
  }

  Object? _decode(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      return null;
    }
  }

  Never _error(http.Response response, {bool uploading = false}) {
    final json = _decode(response);
    final detail = json is Map && json['detail'] is String
        ? json['detail'] as String
        : null;
    switch (response.statusCode) {
      case 400:
        throw EvidenceFailure(
            detail ?? 'El archivo no cumple las condiciones de carga.');
      case 401:
        throw const EvidenceFailure(
            'El servicio de evidencias rechazó la sesión. Inténtalo más tarde.');
      case 403:
        throw const EvidenceFailure(
            'No tienes permiso para realizar esta operación.');
      case 404:
        throw const EvidenceFailure(
            'No se encontró el servicio o la evidencia solicitada.');
      case 409:
        throw EvidenceFailure(detail ??
            'El estado del servicio o el límite de evidencias impide la carga.');
      case 413:
        throw const EvidenceFailure(
            'El archivo supera el límite de carga de 10 MB.');
      default:
        throw EvidenceFailure(
            uploading
                ? uncertain
                : 'No pudimos consultar las evidencias. Inténtalo de nuevo.',
            submissionUncertain: uploading);
    }
  }

  Future<http.Response> _send(
      Future<http.Response> Function(Map<String, String>) call,
      {bool uploading = false}) async {
    try {
      return await _http.send(call);
    } on SessionExpiredException {
      throw const EvidenceFailure('Tu sesión expiró. Inicia sesión de nuevo.',
          isSessionExpired: true);
    } on BackendUnreachableException {
      throw EvidenceFailure(
          uploading
              ? uncertain
              : 'No pudimos conectar con Fixia. Revisa tu conexión.',
          submissionUncertain: uploading);
    }
  }

  ServiceEvidence _parse(Object? json) {
    if (json is! Map) {
      throw const EvidenceFailure('La respuesta de evidencias no es válida.');
    }
    final id = json['id'],
        request = json['serviceRequestId'],
        contract = json['contractId'],
        author = json['uploadedBy'];
    final mime = json['contentType'],
        size = json['sizeBytes'],
        hash = json['sha256'];
    final created = json['createdAt'] is String
        ? DateTime.tryParse(json['createdAt'])
        : null;
    if (id is! String ||
        id.trim().isEmpty ||
        request != access.serviceRequestId ||
        contract != access.contractId ||
        author is! String ||
        (access.providerId != null && author != access.providerId) ||
        author.trim().isEmpty ||
        mime is! String ||
        !EvidenceFilePolicy.backend.mimeTypes.contains(mime) ||
        size is! int ||
        size <= 0 ||
        size > EvidenceFilePolicy.backend.maxBytes ||
        hash is! String ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(hash) ||
        created == null) {
      throw const EvidenceFailure(
          'No pudimos verificar los metadatos de la evidencia.');
    }
    final extension = _extension(mime);
    return ServiceEvidence(
        id: id,
        serviceId: request as String,
        contractId: contract as String,
        fileName: '$id.$extension',
        author: author,
        createdAt: created,
        contentType: mime,
        sizeBytes: size,
        sha256: hash);
  }

  String _extension(String mime) => switch (mime) {
        'image/jpeg' => 'jpg',
        'image/png' => 'png',
        'image/webp' => 'webp',
        _ => 'pdf'
      };
  @override
  Future<List<ServiceEvidence>> list(String serviceId) async {
    _scope(serviceId);
    final response =
        await _send((headers) => _client.get(_url, headers: headers));
    if (response.statusCode != 200) _error(response);
    final json = _decode(response);
    if (json is! List) {
      throw const EvidenceFailure('La lista de evidencias no es válida.');
    }
    final items = json.map(_parse).toList();
    if (items.length > EvidenceFilePolicy.maxEvidences ||
        items.map((e) => e.id).toSet().length != items.length) {
      throw const EvidenceFailure(
          'La lista contiene evidencias inconsistentes.');
    }
    return List.unmodifiable(items);
  }

  @override
  Future<ServiceEvidence> upload(String serviceId, EvidenceFile file) async {
    _scope(serviceId);
    if (access.actor != EvidenceActor.professional || !access.canUpload) {
      throw const EvidenceFailure(
          'Solo el técnico contratado puede cargar en un servicio en curso o finalizado por él.');
    }
    final invalid = EvidenceFilePolicy.backend.validate(file);
    if (invalid != null) throw EvidenceFailure(invalid);
    final bytes = await file.readBytes();
    if (bytes.length != file.size) {
      throw const EvidenceFailure('No pudimos leer el archivo completo.');
    }
    final response = await _send((headers) async {
      final request = http.MultipartRequest('POST', _url)
        ..headers.addAll(headers);
      request.files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: file.name, contentType: MediaType.parse(file.mimeType)));
      return http.Response.fromStream(await _client.send(request));
    }, uploading: true);
    if (response.statusCode != 201) _error(response, uploading: true);
    try {
      final saved = _parse(_decode(response));
      if (saved.sizeBytes != bytes.length ||
          saved.contentType != file.mimeType.toLowerCase()) {
        throw const EvidenceFailure(uncertain, submissionUncertain: true);
      }
      final confirmed = await list(serviceId);
      return confirmed.firstWhere((e) =>
          e.id == saved.id &&
          e.sha256 == saved.sha256 &&
          e.sizeBytes == saved.sizeBytes);
    } catch (error) {
      if (error is EvidenceFailure && error.isSessionExpired) rethrow;
      throw const EvidenceFailure(uncertain, submissionUncertain: true);
    }
  }

  @override
  Future<EvidenceDownload> download(ServiceEvidence evidence) async {
    _scope(evidence.serviceId);
    if (evidence.contractId != access.contractId) {
      throw const EvidenceFailure(
          'La evidencia pertenece a otra contratación.');
    }
    final uri =
        _base.resolve('$_path/${Uri.encodeComponent(evidence.id)}/content');
    final response = await _send((headers) => _client.get(uri, headers: {
          ...headers,
          'Accept': evidence.contentType ?? 'application/octet-stream'
        }));
    if (response.statusCode != 200) _error(response);
    final mime = (response.headers['content-type'] ?? '')
        .split(';')
        .first
        .trim()
        .toLowerCase();
    if (mime != evidence.contentType ||
        response.bodyBytes.length != evidence.sizeBytes) {
      throw const EvidenceFailure(
          'El archivo recibido no coincide con sus metadatos.');
    }
    return EvidenceDownload(
        bytes: response.bodyBytes, mimeType: mime, fileName: evidence.fileName);
  }
}
