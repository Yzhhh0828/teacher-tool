# 教师工具平台 (Teacher Tool)

这是一个专为现代教育场景设计的全栈工具平台，旨在帮助教师更高效地管理班级、学生、成绩、课程表以及进行课堂互动（配合 AI 助手），从而进一步提升生产力。

## 架构概览

- **前端平台**: Flutter (Android, iOS, Web, Desktop) - 采用基于 Riverpod 的状态管理，搭载极简美拉德绿设计风格 (Maillard Green Minimalist)。
- **后端架构**: Python 3.10+ / FastAPI - 支持高吞吐量的异步 API，结合 LangChain 实现的 AI Assistant (LangGraph)。
- **数据库组件**: PostgreSQL / AsyncPG / SQLAlchemy (ORM)。
- **缓存与状态**: Redis (可选，用于分布式锁与队列等)。

---

## 一、本地开发启动指南 (Local Development)

对于在本地直接进行代码开发的场景，我们推荐将前端后端分开独立运行，而不是通过 Docker 容器化所有组件，以便更好的热重载（HOT RELOAD）。

### 1.1 后端环境启动 (FastAPI)

后端服务代码位于 `backend/` 目录下。

1. **进入后端目录并配置虚拟环境**：
   ```bash
   cd backend
   python -m venv venv
   
   # Windows 激活虚拟环境:
   .\venv\Scripts\activate
   # macOS/Linux 激活虚拟环境:
   source venv/bin/activate
   ```

2. **安装依赖**：
   ```bash
   pip install -r requirements.txt
   ```

3. **环境变量配置**：
   复制环境变量模板并根据本地库（比如本地起的 Postgres 等）进行适配。如果您本地没有数据库，您可以依赖 Docker Compose 仅启动 DB（参考后文的“容器辅助”）。
   ```bash
   cp .env.example .env
   ```

4. **初始化数据库结构 (Alembic)**：
   如果是首次运行，需要对数据库应用表结构迁移：
   ```bash
   alembic upgrade head
   ```

5. **启动后端服务**：
   ```bash
   python run.py
   ```
   *服务成功启动后将运行在 `http://localhost:8000`。*

### 1.2 前端环境启动 (Flutter)

前端移动与Web端代码位于 `flutter_app/` 目录下。

1. **环境检查**：
   确保您的机器已安装正确版本的 [Flutter SDK](https://flutter.dev/docs/get-started/install)。可执行 `flutter doctor` 检查。

2. **安装所有的 Flutter 扩展包**：
   ```bash
   cd flutter_app
   flutter pub get
   ```

3. **运行并启动应用**：
   您可以运行在 Chrome，移动模拟器，或 Windows 桌面等。
   ```bash
   # 如果您的后端运行在默认端口 8000：
   flutter run
   
   # 如果不是本机的 8000，可以通过 Dart Define 覆盖 API 地址：
   flutter run --dart-define=API_BASE_URL=http://<YOUR-IP>:8000/api/v1
   ```

---

## 二、本地测试与代码验证

无论是在部署代码前还是提交 PR 前，都需要通过本地核心验证来确保代码完好无损。

### 2.1 后端自动化测试 (`pytest`)
在进行后端数据库或 API 修改后，您必须确保测试全部通过。
```bash
# 在项目根目录执行
cd backend
python -m pytest tests/ -v
```
*(目前测试已达到全面的用例覆盖并保证100%通过状态)*。

### 2.2 前端代码验证
确保您的 Dart/Flutter 代码没有拼写和风格错误。
```bash
cd flutter_app
flutter analyze
flutter test  # 如果您编写了单元测试的话
```

---

## 三、部署指南 (Deploy)

如果您需要将应用部署到服务器，推荐基于 `Docker Compose` 的自动化容器部署方案。您可以选择使用一键的 **研发环境容器编排** 或 **生产正式环境编排**。

相关的部署文件完全存放在 `deploy/` 目录中。

### 3.1 前期准备
1. 确保目标服务器已安装 `Docker 20.10+` 和 `Docker Compose 2.0+`。
2. 准备环境变量：
   ```bash
   cd deploy
   cp .env.prod.example .env
   # -> 编辑 .env 并补充真实的数据库密码、JWT 密钥以及 OpenAI API Key 等等。
   ```

### 3.2 情景 A：全栈本地或测试服务器容器化启动 (Development)

适合在一台纯净虚拟机中快速启动测试：
```bash
cd deploy
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```
> **说明**：开发编排开启了所有测试端口并将 API 抛出以供测试联调，未开启严格验证模式。

### 3.3 情景 B：生产环境正式部署 (Production)

在生产部署中，容器配置会自动采取更安全的资源隔离以及反向代理等：
```bash
cd deploy
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```
启动完成之后执行数据库初始结构导入：
```bash
docker-compose exec backend python -c "from app.database import init_db; import asyncio; asyncio.run(init_db())"
```

### 3.4 生产注意与强制安全锁

1. **环境安全锁保护机制**：
   在 `.env` 中，一旦设置 `DEBUG=false` 或者配置 `APP_ENV=production`，后端系统会默认开启生产安全锁。
   系统将强制：
   - 使用随机熵更高的 `JWT_SECRET_KEY` （如果不配置将直接拒绝启动）。
   - 只接收指定的受限域名列表 `BACKEND_CORS_ORIGINS`。
   - `EXPOSE_DEBUG_VERIFICATION_CODE` 会强制失效（短信息不再在接口回显）。
2. **Nginx/HTTPS 配置**：生产网络必须受到 SSL 保护。可在 `deploy/nginx/` 配置 SSL 证书并将 Nginx 中的 `listen 443 ssl` 相关选项开启。

### 3.5 版本平滑更新 (Hot Update)
当您的代码推入部署仓库后：
```bash
cd deploy
docker-compose pull
docker-compose up -d --force-recreate backend   # 无中断构建后端并重新挂载
```
对于数据安全性，我们已经在 `deploy/backup` 提供了 `./backup.sh`，可以将计划任务注入 `crontab` 每日执行全卷转储。
