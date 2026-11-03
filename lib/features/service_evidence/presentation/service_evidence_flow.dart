import 'package:flutter/material.dart';
import '../../../core/layout/app_shell.dart';
import '../../../core/widgets/fixia_ui.dart';
import '../../auth/login/domain/user_profile.dart';
import '../application/evidence_feature.dart';
import '../domain/service_evidence.dart';
import '../infrastructure/evidence_file_actions.dart';
import '../infrastructure/evidence_file_picker.dart';
import 'service_evidence_page.dart';

class ServiceEvidenceFlow extends StatefulWidget {
  const ServiceEvidenceFlow(
      {super.key,
      required this.feature,
      required this.target,
      required this.profile,
      required this.onSessionExpired});
  final EvidenceFeature feature;
  final EvidenceTarget target;
  final UserProfile profile;
  final VoidCallback onSessionExpired;
  @override
  State<ServiceEvidenceFlow> createState() => _ServiceEvidenceFlowState();
}

class _ServiceEvidenceFlowState extends State<ServiceEvidenceFlow> {
  late Future<EvidenceConnection> _connection =
      widget.feature.connect(widget.target, widget.profile);
  final _picker = browserEvidenceFilePicker();
  bool _expiryHandled = false;

  ShellDestination get _destination => widget.profile.role == UserRole.client
      ? ShellDestination.clientRequests
      : ShellDestination.technicianJobs;
  void _expired() {
    if (!_expiryHandled && mounted) {
      _expiryHandled = true;
      widget.onSessionExpired();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<EvidenceConnection>(
      future: _connection,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          if (error is EvidenceFailure &&
              error.isSessionExpired &&
              !_expiryHandled) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _expired();
            });
          }
          return AppShell(
              destination: _destination,
              subpage: true,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const BackLink(),
                    const PageHeader(title: 'Evidencias del servicio'),
                    const SizedBox(height: 24),
                    EmptyState(
                      icon: Icons.error_outline_rounded,
                      message: error is EvidenceFailure
                          ? error.message
                          : 'No pudimos consultar la contratación.',
                      action: TextButton(
                          onPressed: () => setState(() => _connection = widget
                              .feature
                              .connect(widget.target, widget.profile)),
                          child: const Text('Reintentar')),
                    ),
                  ]));
        }
        final connection = snapshot.data;
        if (connection == null) {
          return AppShell(
              destination: _destination,
              subpage: true,
              child: const SectionLoading());
        }
        Future<void> download(ServiceEvidence item) async =>
            saveEvidenceFile(await connection.repository.download(item));
        Future<void> open(ServiceEvidence item) async {
          final content = await connection.repository.download(item);
          if (!context.mounted) return;
          if (!content.mimeType.startsWith('image/')) {
            await saveEvidenceFile(content);
            return;
          }
          await showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                      title: Text(content.fileName),
                      content: Image.memory(content.bytes,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Text(
                              'No se pudo mostrar la imagen. Puedes descargar el archivo.')),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cerrar'))
                      ]));
        }

        return ServiceEvidencePage(
            serviceId: connection.access.serviceRequestId,
            canUpload: connection.access.canUpload,
            repository: connection.repository,
            picker: _picker,
            policy: EvidenceFilePolicy.backend,
            openEvidence: open,
            downloadEvidence: download,
            onSessionExpired: _expired,
            destination: _destination);
      });
}
