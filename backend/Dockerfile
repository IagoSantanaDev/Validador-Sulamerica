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

# `debian:bookworm-slim` não traz nenhuma raiz de CA: sem este pacote o
# `HttpClient`/`Dio` não validam o certificado do portal e o TLS falha no
# handshake, o que o `login` reportava como "falha de rede". Verificado no
# registry: a imagem não possui `etc/ssl/certs` nem `ca-certificates`.
# O pacote também roda `update-ca-certificates`, que cria o bundle em
# `/etc/ssl/certs/ca-certificates.crt` — o caminho que o Dart procura.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /app/bin/server .
EXPOSE 8080
ENV HOST=0.0.0.0 \
    PORT=8080
CMD ["./server"]