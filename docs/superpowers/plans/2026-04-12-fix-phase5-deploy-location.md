# Phase 5 部署配置修复计划

**Goal:** 修复部署文件位置和缺失的配置

**Architecture:** 将部署文件从 `backend/deploy/` 移动到项目根目录 `deploy/`

---

## 问题

1. 部署文件在 `backend/deploy/` 而不是 `deploy/`
2. `docker-compose.yml` 缺少 `flutter` 服务
3. `flutter/Dockerfile` 引用不存在的 `nginx.conf`
4. 需要更新 docker-compose.yml 的 context 路径

---

## Task 1: 创建正确的部署目录结构

**Files:**
- Create: `deploy/` directory structure

- [ ] **Step 1: Create deploy directory structure**

```bash
mkdir -p deploy/
mkdir -p deploy/backend
mkdir -p deploy/flutter
mkdir -p deploy/nginx/ssl
mkdir -p deploy/scripts
mkdir -p deploy/backup
```

- [ ] **Step 2: Copy backend/Dockerfile to deploy/backend/Dockerfile**

Already exists at `backend/deploy/backend/Dockerfile`, need to move it.

---

## Task 2: 修复 docker-compose.yml

**Files:**
- Modify: `deploy/docker-compose.yml`

- [ ] **Step 1: Write corrected docker-compose.yml with flutter service**

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-teacher_tool}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-change_me_in_production}
      POSTGRES_DB: ${POSTGRES_DB:-teacher_tool}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - backend
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    networks:
      - backend
    restart: unless-stopped

  minio:
    image: minio/minio
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_ACCESS_KEY:-minioadmin}
      MINIO_ROOT_PASSWORD: ${MINIO_SECRET_KEY:-change_me_in_production}
    volumes:
      - minio_data:/data
    networks:
      - backend
    restart: unless-stopped

  backend:
    build:
      context: ../backend
      dockerfile: Dockerfile
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - REDIS_URL=${REDIS_URL}
      - JWT_SECRET_KEY=${JWT_SECRET_KEY}
      - JWT_ALGORITHM=${JWT_ALGORITHM:-HS256}
      - ACCESS_TOKEN_EXPIRE_MINUTES=${ACCESS_TOKEN_EXPIRE_MINUTES:-60}
      - REFRESH_TOKEN_EXPIRE_DAYS=${REFRESH_TOKEN_EXPIRE_DAYS:-7}
      - LLM_PROVIDER=${LLM_PROVIDER}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - OPENAI_BASE_URL=${OPENAI_BASE_URL}
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
      - ANTHROPIC_BASE_URL=${ANTHROPIC_BASE_URL}
      - STORAGE_TYPE=${STORAGE_TYPE}
      - MINIO_ENDPOINT=${MINIO_ENDPOINT}
      - MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY}
      - MINIO_SECRET_KEY=${MINIO_SECRET_KEY}
      - MINIO_BUCKET=${MINIO_BUCKET}
    depends_on:
      - postgres
      - redis
      - minio
    networks:
      - backend
    restart: unless-stopped

  flutter:
    build:
      context: ../flutter_app
      dockerfile: ../deploy/flutter/Dockerfile
    depends_on:
      - backend
    networks:
      - backend
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "${NGINX_PORT:-80}:80"
      - "${NGINX_SSL_PORT:-443}:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - nginx_data:/var/log/nginx
    depends_on:
      - backend
      - flutter
    networks:
      - backend
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
  minio_data:
  nginx_data:

networks:
  backend:
    driver: bridge
```

- [ ] **Step 2: Commit**

```bash
git add deploy/docker-compose.yml
git commit -m "fix: add flutter service to docker-compose"
```

---

## Task 3: 修复 Flutter Dockerfile

**Files:**
- Modify: `deploy/flutter/Dockerfile`

- [ ] **Step 1: Write corrected Flutter Dockerfile**

```dockerfile
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
```

- [ ] **Step 2: Commit**

```bash
git add deploy/flutter/Dockerfile
git commit -m "fix: correct Flutter Dockerfile"
```

---

## Task 4: 移动现有部署文件到正确位置

**Files:**
- Move: `backend/deploy/*` → `deploy/`

- [ ] **Step 1: Move files to correct location**

```bash
mv deploy/backend/ deploy/
mv deploy/flutter/ deploy/
mv deploy/nginx/ deploy/
mv deploy/scripts/ deploy/
mv deploy/backup/ deploy/
mv deploy/.env.prod.example deploy/
mv deploy/README.md deploy/
mv deploy/docker-compose.prod.yml deploy/
mv deploy/docker-compose.dev.yml deploy/
```

- [ ] **Step 2: Remove old backend/deploy directory**

```bash
rm -rf backend/deploy
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "refactor: move deploy files to project root"
```

---

## 自检清单

- [ ] `deploy/` 目录在项目根目录
- [ ] `deploy/docker-compose.yml` 包含 flutter 服务
- [ ] `deploy/flutter/Dockerfile` 正确（不引用不存在的 nginx.conf）
- [ ] `backend/deploy/` 目录已删除
