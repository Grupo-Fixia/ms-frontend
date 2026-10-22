import 'key_value_store.dart';

/// Fuera del navegador no hay `sessionStorage`: la sesión vive en memoria.
KeyValueStore tabKeyValueStore() => InMemoryKeyValueStore();

/// Fuera del navegador no hay `localStorage`: la sesión vive en memoria.
KeyValueStore persistentKeyValueStore() => InMemoryKeyValueStore();
