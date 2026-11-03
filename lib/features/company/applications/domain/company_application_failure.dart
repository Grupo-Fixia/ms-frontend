import '../../../technician/applications/domain/application_exceptions.dart';

class CompanySubmissionUnconfirmed extends ApplicationFailure {
  const CompanySubmissionUnconfirmed()
      : super(
            'No pudimos confirmar la postulación empresarial. Consulta tus postulaciones antes de volver a enviar.');
}

class CompanyApplicationConflict extends ApplicationFailure {
  const CompanyApplicationConflict({String? id})
      : super(
            'Ya existe una postulación o la solicitud no recibe más propuestas. Consulta su estado antes de reintentar.',
            existingApplicationId: id);
}
