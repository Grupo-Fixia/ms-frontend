import 'service_request.dart';

/// Reglas para publicar una solicitud de servicio.
///
/// Replican las de `CreateServiceRequestRequest` en ms-services para que el
/// cliente vea el error antes de enviar. Las claves de los errores son los
/// mismos nombres de campo que usa el backend (`approximateLocation.city`).
abstract final class ServiceRequestRules {
  static const descriptionMaxLength = 2000;
  static const placeMaxLength = 100;
  static const addressMaxLength = 255;
  static const maxPhotos = 5;
  static const photoKeyMaxLength = 255;

  static final _photoKeyPattern =
      RegExp(r'^(?!.*\.\.)[A-Za-z0-9][A-Za-z0-9._/-]*$');

  /// Errores por campo; vacío si la solicitud es válida. [now] es el momento
  /// de la publicación (el servicio debe esperarse después).
  static Map<String, String> validate(
    NewServiceRequest request, {
    required DateTime now,
  }) {
    final errors = <String, String>{};

    if (request.category == null) {
      errors['category'] = 'Elige el tipo de servicio.';
    }

    final description = request.description.trim();
    if (description.isEmpty) {
      errors['description'] = 'Describe lo que necesitas.';
    } else if (description.length > descriptionMaxLength) {
      errors['description'] =
          'La descripción no puede superar $descriptionMaxLength caracteres.';
    }

    final approximate = request.approximateLocation;
    _requiredText(errors, 'approximateLocation.city', approximate.city,
        'Ingresa la ciudad.', 'La ciudad', placeMaxLength);
    _requiredText(errors, 'approximateLocation.zone', approximate.zone,
        'Ingresa el barrio o la zona.', 'La zona', placeMaxLength);
    _coordinates(errors, 'approximateLocation', approximate.latitude,
        approximate.longitude);

    final exact = request.exactLocation;
    if (exact != null) {
      _requiredText(errors, 'exactLocation.address', exact.address,
          'Ingresa la dirección.', 'La dirección', addressMaxLength);
      _coordinates(errors, 'exactLocation', exact.latitude, exact.longitude);
    }

    final expectedAt = request.expectedAt;
    if (expectedAt == null) {
      errors['expectedAt'] = 'Indica cuándo necesitas el servicio.';
    } else if (!expectedAt.isAfter(now)) {
      errors['expectedAt'] = 'Elige un momento posterior a ahora.';
    }

    if (request.photoKeys.length > maxPhotos) {
      errors['photoKeys'] = 'Puedes adjuntar máximo $maxPhotos fotografías.';
    } else if (request.photoKeys.any((key) =>
        key.length > photoKeyMaxLength || !_photoKeyPattern.hasMatch(key))) {
      errors['photoKeys'] = 'Hay una fotografía con un nombre no permitido.';
    }

    return errors;
  }

  static void _requiredText(
    Map<String, String> errors,
    String field,
    String value,
    String emptyMessage,
    String label,
    int maxLength,
  ) {
    final text = value.trim();
    if (text.isEmpty) {
      errors[field] = emptyMessage;
    } else if (text.length > maxLength) {
      errors[field] = '$label no puede superar $maxLength caracteres.';
    }
  }

  static void _coordinates(
    Map<String, String> errors,
    String prefix,
    double? latitude,
    double? longitude,
  ) {
    if (latitude == null && longitude == null) return;
    if (latitude == null || longitude == null) {
      errors['$prefix.coordinatesComplete'] =
          'La latitud y la longitud deben indicarse juntas.';
      return;
    }
    if (latitude.isNaN || latitude < -90 || latitude > 90) {
      errors['$prefix.latitude'] = 'La latitud debe estar entre -90 y 90.';
    }
    if (longitude.isNaN || longitude < -180 || longitude > 180) {
      errors['$prefix.longitude'] = 'La longitud debe estar entre -180 y 180.';
    }
  }
}
