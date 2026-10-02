FROM ghcr.io/cirrusci/flutter:3.22.0 AS build

WORKDIR /app

COPY . .

RUN flutter config --no-analytics

RUN flutter pub get

RUN flutter build web --release

FROM nginx:alpine

COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
