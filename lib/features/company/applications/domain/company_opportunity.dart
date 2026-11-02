import '../../../technician/opportunities/domain/opportunity.dart';

class CompanyOpportunity {
  const CompanyOpportunity(
      {required this.request,
      required this.eligibleTechnicianIds,
      this.budgetAmount});
  final Opportunity request;
  final Set<String> eligibleTechnicianIds;
  final num? budgetAmount;
}

class CompanyOpportunityPage {
  const CompanyOpportunityPage({required this.items, this.nextCursor});
  final List<CompanyOpportunity> items;
  final String? nextCursor;
}
