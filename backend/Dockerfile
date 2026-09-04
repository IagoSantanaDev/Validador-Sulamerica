# Etapa de build: compila o Dart para executável nativo enxuto
FROM dart:stable AS build
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get
COPY . .
RUN dart compile exe bin/server.dart -o bin/server

# Etapa final: imagem de runtime só com o binário
FROM debian:bookworm-slim
WORKDIR /app
COPY --from=build /app/bin/server .
EXPOSE 8080
ENV HOST=0.0.0.0 \
    PORT=8080
CMD ["./server"]