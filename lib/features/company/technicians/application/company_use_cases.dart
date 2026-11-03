import '../domain/associated_technician.dart';
import '../domain/company_account.dart';
import 'ports/company_repository.dart';

/// Caso de uso: consultar la empresa del administrador autenticado (GC-467).
class GetMyCompany {
  const GetMyCompany(this._repository);

  final CompanyRepository _repository;

  Future<CompanyAccount> call() => _repository.getMine();
}

/// Caso de uso: listar los técnicos asociados a la empresa autenticada
/// (GC-467). Es la única fuente de técnicos de la empresa en el frontend: el
/// selector de la postulación empresarial (GC-469) la reutiliza.
class ListCompanyTechnicians {
  const ListCompanyTechnicians(this._repository);

  final CompanyRepository _repository;

  Future<List<AssociatedTechnician>> call() => _repository.listTechnicians();
}
