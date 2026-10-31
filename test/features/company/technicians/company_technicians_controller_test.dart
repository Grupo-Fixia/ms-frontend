import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/company/technicians/application/company_use_cases.dart';
import 'package:ms_frontend/features/company/technicians/domain/company_exceptions.dart';
import 'package:ms_frontend/features/company/technicians/presentation/company_technicians_controller.dart';

import 'fake_company_repository.dart';

CompanyTechniciansController _controller(FakeCompanyRepository repository) =>
    CompanyTechniciansController(ListCompanyTechnicians(repository));

void main() {
  test('arranca sin consultar hasta que se pide', () {
    final repository = FakeCompanyRepository();
    final controller = _controller(repository);

    expect(controller.status, CompanyTechniciansStatus.idle);
    expect(controller.technicians, isEmpty);
    expect(repository.techniciansCalls, 0);
  });

  test('carga los técnicos reales y avisa a quien escucha', () async {
    final repository = FakeCompanyRepository();
    final controller = _controller(repository);
    final statuses = <CompanyTechniciansStatus>[];
    controller.addListener(() => statuses.add(controller.status));

    await controller.load();

    expect(statuses, [
      CompanyTechniciansStatus.loading,
      CompanyTechniciansStatus.ready,
    ]);
    expect(controller.technicians, fixtureTechnicians);
    expect(controller.errorMessage, isNull);
  });

  test('un error del backend queda con su mensaje', () async {
    final repository = FakeCompanyRepository(
        failure: const CompanyFailure('Esta sección es solo para empresas.'));
    final controller = _controller(repository);

    await controller.load();

    expect(controller.status, CompanyTechniciansStatus.failure);
    expect(controller.errorMessage, 'Esta sección es solo para empresas.');
    expect(controller.sessionExpired, isFalse);
  });

  test('marca la sesión vencida', () async {
    final repository = FakeCompanyRepository(
        failure: const CompanyFailure('vencida', isSessionExpired: true));
    final controller = _controller(repository);

    await controller.load();

    expect(controller.sessionExpired, isTrue);
  });

  test('un error inesperado se muestra con un mensaje genérico', () async {
    final controller = CompanyTechniciansController(
        _ThrowingList(StateError('inesperado')));

    await controller.load();

    expect(controller.status, CompanyTechniciansStatus.failure);
    expect(controller.errorMessage,
        CompanyTechniciansController.unexpectedErrorMessage);
  });

  test('reintentar después de un error recupera la lista', () async {
    final repository =
        FakeCompanyRepository(failure: const CompanyFailure('sin red'));
    final controller = _controller(repository);
    await controller.load();

    repository.failure = null;
    await controller.load();

    expect(controller.status, CompanyTechniciansStatus.ready);
    expect(controller.technicians, hasLength(2));
    expect(controller.errorMessage, isNull);
  });

  test('la respuesta de una consulta anterior no pisa la más reciente',
      () async {
    final slow = Completer<void>();
    final repository = FakeCompanyRepository(pending: slow);
    final controller = _controller(repository);
    // La primera consulta queda esperando con la lista completa.
    final first = controller.load();

    repository
      ..technicians = [fixtureTechnicians.last]
      ..pending = null;
    await controller.load();
    expect(controller.technicians, [fixtureTechnicians.last]);

    // La primera consulta termina tarde: se descarta.
    slow.complete();
    await first;
    expect(controller.technicians, [fixtureTechnicians.last]);
    expect(controller.status, CompanyTechniciansStatus.ready);
  });

  test('eligibleFor filtra por los ids de la oportunidad, en orden de la empresa',
      () async {
    final controller = _controller(FakeCompanyRepository());
    await controller.load();

    final eligible = controller.eligibleFor([
      fixtureTechnicians.last.userId,
      'id-de-otra-empresa',
      fixtureTechnicians.first.userId,
    ]);

    expect(eligible, fixtureTechnicians);
    expect(controller.eligibleFor(const []), isEmpty);
  });

  test('byId encuentra al técnico o devuelve null', () async {
    final controller = _controller(FakeCompanyRepository());
    await controller.load();

    expect(controller.byId(fixtureTechnicians.first.userId),
        fixtureTechnicians.first);
    expect(controller.byId('otro'), isNull);
  });

  test('GetMyCompany devuelve la empresa del repositorio', () async {
    final repository = FakeCompanyRepository();

    expect(await GetMyCompany(repository)(), fixtureCompany);
    expect(repository.companyCalls, 1);
  });
}

/// Caso de uso que falla con un error que no es `CompanyFailure`.
class _ThrowingList implements ListCompanyTechnicians {
  _ThrowingList(this.error);

  final Object error;

  @override
  Future<Never> call() async => throw error;
}
