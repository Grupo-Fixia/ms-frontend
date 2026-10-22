import 'key_value_store.dart';

/// Fuera del navegador no hay `sessionStorage`: la sesión vive en memoria.
KeyValueStore tabKeyValueStore() => InMemoryKeyValueStore();

/// Fuera del navegador no hay `localStorage`: la sesión vive en memoria.
ListableKeyValueStore persistentKeyValueStore() => InMemoryKeyValueStore();

/// Fuera del navegador no hay cookies: la sesión vive en memoria.
KeyValueStore browserSessionKeyValueStore() => InMemoryKeyValueStore();

/// Fuera del navegador no hay otras pestañas.
Stream<void> sharedSessionChanges(String sessionIdKey) => const Stream.empty();

/// Fuera del navegador las pestañas no se cierran.
void onTabClosed(void Function() closed, void Function() reopened) {}
