import '../../../technician/applications/domain/service_application.dart';

import '../domain/company_opportunity.dart';

abstract interface class CompanyOpportunitiesRepository {
  Future<CompanyOpportunityPage> fetchPage(
      {required int limit, String? cursor});
}

abstract interface class CompanyApplicationRepository {
  Future<ServiceApplication> applyCompany(String requestId,
      {required String technicianUserId, required ProposedPrice price});
  Future<List<ServiceApplication>> listMine();
  Future<ServiceApplication> getMine(String id);
}

String? validateCompanyPrice(String? input) {
  final error = ProposedPrice.validate(input);
  if (error != null) return error;
  if (ProposedPrice.tryParse(input!)!.amount.split('.').first.length > 10) {
    return 'El precio propuesto admite máximo 10 dígitos enteros.';
  }
  return null;
}
