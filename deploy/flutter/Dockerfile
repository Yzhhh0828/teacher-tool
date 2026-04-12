FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
RUN curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.0-stable.tar.xz | tar xJ -C /opt
ENV PATH="/opt/flutter/bin:$PATH"

# Set working directory
WORKDIR /app

# Copy pubspec and download dependencies
COPY pubspec.yaml .
RUN flutter pub get

# Copy source and build
COPY lib/ ./lib/
RUN flutter build web --release

# Use nginx to serve
FROM nginx:alpine
COPY --from=0 /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
