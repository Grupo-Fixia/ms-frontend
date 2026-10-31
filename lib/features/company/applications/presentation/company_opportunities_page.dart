import 'package:flutter/material.dart';
import '../../../home/presentation/widgets/dashboard_components.dart';
import '../../technicians/presentation/company_technicians_controller.dart';
import '../application/company_repositories.dart';
import 'company_opportunities_panel.dart';

class CompanyOpportunitiesPage extends StatefulWidget {
  const CompanyOpportunitiesPage(
      {super.key,
      required this.sessionKey,
      required this.techniciansController,
      required this.applications,
      required this.opportunities,
      required this.onBack,
      required this.onSessionExpired});
  final String sessionKey;
  final CompanyTechniciansController techniciansController;
  final CompanyApplicationRepository applications;
  final CompanyOpportunitiesRepository opportunities;
  final VoidCallback onBack;
  final VoidCallback onSessionExpired;
  @override
  State<CompanyOpportunitiesPage> createState() =>
      _CompanyOpportunitiesPageState();
}

class _CompanyOpportunitiesPageState extends State<CompanyOpportunitiesPage> {
  bool _sending = false;
  bool _expired = false;
  @override
  void initState() {
    super.initState();
    widget.techniciansController.addListener(_onTechniciansChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.techniciansController.load();
    });
  }

  void _onTechniciansChanged() {
    if (mounted && widget.techniciansController.sessionExpired && !_expired) {
      _handleExpired();
    }
  }

  void _handleExpired() {
    if (!mounted || _expired) return;
    _expired = true;
    widget.onSessionExpired();
  }

  @override
  void dispose() {
    widget.techniciansController.removeListener(_onTechniciansChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_sending,
      child: MobileFeatureShell(
          title: 'Oportunidades empresariales',
          onBack: () {
            if (!_sending) widget.onBack();
          },
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: CompanyOpportunitiesPanel(
                sessionKey: widget.sessionKey,
                techniciansController: widget.techniciansController,
                applications: widget.applications,
                opportunities: widget.opportunities,
                onSessionExpired: _handleExpired,
                onBusyChanged: (value) {
                  if (mounted) setState(() => _sending = value);
                },
              ))));
}
