import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/auth/data/shared_preferences_session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferencesSessionStorage> _storage(
  Map<String, Object> initial,
) async {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferencesSessionStorage(await SharedPreferences.getInstance());
}

void main() {
  test('sin nada guardado devuelve null', () async {
    expect(await (await _storage({})).readRefreshToken(), isNull);
  });

  test('guarda y lee el refresh token', () async {
    final storage = await _storage({});

    await storage.saveRefreshToken('r1');

    expect(await storage.readRefreshToken(), 'r1');
  });

  test('guardar de nuevo reemplaza el token anterior (rotación)', () async {
    final storage = await _storage({});

    await storage.saveRefreshToken('r1');
    await storage.saveRefreshToken('r2');

    expect(await storage.readRefreshToken(), 'r2');
  });

  test('clear borra el token', () async {
    final storage = await _storage({});
    await storage.saveRefreshToken('r1');

    await storage.clear();

    expect(await storage.readRefreshToken(), isNull);
  });
}
