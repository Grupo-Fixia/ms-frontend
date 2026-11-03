/// Sentido de una evaluación (GC-444).
enum EvaluationDirection {
  clientToProvider('CLIENT_TO_PROVIDER'),
  providerToClient('PROVIDER_TO_CLIENT');

  const EvaluationDirection(this.apiValue);

  final String apiValue;

  static EvaluationDirection? fromApi(String? value) {
    for (final direction in values) {
      if (direction.apiValue == value) return direction;
    }
    return null;
  }
}

/// Evaluación de un servicio cerrado, tal como la guarda ms-users (GC-444).
/// El historial solo la muestra cuando existe: nunca se rellena una ausente.
class ServiceEvaluation {
  const ServiceEvaluation({
    required this.serviceRequestId,
    required this.direction,
    required this.evaluatorId,
    required this.evaluatedId,
    required this.rating,
    this.comment,
    this.createdAt,
  });

  final String serviceRequestId;
  final EvaluationDirection direction;
  final String evaluatorId;
  final String evaluatedId;

  /// De 1 a 5 estrellas.
  final int rating;

  /// Solo lo ven el evaluador y el evaluado.
  final String? comment;
  final DateTime? createdAt;

  /// ¿La escribió [userId]?
  bool isBy(String userId) => evaluatorId == userId;

  /// ¿La recibió [userId]?
  bool isFor(String userId) => evaluatedId == userId;
}

/// Calificación que alguien quiere registrar (GC-445). Quién evalúa, a quién
/// y en qué sentido los decide ms-users con el token y la participación en
/// el servicio; aquí solo van el servicio, la nota y el comentario.
class NewServiceEvaluation {
  NewServiceEvaluation({
    required this.serviceRequestId,
    required this.rating,
    String? comment,
  }) : comment = _normalize(comment) {
    if (rating < minRating || rating > maxRating) {
      throw ArgumentError.value(rating, 'rating', 'Debe ir de 1 a 5');
    }
    if ((this.comment?.length ?? 0) > maxCommentLength) {
      throw ArgumentError.value(
          comment, 'comment', 'Admite hasta $maxCommentLength caracteres');
    }
  }

  static const minRating = 1;
  static const maxRating = 5;

  /// Límite de ms-users (columna `comment VARCHAR(500)`).
  static const maxCommentLength = 500;

  final String serviceRequestId;
  final int rating;

  /// Sin espacios a los lados; `null` si queda vacío, como lo guarda
  /// ms-users.
  final String? comment;

  static String? _normalize(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
