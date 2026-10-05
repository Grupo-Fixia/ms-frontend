import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'core/theme/fixia_theme.dart';
import 'features/technician_registration/data/datasources/technician_registration_remote_data_source.dart';
import 'features/technician_registration/data/repositories/technician_registration_repository_impl.dart';
import 'features/technician_registration/domain/usecases/register_technician.dart';
import 'features/technician_registration/presentation/pages/technician_registration_page.dart';

const _usersApiBaseUrl = String.fromEnvironment(
  'USERS_API_BASE_URL',
  defaultValue: 'https://api.fixia.com',
);

void main() {
  final client = http.Client();
  final remoteDataSource = TechnicianRegistrationRemoteDataSource(
    client: client,
    baseUrl: Uri.parse(_usersApiBaseUrl),
  );
  final repository = TechnicianRegistrationRepositoryImpl(remoteDataSource);

  runApp(FixiaApp(registerTechnician: RegisterTechnician(repository)));
}

class FixiaApp extends StatelessWidget {
  const FixiaApp({super.key, required this.registerTechnician});

  final RegisterTechnician registerTechnician;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fixia - Registro de técnico',
      theme: FixiaTheme.light,
      home: TechnicianRegistrationPage(
        registerTechnician: registerTechnician,
      ),
    );
  }
}
