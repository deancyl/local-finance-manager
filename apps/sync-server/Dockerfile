# Build stage
FROM dart:stable AS build

WORKDIR /app

# Copy pubspec files
COPY pubspec.yaml ./
RUN dart pub get

# Copy source code
COPY . .

# Compile the server
RUN dart compile exe server.dart -o server

# Runtime stage
FROM debian:bookworm-slim

# Install required libraries
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy compiled server
COPY --from=build /app/server /app/server
COPY --from=build /app/.env /app/.env

# Expose port
EXPOSE 3000

# Run the server
CMD ["/app/server"]
