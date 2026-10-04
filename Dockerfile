# Usar imagen mantenida en Docker Hub
FROM instrumentisto/flutter:3.22.0 AS build

WORKDIR /app

RUN flutter config --no-analytics

COPY pubspec.* ./
RUN flutter pub get

COPY . .
RUN flutter build web --release

# Etapa Nginx (sin cambios)
FROM nginx:alpine
#COPY --from=build /app/build/web /usr/share/nginx/html
#COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]