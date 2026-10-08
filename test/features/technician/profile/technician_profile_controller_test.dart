import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/features/technician/profile/application/get_technician_profile.dart';
import 'package:ms_frontend/features/technician/profile/application/update_technician_profile.dart';
import 'package:ms_frontend/features/technician/profile/domain/technician_profile_exceptions.dart';
import 'package:ms_frontend/features/technician/profile/presentation/technician_profile_controller.dart';

import 'fake_repository.dart';
import 'fixtures.dart';

TechnicianProfileController _controller(
  FakeTechnicianProfileRepository repository,
) =>
    TechnicianProfileController(
      getProfile: GetTechnicianProfile(repository),
      updateProfile: UpdateTechnicianProfile(repository),
    );

void main() {
  test('carga el perfil; incompleto muestra el formulario', () async {
    final controller =
        _controller(FakeTechnicianProfileRepository(profile: emptyProfile));
    expect(controller.status, TechnicianProfileStatus.loading);

    await controller.load();

    expect(controller.status, TechnicianProfileStatus.ready);
    expect(controller.showForm, isTrue);
  });

  test('perfil completo muestra el resumen hasta que decida editar', () async {
    final controller = _controller(
      FakeTechnicianProfileRepository(profile: completeProfile()),
    );
    await controller.load();
    expect(controller.showForm, isFalse);

    controller.startEditing();
    expect(controller.showForm, isTrue);

    controller.cancelEditing();
    expect(controller.showForm, isFalse);
  });

  test('si no carga guarda el mensaje y se puede reintentar', () async {
    final repository = FakeTechnicianProfileRepository(
      profile: emptyProfile,
      fetchFailure: const TechnicianProfileFailure('Sin conexión'),
    );
    final controller = _controller(repository);

    await controller.load();
    expect(controller.status, TechnicianProfileStatus.loadError);
    expect(controller.loadErrorMessage, 'Sin conexión');

    repository.fetchFailure = null;
    await controller.load();
    expect(controller.status, TechnicianProfileStatus.ready);
    expect(repository.fetchCalls, 2);
  });

  test('un error inesperado al cargar muestra un mensaje genérico', () async {
    final controller = TechnicianProfileController(
      getProfile: GetTechnicianProfile(_ThrowingRepository()),
      updateProfile: UpdateTechnicianProfile(_ThrowingRepository()),
    );

    await controller.load();

    expect(
      controller.loadErrorMessage,
      TechnicianProfileController.unexpectedErrorMessage,
    );
  });

  test('guardar envía los datos y vuelve al resumen', () async {
    final repository = FakeTechnicianProfileRepository(profile: emptyProfile);
    final controller = _controller(repository);
    await controller.load();

    final saved = await controller.save(
      professionalDescription: '  Electricista residencial  ',
      yearsOfExperience: '7',
      categories: {ServiceCategory.electrical},
    );

    expect(saved, isTrue);
    expect(repository.lastUpdate?.professionalDescription,
        'Electricista residencial');
    expect(repository.lastUpdate?.yearsOfExperience, 7);
    expect(controller.justSaved, isTrue);
    expect(controller.showForm, isFalse);
  });

  test('errores del backend quedan por campo', () async {
    final controller = _controller(
      FakeTechnicianProfileRepository(
        profile: emptyProfile,
        updateFailure: const TechnicianProfileFailure(
          'Revisa los datos',
          fieldErrors: {'yearsOfExperience': 'No puede superar 80'},
        ),
      ),
    );
    await controller.load();

    final saved = await controller.save(
      professionalDescription: 'Pintor',
      yearsOfExperience: '5',
      categories: {ServiceCategory.painting},
    );

    expect(saved, isFalse);
    expect(controller.saveErrorMessage, 'Revisa los datos');
    expect(controller.fieldError('yearsOfExperience'), 'No puede superar 80');
    controller.clearFieldError('yearsOfExperience');
    expect(controller.fieldError('yearsOfExperience'), isNull);
    controller.dismissSaveError();
    expect(controller.saveErrorMessage, isNull);
  });

  test('marca la sesión vencida', () async {
    final controller = _controller(
      FakeTechnicianProfileRepository(
        profile: emptyProfile,
        fetchFailure: const TechnicianProfileFailure(
          'Tu sesión venció',
          isSessionExpired: true,
        ),
      ),
    );

    await controller.load();

    expect(controller.isSessionExpired, isTrue);
  });
}

class _ThrowingRepository extends FakeTechnicianProfileRepository {
  _ThrowingRepository() : super(profile: emptyProfile);

  @override
  Future<Never> fetchProfile() async => throw StateError('inesperado');
}
