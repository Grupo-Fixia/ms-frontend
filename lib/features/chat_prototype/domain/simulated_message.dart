/// Quién «escribió» un mensaje del chat prototipo (GC-431).
enum SimulatedAuthor {
  /// La persona que usa la demo.
  you,

  /// Respuesta automática de la simulación; no hay otra persona al otro lado.
  simulation,
}

/// Mensaje del chat prototipo. Vive solo en memoria: no se envía, no se
/// guarda y no se relaciona con ninguna solicitud, cotización ni contrato.
class SimulatedMessage {
  const SimulatedMessage({required this.author, required this.text});

  final SimulatedAuthor author;
  final String text;
}
