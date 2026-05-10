# 教师工具部署指南

## 快速开始

### 1. 环境准备

- Docker 20.10+
- Docker Compose 2.0+

### 2. 配置环境变量

```bash
cd deploy
cp .env.example .env
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

### 5. 本地验证

```bash
# 在仓库根目录执行后端测试
python -m pytest backend/tests

# Flutter 端需要先安装 Flutter SDK，再在 flutter_app 目录执行
flutter pub get
flutter analyze
flutter test
```

注意：后端当 `DEBUG=false` 或 `APP_ENV=production` 时会启用严格环境校验，此时必须显式配置安全的 `JWT_SECRET_KEY`、受限的 `BACKEND_CORS_ORIGINS`，并关闭 `EXPOSE_DEBUG_VERIFICATION_CODE`。

如果 Flutter 端连接的后端地址不是默认的 `http://localhost:8000/api/v1`，请在启动时追加：

```bash
flutter run --dart-define=API_BASE_URL=http://<your-host>:8000/api/v1
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

1. 获取 SSL 证书（推荐 Let's Encrypt / certbot）
2. 将证书放入 `nginx/ssl/` 目录：
   - `nginx/ssl/cert.pem` — 证书链
   - `nginx/ssl/key.pem` — 私钥
3. 编辑 `nginx/nginx.conf`：
   - 在 HTTP server 块中取消 `return 301 https://...` 的注释
   - 取消 HTTPS server 块的注释
   - 将 `server_name` 替换为实际域名
4. 重启 nginx: `docker-compose restart nginx`

### 数据库迁移

```bash
# 应用所有待迁移
docker-compose exec backend alembic upgrade head

# 查看当前版本
docker-compose exec backend alembic current

# 生成新迁移（开发时使用）
docker-compose exec backend alembic revision --autogenerate -m "description"
```

### 数据库恢复

```bash
# 从备份恢复 PostgreSQL
docker-compose exec -T postgres psql -U teacher_tool -d teacher_tool < backup_file.sql
```
