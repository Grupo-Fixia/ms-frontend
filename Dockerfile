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
RUN flutter build web --release --dart-define=USERS_API_BASE_URL=${USERS_API_BASE_URL}

# Etapa Nginx
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]