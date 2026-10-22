/// Almacén clave-valor síncrono, como `sessionStorage` y `localStorage`.
abstract interface class KeyValueStore {
  String? read(String key);

  void write(String key, String value);

  void remove(String key);
}

/// Almacén en memoria: se usa fuera del navegador (pruebas) y como respaldo.
class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _values = {};

  @override
  String? read(String key) => _values[key];

  @override
  void write(String key, String value) => _values[key] = value;

  @override
  void remove(String key) => _values.remove(key);
}
