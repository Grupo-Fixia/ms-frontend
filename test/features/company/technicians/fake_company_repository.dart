import 'dart:async';

import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/features/company/technicians/application/ports/company_repository.dart';
import 'package:ms_frontend/features/company/technicians/domain/associated_technician.dart';
import 'package:ms_frontend/features/company/technicians/domain/company_account.dart';
import 'package:ms_frontend/features/company/technicians/domain/company_exceptions.dart';

const fixtureCompany = CompanyAccount(
  id: 'c0a00000-0000-4000-8000-000000000001',
  name: 'Servicios Integrales Andina',
  nit: '900123456-7',
);

const fixtureTechnicians = [
  AssociatedTechnician(
    userId: '7ec00000-0000-4000-8000-000000000001',
    displayName: 'Carlos G.',
    verificationStatus: VerificationStatus.valid,
    categories: [ServiceCategory.plumbing, ServiceCategory.electrical],
    yearsOfExperience: 6,
    city: 'Bogotá',
  ),
  AssociatedTechnician(
    userId: '7ec00000-0000-4000-8000-000000000002',
    displayName: 'Diana M.',
    verificationStatus: VerificationStatus.pending,
  ),
];

/// Repositorio de prueba: devuelve lo configurado, puede fallar o demorarse.
class FakeCompanyRepository implements CompanyRepository {
  FakeCompanyRepository({
    this.company = fixtureCompany,
    this.technicians = fixtureTechnicians,
    this.failure,
    this.pending,
  });

  CompanyAccount company;
  List<AssociatedTechnician> technicians;
  CompanyFailure? failure;
  Completer<void>? pending;

  int companyCalls = 0;
  int techniciansCalls = 0;

  @override
  Future<CompanyAccount> getMine() async {
    companyCalls++;
    await pending?.future;
    if (failure != null) throw failure!;
    return company;
  }

  @override
  Future<List<AssociatedTechnician>> listTechnicians() async {
    techniciansCalls++;
    await pending?.future;
    if (failure != null) throw failure!;
    return technicians;
  }
}
