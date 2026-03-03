# Build stage
FROM debian:latest AS build-env

# Install dependencies
RUN apt-get update && apt-get install -y curl git wget unzip xz-utils libglu1-mesa python3

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git -b stable /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Verify Flutter
RUN flutter doctor

WORKDIR /app

# Copy pubspec and get dependencies
COPY pubspec.yaml .
RUN flutter pub get

# Copy source and build for web
COPY . .
RUN flutter build web --release

# Production stage
FROM nginx:alpine

# Copy web build to nginx
COPY --from=build-env /app/build/web /usr/share/nginx/html

# Expose port 80
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
