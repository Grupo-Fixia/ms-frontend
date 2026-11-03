/// Respuestas simuladas del chat prototipo (GC-431).
///
/// Son textos genéricos y fijos: no nombran personas, servicios, precios ni
/// estados. Se entregan en orden y de forma cíclica, así la demo es
/// reproducible.
abstract final class SimulatedReplies {
  static const List<String> texts = [
    'Esta es una respuesta simulada. Tu mensaje no llegó a ninguna persona.',
    'Así se vería una respuesta dentro de Fixia. Aquí no hay nadie conectado.',
    'Simulación: la mensajería real todavía no está disponible.',
  ];

  /// Respuesta número [index] (empezando en 0), repitiendo el ciclo.
  static String at(int index) => texts[index % texts.length];
}
