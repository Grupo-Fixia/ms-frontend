# ms-frontend
## APK de Android (GC-550)

La misma app compila para Android (`android/`, paquete `co.fixia.app`).

- **Publicar:** en GitHub → Actions → *android-apk* → *Run workflow* (URL de
  la API y versión). Sube `fixia.apk` y su SHA-256 a un Release; el enlace
  estable es
  `https://github.com/Grupo-Fixia/ms-frontend/releases/latest/download/fixia.apk`.
- **En la landing:** el botón «Descargar para Android» aparece si la web se
  compila con `--dart-define=ANDROID_APK_URL=<ese enlace>`.
- **Local:** `flutter build apk --release --dart-define=USERS_API_BASE_URL=http://10.43.98.211`
  (Java 17 o 21; el APK queda en `build/app/outputs/flutter-apk/`).
- **Firma:** sin `android/key.properties` se firma con la clave de depuración
  (sirve para QA). Para la llave del equipo, crear el `.jks` con `keytool` y
  cargarlo en los secretos `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
  `ANDROID_KEY_ALIAS` y `ANDROID_KEY_PASSWORD`. Nunca se sube al repositorio.
- **HTTP:** QA no tiene HTTPS (GC-499), así que la app permite tráfico sin
  cifrar (`android/app/src/main/res/values/config.xml`). Con HTTPS, ponerlo en
  `false`.
- **Sesión en Android:** con «Mantener sesión iniciada» la sesión se guarda
  en el dispositivo y sobrevive a cerrar la app; sin esa opción, cerrar la app
  cierra la sesión (como cerrar el navegador).
- **Evidencias en Android:** se suben con el selector de archivos del sistema
  (JPG, PNG, WEBP o PDF). Descargarlas sigue siendo solo en la web.
- **Landing:** el `Dockerfile` compila la web con `ANDROID_APK_URL` apuntando
  al último Release, así aparece el botón «Descargar para Android».
