FROM dart:stable AS build

# Install sqlite3
RUN apt-get update && apt-get install -y libsqlite3-dev && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy pubspec and get dependencies
COPY pubspec.yaml ./
RUN dart pub get

# Copy source code
COPY bin/ bin/
COPY lib/ lib/

# Compile to native executable
RUN dart compile exe bin/server.dart -o bin/server

# --- Runtime stage ---
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y libsqlite3-0 ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy compiled binary
COPY --from=build /app/bin/server /app/bin/server

# Copy public directory (Flutter web build, added during CI/build)
COPY public/ public/

EXPOSE 3000

CMD ["/app/bin/server"]
