import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/features/technician/specialties/application/get_service_catalog.dart';
import 'package:ms_frontend/features/technician/specialties/application/get_technician_specialties.dart';
import 'package:ms_frontend/features/technician/specialties/application/ports/technician_specialties_repository.dart';
import 'package:ms_frontend/features/technician/specialties/application/update_technician_specialties.dart';
import 'package:ms_frontend/features/technician/specialties/domain/technician_specialties.dart';

class _FakeRepository implements TechnicianSpecialtiesRepository {
  Set<ServiceCategory> saved = {ServiceCategory.plumbing};
  Set<ServiceCategory>? lastUpdate;

  @override
  Future<List<ServiceCategoryOption>> fetchCatalog() async => const [
        ServiceCategoryOption(
          category: ServiceCategory.plumbing,
          name: 'Plomería',
        ),
      ];

  @override
  Future<TechnicianSpecialties> fetchSpecialties() async =>
      TechnicianSpecialties(categories: saved);

  @override
  Future<TechnicianSpecialties> updateSpecialties(
    Set<ServiceCategory> categories,
  ) async {
    lastUpdate = categories;
    saved = categories;
    return TechnicianSpecialties(categories: categories);
  }
}

void main() {
  test('consulta el catálogo', () async {
    final catalog = await GetServiceCatalog(_FakeRepository())();

    expect(catalog.single.name, 'Plomería');
  });

  test('consulta las especialidades del técnico', () async {
    final specialties = await GetTechnicianSpecialties(_FakeRepository())();

    expect(specialties.categories, {ServiceCategory.plumbing});
  });

  test('actualiza la selección sin compartir el conjunto del llamador',
      () async {
    final repository = _FakeRepository();
    final selection = {ServiceCategory.painting};

    final saved = await UpdateTechnicianSpecialties(repository)(selection);
    selection.add(ServiceCategory.carpentry);

    expect(saved.categories, {ServiceCategory.painting});
    expect(repository.lastUpdate, {ServiceCategory.painting});
    expect(() => repository.lastUpdate!.add(ServiceCategory.carpentry),
        throwsUnsupportedError);
  });
}
