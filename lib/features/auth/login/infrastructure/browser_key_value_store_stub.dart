import 'dart:io' show Platform;

import 'package:shared_preferences/shared_preferences.dart';

import 'key_value_store.dart';

SharedPreferences? _devicePreferences;

/// En Android carga las preferencias del dispositivo para que «Mantener sesión
/// iniciada» sobreviva a cerrar la app (GC-550). En pruebas y escritorio no
/// hace nada: la sesión vive en memoria.
Future<void> initPersistentStorage() async {
  if (!Platform.isAndroid) return;
  _devicePreferences = await SharedPreferences.getInstance();
}

/// Fuera del navegador no hay `sessionStorage`: dura lo que dura la app
/// abierta.
KeyValueStore tabKeyValueStore() => InMemoryKeyValueStore();

/// En Android, las preferencias del dispositivo (como `localStorage`); si no,
/// memoria.
ListableKeyValueStore persistentKeyValueStore() {
  final preferences = _devicePreferences;
  return preferences == null
      ? InMemoryKeyValueStore()
      : PreferencesKeyValueStore(preferences);
}

/// Fuera del navegador no hay cookies de sesión: duran lo que dura la app
/// abierta, así una sesión sin «Mantener sesión iniciada» se cierra al cerrar
/// la app, como al cerrar el navegador.
KeyValueStore browserSessionKeyValueStore() => InMemoryKeyValueStore();

/// Fuera del navegador no hay otras pestañas.
Stream<void> sharedSessionChanges(String sessionIdKey) => const Stream.empty();

/// Fuera del navegador las pestañas no se cierran.
void onTabClosed(void Function() closed, void Function() reopened) {}

/// Almacén síncrono sobre `SharedPreferences`: lee de la copia en memoria que
/// el plugin carga al iniciar y escribe en disco en segundo plano.
class PreferencesKeyValueStore implements ListableKeyValueStore {
  PreferencesKeyValueStore(this._preferences);

  final SharedPreferences _preferences;

  @override
  String? read(String key) => _preferences.getString(key);

  @override
  void write(String key, String value) => _preferences.setString(key, value);

  @override
  void remove(String key) => _preferences.remove(key);

  @override
  List<String> keysStartingWith(String prefix) =>
      _preferences.getKeys().where((key) => key.startsWith(prefix)).toList();
}
