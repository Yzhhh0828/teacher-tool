# 教师工具平台 (Teacher Tool)

这是一个专为现代教育场景设计的全栈工具平台，旨在帮助教师更高效地管理班级、学生、成绩、课程表以及进行课堂互动（配合 AI 助手），从而进一步提升生产力。

## 架构概览

- **前端平台**: Flutter (Android, iOS, Web, Desktop) - 基于 Riverpod 的状态管理；提供 *Warm Orange*（默认）与 *Mellard Green M3-Expressive* 两套主题；**用户偏好（主题、当前班级、心情、自定义金句）通过 `PrefsService` 持久化于 SharedPreferences，关闭重开仍保留**。
- **后端架构**: Python 3.10+ / FastAPI - 自研轻量 LLM Provider 抽象层，原生支持 **OpenAI 兼容协议 / Anthropic / Ollama** 三种后端，附带可插拔的 Agent 工具注册表（学生 / 成绩 / 座位 / 分析 / 课堂 / 视觉录入）+ 写操作二次确认与撤销链。
- **数据库组件**: SQLite（默认）/ PostgreSQL，使用 SQLAlchemy 2.x async ORM；启动时执行 `ensure_backward_compatible_schema` 幂等迁移补齐缺失字段。
- **缓存与状态**: Redis (可选，用于分布式锁与队列等)。

### 主要功能模块

- **工作台首页**：成绩趋势 sparkline、心情速记 + 每日金句卡片、今日课表、生日提醒。
- **班级 / 学生**：批量导入（粘贴一列名字）、性别 / 联系方式 / 备注扩展字段。
- **座位**：拖拽换座、随机排座、行列调整、保存 / 加载多套方案、**导出 PNG / PDF / 系统打印**。
- **行为积分**：自定义类目 + 预设、单次多人加扣分、班级排行榜。
- **成绩 / 分析**：考试 CRUD、批量录分、班级趋势 / 考试分布 / 学生轨迹。
- **AI Agent**：自然语言 → 工具调用 → 二次确认 → 审计日志 → 一键撤销。
- **协作邀请**：邀请码加入、成员管理、跨教师共建班级。

### 进一步阅读

- [`docs/architecture.md`](docs/architecture.md) — 完整模块拓扑与数据流
- [`docs/ai-agent.md`](docs/ai-agent.md) — Provider 抽象、工具注册表、HTTP 接口
- [`docs/design-system.md`](docs/design-system.md) — 设计代币、调色板、复用组件

---

## 一、本地开发启动指南 (Local Development)

对于在本地直接进行代码开发的场景，我们推荐将前端后端分开独立运行，而不是通过 Docker 容器化所有组件，以便更好的热重载（HOT RELOAD）。

> **快速启动**: 可直接运行 `scripts/dev_start.ps1`（Windows）或 `scripts/dev_start.sh`（Linux/Mac），脚本会自动创建虚拟环境、安装依赖并启动后端。默认使用 SQLite，零配置即可运行。

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

### 2.1 测试矩阵一览

| 层 | 工具 | 路径 | 数量 | 命令 |
| --- | --- | --- | --- | --- |
| 后端单元 + E2E | pytest | `backend/tests/` | **111** | `cd backend && pytest -q` |
| Flutter 单元 + Widget | flutter test | `flutter_app/test/` | **53** | `cd flutter_app && flutter test` |
| API 端到端 | Playwright | `e2e/tests/` | **15** | `cd e2e && npx playwright test` |

合计 **179 个自动化测试**，全部并入 GitHub Actions（见 `.github/workflows/ci.yml`），任意 push / PR 触发。

### 2.2 后端自动化测试 (`pytest`)

```bash
cd backend
python -m pytest -q
```

覆盖：身份验证、班级 / 学生 / 成绩 / 课程表 / 座位 / 行为 / 邀请 / 仪表盘 / 分析 / 课堂 / Agent 工具调用与撤销链 / 数据库迁移幂等。

### 2.3 前端测试与静态分析

```bash
cd flutter_app
flutter analyze
flutter test
```

覆盖：PrefsService 持久化、ThemeNotifier、AuthNotifier、CurrentClassNotifier、GoRouter 不重建不变量、SeatingExporter PNG 捕获、MoodQuoteCard 渲染 / 持久化、各通用 widget。

### 2.4 Playwright API E2E

```bash
cd e2e
npm install            # 首次
npx playwright test    # 自动启动后端 webServer
```

8 个 spec / 15 用例，覆盖：登录鉴权、班级 CRUD + 跨租户隔离、学生批量导入、座位布局生命周期、行为积分聚合、分析端到端、邀请加入、Agent 二次确认 + 审计 + 撤销。详见 [`e2e/README.md`](e2e/README.md)。

### 2.5 手动验证 Checklist

部署或重大改动后，建议跑一遍完整端到端：

1. **登录**
   - [ ] `13912345678` 输入手机号 → 获取验证码 → 登录成功 → 落地工作台（不再回弹设置页）
   - [ ] 切换主题色 / 明暗模式 → 退出 → 重新登录 → 主题保持
2. **班级 / 学生**
   - [ ] 新建班级 → 学生页粘贴 5 个名字批量导入 → 列表立即出现
   - [ ] 切换班级 → 重新进入 → 所选班级保持（持久化）
3. **座位**
   - [ ] 座位页拖拽两个学生交换 → 保存
   - [ ] 调整行列、保存方案、加载方案
   - [ ] 导出 PNG → 浏览器下载（Web）/ 系统保存（桌面）
   - [ ] 导出 PDF → 浏览器打印（Web）/ 系统打印对话框（桌面）
4. **行为积分**
   - [ ] 给学生加分 / 扣分 → 排行榜实时刷新
5. **分析**
   - [ ] 班级总览：学生数、考试数、最近一次考试
   - [ ] 单次考试分数分布柱状图
6. **邀请协作**
   - [ ] 班主任生成邀请码 → 复制 → 第二个账号加入 → 成员列表显示双方
7. **Agent 助手**
   - [ ] 自然语言 "给三班加 5 个学生 张三 李四 王五" → 弹出确认 → 点击执行 → 列表落库
   - [ ] 历史动作页点击撤销 → 数据回滚
8. **登出**
   - [ ] 设置 → 退出登录 → 回到登录页 → currentClass / lastTab 已清理但主题保留

---

## 三、部署指南 (Deploy)

如果您需要将应用部署到服务器，推荐基于 `Docker Compose` 的自动化容器部署方案。您可以选择使用一键的 **研发环境容器编排** 或 **生产正式环境编排**。

相关的部署文件完全存放在 `deploy/` 目录中。

### 3.1 前期准备
1. 确保目标服务器已安装 `Docker 20.10+` 和 `Docker Compose 2.0+`。
2. 准备环境变量：
   ```bash
   cd deploy
   cp .env.example .env
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
   - `DATABASE_URL` 不允许使用 SQLite（必须使用 PostgreSQL）。
2. **Nginx/HTTPS 配置**：生产网络必须受到 SSL 保护。可在 `deploy/nginx/` 配置 SSL 证书并将 Nginx 中的 `listen 443 ssl` 相关选项开启。

### 3.5 版本平滑更新 (Hot Update)
当您的代码推入部署仓库后：
```bash
cd deploy
docker-compose pull
docker-compose up -d --force-recreate backend   # 无中断构建后端并重新挂载
```
对于数据安全性，我们已经在 `deploy/backup` 提供了 `./backup.sh`，可以将计划任务注入 `crontab` 每日执行全卷转储。
