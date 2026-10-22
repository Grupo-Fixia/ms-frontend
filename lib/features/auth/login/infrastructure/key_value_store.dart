/// Almacén clave-valor síncrono, como `sessionStorage` y `localStorage`.
abstract interface class KeyValueStore {
  String? read(String key);

  void write(String key, String value);

  void remove(String key);
}

/// Almacén que además permite listar sus claves, como `localStorage`.
abstract interface class ListableKeyValueStore implements KeyValueStore {
  /// Las claves guardadas que empiezan por [prefix].
  List<String> keysStartingWith(String prefix);
}

/// Almacén en memoria: se usa fuera del navegador (pruebas) y como respaldo.
class InMemoryKeyValueStore implements ListableKeyValueStore {
  final Map<String, String> _values = {};

  @override
  List<String> keysStartingWith(String prefix) =>
      _values.keys.where((key) => key.startsWith(prefix)).toList();

  @override
  String? read(String key) => _values[key];

  @override
  void write(String key, String value) => _values[key] = value;

  @override
  void remove(String key) => _values.remove(key);
}
