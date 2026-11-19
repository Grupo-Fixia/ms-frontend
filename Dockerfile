# Usar imagen mantenida en Docker Hub
FROM instrumentisto/flutter:3.22.0 AS build
WORKDIR /app
RUN flutter config --no-analytics
COPY pubspec.* ./
RUN flutter pub get
COPY . .

# URL base de la API, fijada al compilar. Con el mismo origen que sirve Traefik (http://localhost)
# el navegador no necesita CORS. Para otro host: --build-arg USERS_API_BASE_URL=...
ARG USERS_API_BASE_URL=http://localhost
# Sin service worker (--pwa-strategy=none): si no, el navegador guarda una
# copia de la app y sigue mostrando la versión anterior después de cada
# despliegue hasta que se borre el caché a mano.
# APK de Android que ofrece la landing (GC-550); vacío, no se muestra el botón.
ARG ANDROID_APK_URL=https://github.com/Grupo-Fixia/ms-frontend/releases/latest/download/fixia.apk
RUN flutter build web --release --pwa-strategy=none \
    --dart-define=USERS_API_BASE_URL=${USERS_API_BASE_URL} \
    --dart-define=ANDROID_APK_URL=${ANDROID_APK_URL}

# Etapa Nginx
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]