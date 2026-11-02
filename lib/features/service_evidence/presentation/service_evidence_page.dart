import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../application/ports/evidence_repository.dart';
import '../domain/service_evidence.dart';

/// Recibe un servicio y permisos del flujo autenticado, aún pendiente de integrar.
/// canUpload controla UI; nunca sustituye autorización en Backend.
class ServiceEvidencePage extends StatefulWidget {
  const ServiceEvidencePage({
    super.key,
    required this.serviceId,
    required this.canUpload,
    required this.repository,
    required this.picker,
    required this.policy,
    required this.openEvidence,
    this.downloadEvidence,
    this.onSessionExpired,
  });
  final String serviceId;
  final bool canUpload;
  final EvidenceRepository repository;
  final EvidenceFilePicker picker;
  final EvidenceFilePolicy policy;
  final Future<void> Function(ServiceEvidence) openEvidence;
  final Future<void> Function(ServiceEvidence)? downloadEvidence;
  final VoidCallback? onSessionExpired;

  @override
  State<ServiceEvidencePage> createState() => _ServiceEvidencePageState();
}

class _ServiceEvidencePageState extends State<ServiceEvidencePage> {
  List<ServiceEvidence>? _items;
  EvidenceFile? _selected;
  Uint8List? _preview;
  String? _loadError;
  String? _actionError;
  String? _notice;
  bool _busy = false;
  bool _loading = true;
  bool _uncertain = false;
  bool _expiryHandled = false;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ServiceEvidencePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.serviceId != oldWidget.serviceId ||
        widget.repository != oldWidget.repository ||
        widget.canUpload != oldWidget.canUpload ||
        widget.policy != oldWidget.policy) {
      _revision++;
      _items = null;
      _selected = null;
      _preview = null;
      _busy = false;
      _actionError = null;
      _notice = null;
      _uncertain = false;
      _load();
    }
  }

  Future<void> _load() async {
    final revision = _revision;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      if (widget.serviceId.trim().isEmpty) {
        throw const EvidenceFailure(
            'Abre un servicio para consultar sus evidencias.');
      }
      final items = await widget.repository.list(widget.serviceId);
      if (items.any((item) => item.serviceId != widget.serviceId)) {
        throw const EvidenceFailure(
            'No pudimos verificar las evidencias del servicio.');
      }
      if (mounted && revision == _revision) setState(() => _items = items);
    } catch (error) {
      if (mounted && revision == _revision) {
        setState(() {
          _items = null;
          _loadError = _message(error);
        });
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  String _message(Object error) {
    if (error is EvidenceFailure) {
      if (error.isSessionExpired && !_expiryHandled) {
        _expiryHandled = true;
        final revision = _revision;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && revision == _revision) widget.onSessionExpired?.call();
        });
      }
      return error.message;
    }
    return 'No pudimos completar la operación. Inténtalo de nuevo.';
  }

  Future<void> _pick() async {
    if (_busy ||
        !widget.canUpload ||
        (_items?.length ?? 0) >= EvidenceFilePolicy.maxEvidences) return;
    final revision = _revision;
    setState(() {
      _busy = true;
      _actionError = null;
      _notice = null;
    });
    try {
      final file = await widget.picker.pick(widget.policy);
      if (!mounted || revision != _revision || file == null) return;
      final error = widget.policy.validate(file);
      if (error != null) throw EvidenceFailure(error);
      Uint8List? preview;
      if (file.mimeType == 'image/jpeg' || file.mimeType == 'image/png') {
        preview = await file.readBytes();
        if (preview.length != file.size) {
          throw const EvidenceFailure('No pudimos leer el archivo completo.');
        }
      }
      if (mounted && revision == _revision) {
        setState(() {
          _selected = file;
          _preview = preview;
        });
      }
    } catch (error) {
      if (mounted && revision == _revision) {
        setState(() {
          _selected = null;
          _preview = null;
          _actionError = _message(error);
        });
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    final file = _selected;
    if (_busy ||
        !widget.canUpload ||
        file == null ||
        _uncertain ||
        (_items?.length ?? 0) >= EvidenceFilePolicy.maxEvidences) return;
    final revision = _revision;
    setState(() {
      _busy = true;
      _actionError = null;
      _notice = null;
    });
    try {
      final error = widget.policy.validate(file);
      if (error != null) throw EvidenceFailure(error);
      final saved = await widget.repository.upload(widget.serviceId, file);
      if (!mounted || revision != _revision) return;
      if (saved.serviceId != widget.serviceId || saved.id.isEmpty) {
        throw const EvidenceFailure(
            'No pudimos confirmar la evidencia del servicio.');
      }
      setState(() {
        _selected = null;
        _preview = null;
        _notice = 'Evidencia registrada.';
      });
      await _load();
    } catch (error) {
      if (mounted && revision == _revision) {
        final message = _message(error);
        if (mounted) {
          setState(() {
            _actionError = message;
            _uncertain = error is EvidenceFailure && error.submissionUncertain;
          });
        }
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _busy = false);
    }
  }

  Future<void> _open(ServiceEvidence item, {bool download = false}) async {
    if (_busy) return;
    final revision = _revision;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      await (download
          ? widget.downloadEvidence ?? widget.openEvidence
          : widget.openEvidence)(item);
    } catch (error) {
      if (mounted && revision == _revision) {
        setState(() => _actionError = _message(error));
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_busy,
        child: Scaffold(
          appBar: AppBar(title: const Text('Evidencias del servicio')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                      'JPEG, PNG, WebP o PDF. Máximo 10 MB por archivo y 10 evidencias por servicio.'),
                  if (!widget.canUpload)
                    const Text(
                        'Solo consulta: la carga requiere al técnico contratado y un servicio en curso o finalizado por él.'),
                  if ((_items?.length ?? 0) >= EvidenceFilePolicy.maxEvidences)
                    const Text(
                        'Se alcanzó el límite de 10 evidencias para este servicio.'),
                  if (widget.canUpload) ...[
                    OutlinedButton(
                      key: const ValueKey('evidence-pick'),
                      onPressed: _busy ||
                              _loading ||
                              _loadError != null ||
                              (_items?.length ?? 0) >=
                                  EvidenceFilePolicy.maxEvidences
                          ? null
                          : _pick,
                      child: const Text('Seleccionar archivo'),
                    ),
                    if (_selected != null) ...[
                      Text(_selected!.name,
                          key: const ValueKey('evidence-selected')),
                      const Text('Archivo local, pendiente de cargar.'),
                      if (_preview != null)
                        Image.memory(_preview!,
                            height: 160,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const Text('Vista previa no disponible.')),
                      TextButton(
                        key: const ValueKey('evidence-remove'),
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                  _selected = null;
                                  _preview = null;
                                }),
                        child: const Text('Quitar archivo'),
                      ),
                      FilledButton(
                        key: const ValueKey('evidence-upload'),
                        onPressed: _busy ||
                                _loading ||
                                _loadError != null ||
                                _uncertain
                            ? null
                            : _upload,
                        child: const Text('Cargar evidencia'),
                      ),
                    ],
                  ],
                  if (_busy)
                    const LinearProgressIndicator(
                        key: ValueKey('evidence-busy')),
                  if (_actionError != null)
                    Text(_actionError!,
                        key: const ValueKey('evidence-action-error')),
                  if (_notice != null)
                    Text(_notice!, key: const ValueKey('evidence-notice')),
                  const SizedBox(height: 20),
                  const Text('Evidencias registradas'),
                  TextButton(
                      onPressed: _busy || _loading ? null : _load,
                      child: const Text('Actualizar evidencias')),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else if (_loadError != null) ...[
                    Text(_loadError!,
                        key: const ValueKey('evidence-load-error')),
                    TextButton(
                        onPressed: _busy ? null : _load,
                        child: const Text('Reintentar consulta')),
                  ] else if (_items!.isEmpty)
                    const Text('Todavía no hay evidencias registradas.')
                  else
                    for (final item in _items!)
                      ListTile(
                        title: Text(item.fileName),
                        subtitle: Text(
                            '${item.author} · ${item.createdAt.toLocal()}'),
                        trailing:
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            tooltip: 'Abrir evidencia',
                            onPressed: _busy ? null : () => _open(item),
                            icon: const Icon(Icons.open_in_new),
                          ),
                          if (widget.downloadEvidence != null)
                            IconButton(
                                tooltip: 'Descargar evidencia',
                                onPressed: _busy
                                    ? null
                                    : () => _open(item, download: true),
                                icon: const Icon(Icons.download_outlined)),
                        ]),
                      ),
                ],
              ),
            ),
          ),
        ),
      );
}
