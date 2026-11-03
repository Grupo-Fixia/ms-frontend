/// Ciudades que se ofrecen al publicar una solicitud y al configurar la zona
/// de atención del técnico. ms-users compara la ciudad del técnico con la de
/// la solicitud (sin tildes ni mayúsculas), así que las dos pantallas eligen
/// de la misma lista para que siempre coincidan.
abstract final class ColombianCities {
  static const all = [
    'Armenia',
    'Barranquilla',
    'Bello',
    'Bogotá',
    'Bucaramanga',
    'Cali',
    'Cartagena',
    'Chía',
    'Cúcuta',
    'Envigado',
    'Ibagué',
    'Itagüí',
    'Manizales',
    'Medellín',
    'Montería',
    'Neiva',
    'Palmira',
    'Pasto',
    'Pereira',
    'Popayán',
    'Santa Marta',
    'Sincelejo',
    'Soacha',
    'Soledad',
    'Tunja',
    'Valledupar',
    'Villavicencio',
    'Zipaquirá',
  ];

  /// La ciudad de la lista que corresponde a [value] (sin importar tildes,
  /// mayúsculas ni espacios), o `null` si no está.
  static String? match(String? value) {
    if (value == null) return null;
    final key = _normalize(value);
    for (final city in all) {
      if (_normalize(city) == key) return city;
    }
    return null;
  }

  static String _normalize(String value) {
    const from = 'áéíóúüñÁÉÍÓÚÜÑ';
    const to = 'aeiouunAEIOUUN';
    final buffer = StringBuffer();
    for (final rune in value.trim().runes) {
      final char = String.fromCharCode(rune);
      final i = from.indexOf(char);
      buffer.write(i >= 0 ? to[i] : char);
    }
    return buffer.toString().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
