# Phase 5: 生产部署

**目标:** 完成生产环境部署配置

**Sub-plan for:** [主计划](./2026-04-12-teacher-tool-master-plan.md)

**Prerequisite:** Phase 1-4 完成

**Status:** 🚧 进行中

---

## 文件结构

```
deploy/
├── docker-compose.yml           # 主配置
├── docker-compose.dev.yml       # 开发环境
├── docker-compose.prod.yml      # 生产环境
├── docker-compose.yml           # 基础服务
├── nginx/
│   ├── nginx.conf
│   └── ssl/                     # SSL 证书
├── backend/
│   ├── Dockerfile
│   └── ...
├── backup/
│   └── backup.sh
└── scripts/
    ├── init-db.sh
    └── migrate.sh
```

---

## Task 1: Docker Compose 生产配置

**Files:**
- Create: `deploy/docker-compose.yml`
- Create: `deploy/docker-compose.prod.yml`

- [ ] **Step 1: Create deploy/docker-compose.yml**

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

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - nginx_data:/var/log/nginx
    depends_on:
      - backend
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

- [ ] **Step 2: Create deploy/docker-compose.prod.yml**

```yaml
version: '3.8'

# Override for production
# Usage: docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

services:
  postgres:
    restart: always
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U teacher_tool"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    restart: always

  minio:
    restart: always

  backend:
    restart: always
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 512M

  nginx:
    restart: always
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: add Docker Compose production config"
```

---

## Task 2: Backend Dockerfile

**Files:**
- Create: `deploy/backend/Dockerfile`

- [ ] **Step 1: Create deploy/backend/Dockerfile**

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY app/ ./app/
COPY run.py .

# Create non-root user
RUN useradd -m appuser && chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

- [ ] **Step 2: Update backend/app/main.py with health check**

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Teacher Tool API")

# Add health endpoint
@app.get("/health")
async def health_check():
    return {"status": "healthy"}


@app.on_event("startup")
async def startup():
    from app.database import init_db
    await init_db()
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: add Backend Dockerfile and health check"
```

---

## Task 3: Nginx 配置

**Files:**
- Create: `deploy/nginx/nginx.conf`

- [ ] **Step 1: Create deploy/nginx/nginx.conf**

```nginx
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;

    # Performance
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

    upstream backend {
        server backend:8000;
        keepalive 32;
    }

    server {
        listen 80;
        server_name localhost;

        # Redirect to HTTPS (uncomment when SSL is configured)
        # return 301 https://$server_name$request_uri;

        # For development/testing without SSL
        location / {
            root /usr/share/nginx/html;
            index index.html;
            try_files $uri $uri/ /index.html;
        }

        location /api {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://backend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
            proxy_read_timeout 300s;
            proxy_connect_timeout 75s;
        }

        location /ws {
            proxy_pass http://backend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_read_timeout 86400;
        }

        # SSE endpoint
        location /api/v1/agent/chat {
            proxy_pass http://backend;
            proxy_http_version 1.1;
            proxy_set_header Connection '';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            chunked_transfer_encoding on;
            proxy_cache off;
        }
    }

    # HTTPS server (uncomment when SSL is configured)
    # server {
    #     listen 443 ssl http2;
    #     server_name localhost;
    #
    #     ssl_certificate /etc/nginx/ssl/cert.pem;
    #     ssl_certificate_key /etc/nginx/ssl/key.pem;
    #     ssl_session_timeout 1d;
    #     ssl_session_cache shared:SSL:50m;
    #     ssl_session_tickets off;
    #
    #     ssl_protocols TLSv1.2 TLSv1.3;
    #     ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    #     ssl_prefer_server_ciphers off;
    #
    #     add_header Strict-Transport-Security "max-age=63072000" always;
    #
    #     location / {
    #         root /usr/share/nginx/html;
    #         try_files $uri $uri/ /index.html;
    #     }
    #
    #     location /api {
    #         proxy_pass http://backend;
    #         # ... same as above
    #     }
    # }
}
```

- [ ] **Step 2: Commit**

```bash
git add -A && git commit -m "feat: add Nginx configuration"
```

---

## Task 4: 环境变量与部署脚本

**Files:**
- Create: `deploy/.env.prod.example`
- Create: `deploy/scripts/init-db.sh`
- Create: `deploy/scripts/migrate.sh`
- Create: `deploy/backup/backup.sh`

- [ ] **Step 1: Create deploy/.env.prod.example**

```bash
# Database
POSTGRES_USER=teacher_tool
POSTGRES_PASSWORD=change_me_in_production_strong_password
POSTGRES_DB=teacher_tool
DATABASE_URL=postgresql+asyncpg://teacher_tool:change_me_in_production_strong_password@postgres:5432/teacher_tool

# Redis
REDIS_URL=redis://redis:6379/0

# JWT (generate with: openssl rand -hex 32)
JWT_SECRET_KEY=change_me_generate_with_openssl_rand_hex_32
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60
REFRESH_TOKEN_EXPIRE_DAYS=7

# LLM Provider (openai or anthropic)
LLM_PROVIDER=openai
OPENAI_API_KEY=your-api-key-here
OPENAI_BASE_URL=https://api.openai.com/v1
ANTHROPIC_API_KEY=your-api-key-here
ANTHROPIC_BASE_URL=https://api.anthropic.com

# Storage
STORAGE_TYPE=minio
MINIO_ENDPOINT=minio:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=change_me_in_production
MINIO_BUCKET=teacher-tool

# Nginx
NGINX_PORT=80
NGINX_SSL_PORT=443
```

- [ ] **Step 2: Create deploy/scripts/init-db.sh**

```bash
#!/bin/bash
set -e

echo "Waiting for PostgreSQL to be ready..."
until PGPASSWORD=$POSTGRES_PASSWORD psql -h postgres -U $POSTGRES_USER -d $POSTGRES_DB -c '\q' 2>/dev/null; do
    echo "PostgreSQL is unavailable - sleeping"
    sleep 1
done

echo "PostgreSQL is up - running migrations"

cd /app
python -c "from app.database import init_db; import asyncio; asyncio.run(init_db())"

echo "Database initialized successfully"
```

- [ ] **Step 3: Create deploy/scripts/migrate.sh**

```bash
#!/bin/bash
set -e

echo "Running database migrations..."

cd /app

# Install alembic if needed
pip install alembic

# Run migrations
alembic upgrade head

echo "Migrations completed"
```

- [ ] **Step 4: Create deploy/backup/backup.sh**

```bash
#!/bin/bash
set -e

BACKUP_DIR=/backups
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE=${BACKUP_DIR}/backup_${DATE}.sql

mkdir -p $BACKUP_DIR

echo "Starting backup..."

# Backup PostgreSQL
PGPASSWORD=$POSTGRES_PASSWORD pg_dump -h postgres -U $POSTGRES_USER $POSTGRES_DB > $BACKUP_FILE

# Compress
gzip $BACKUP_FILE

# Keep only last 7 days
find $BACKUP_DIR -name "backup_*.sql.gz" -mtime +7 -delete

echo "Backup completed: ${BACKUP_FILE}.gz"
```

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add deployment scripts and environment template"
```

---

## Task 5: Flutter Web 构建配置

**Files:**
- Create: `deploy/flutter/Dockerfile`

- [ ] **Step 1: Create deploy/flutter/Dockerfile**

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
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

- [ ] **Step 2: Commit**

```bash
git add -A && git commit -m "feat: add Flutter web Docker build"
```

---

## Task 6: 部署文档

**Files:**
- Create: `deploy/README.md`

- [ ] **Step 1: Create deploy/README.md**

```markdown
# 教师工具部署指南

## 快速开始

### 1. 环境准备

- Docker 20.10+
- Docker Compose 2.0+

### 2. 配置环境变量

```bash
cd deploy
cp .env.prod.example .env
# 编辑 .env 文件，填入实际值
```

### 3. 启动服务

```bash
# 开发环境
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# 生产环境
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### 4. 初始化数据库

```bash
docker-compose exec backend python -c "from app.database import init_db; import asyncio; asyncio.run(init_db())"
```

## 服务访问

- API: http://localhost/api/v1
- MinIO Console: http://localhost:9001 (minioadmin/minioadmin)
- PostgreSQL: localhost:5432

## 备份

```bash
# 手动备份
./backup/backup.sh

# 自动备份 (添加 cron)
0 2 * * * /path/to/backup/backup.sh
```

## 更新部署

```bash
docker-compose pull
docker-compose up -d --force-recreate backend
```

## 停止服务

```bash
docker-compose down
```

## 扩展

### 添加 HTTPS

1. 获取 SSL 证书
2. 将证书放入 `nginx/ssl/` 目录
3. 取消 nginx.conf 中 HTTPS server 的注释
4. 重启 nginx: `docker-compose restart nginx`
```

- [ ] **Step 2: Commit**

```bash
git add -A && git commit -m "docs: add deployment README"
```

---

## 自检清单

- [ ] Docker Compose 配置可正常启动
- [ ] PostgreSQL, Redis, MinIO 正常运行
- [ ] Backend 可访问
- [ ] Nginx 反向代理配置正确
- [ ] 数据库备份脚本可用
- [ ] 部署文档完整
