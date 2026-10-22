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
# Flujo postulacion/cotizacion con datos locales mientras no haya solicitudes reales:
# USE_MOCK_APPLICATIONS=true usa postulaciones simuladas (sin ms-services);
# DEV_FLOW_SANDBOX=true abre al iniciar la pantalla del flujo E2E (/dev/flujo-e2e).
ARG USE_MOCK_APPLICATIONS=true
ARG DEV_FLOW_SANDBOX=false
RUN flutter build web --release \
    --dart-define=USERS_API_BASE_URL=${USERS_API_BASE_URL} \
    --dart-define=USE_MOCK_APPLICATIONS=${USE_MOCK_APPLICATIONS} \
    --dart-define=DEV_FLOW_SANDBOX=${DEV_FLOW_SANDBOX}

# Etapa Nginx
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]