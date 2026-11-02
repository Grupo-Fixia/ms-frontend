import 'package:ms_frontend/features/company/technicians/application/company_use_cases.dart';
import 'package:ms_frontend/features/company/technicians/application/ports/company_repository.dart';
import 'package:ms_frontend/features/company/technicians/domain/associated_technician.dart';
import 'package:ms_frontend/features/company/technicians/domain/company_account.dart';
import 'package:ms_frontend/features/company/technicians/presentation/company_technicians_controller.dart';

CompanyTechniciansController controllerFor(
        Future<List<AssociatedTechnician>> Function() load) =>
    CompanyTechniciansController(
        ListCompanyTechnicians(_CallbackRepository(load)));

class _CallbackRepository implements CompanyRepository {
  _CallbackRepository(this.load);
  final Future<List<AssociatedTechnician>> Function() load;
  @override
  Future<List<AssociatedTechnician>> listTechnicians() => load();
  @override
  Future<CompanyAccount> getMine() => throw UnimplementedError();
}
