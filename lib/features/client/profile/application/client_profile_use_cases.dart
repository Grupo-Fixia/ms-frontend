import '../domain/client_profile.dart';
import '../domain/client_profile_exceptions.dart';
import '../domain/client_profile_rules.dart';
import '../domain/client_profile_update.dart';
import 'ports/client_profile_repository.dart';

/// Caso de uso: consultar el perfil del cliente (GC-293).
class GetClientProfile {
  const GetClientProfile(this._repository);

  final ClientProfileRepository _repository;

  Future<ClientProfile> call() => _repository.fetchProfile();
}

/// Caso de uso: actualizar nombre, apellido y teléfono del cliente (GC-293).
///
/// Valida con las mismas reglas de la pantalla (`ClientProfileRules`, que
/// replican las de ms-users) y envía los textos sin espacios sobrantes.
class UpdateClientProfile {
  const UpdateClientProfile(this._repository);

  static const invalidDataMessage = 'Revisa los datos marcados.';

  final ClientProfileRepository _repository;

  Future<ClientProfile> call(ClientProfileUpdate update) async {
    final errors = <String, String>{
      if (ClientProfileRules.name(update.firstName, label: 'nombre')
          case final error?)
        'firstName': error,
      if (ClientProfileRules.name(update.lastName, label: 'apellido')
          case final error?)
        'lastName': error,
      if (ClientProfileRules.phone(update.phone) case final error?)
        'phone': error,
    };
    if (errors.isNotEmpty) {
      throw ClientProfileFailure(invalidDataMessage, fieldErrors: errors);
    }
    return _repository.updateProfile(
      ClientProfileUpdate(
        firstName: update.firstName.trim(),
        lastName: update.lastName.trim(),
        phone: update.phone.trim(),
      ),
    );
  }
}
