# 教师工具 (Teacher Tool) - 实施计划

> **For agentic workers:** Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 完整的教师工具 MVP，包含班级管理、AI Agent、用户认证、Flutter 多平台前端

**Architecture:** 微服务架构风格，FastAPI 后端 + Flutter 前端 + PostgreSQL + Redis + MinIO

**Tech Stack:** Python/FastAPI, SQLAlchemy, Langchain v1, FastMCP, Flutter/Riverpod, PostgreSQL, Redis, MinIO

---

## Phase 1: 后端基础设施 ✅ 完成

**目标:** 搭建项目结构、数据库模型、认证系统

**Sub-plan:** `docs/superpowers/plans/2026-04-12-phase1-backend-infrastructure.md`

**完成时间:** 2026-04-12

### 已完成
- [x] 项目目录结构
- [x] 数据库模型 (User, Class, ClassMember, Student, Exam, Grade, Schedule, Seating)
- [x] 认证 API (发送验证码、登录、刷新Token、登出)
- [x] RBAC 权限中间件
- [x] Docker Compose 开发环境 (PostgreSQL, Redis, MinIO)

---

## Phase 2: 核心 CRUD API ✅ 完成

**目标:** 实现所有 CRUD 接口

**Sub-plan:** `docs/superpowers/plans/2026-04-12-phase2-core-crud-api.md`

**完成时间:** 2026-04-12

### 已完成
- [x] 班级 API (CRUD + 邀请码)
- [x] 学生 API (CRUD)
- [x] 成绩 API (CRUD)
- [x] 座位 API (CRUD + 随机换座位)
- [x] 课表 API (CRUD)

**注意:** 批量导入/导出在 Phase 2 实现为部分完成，Excel 功能待 Phase 4 Flutter 端实现

---

## Phase 3: AI Agent + MCP ✅ 完成

**目标:** 实现 Agent 对话系统和 MCP 工具

**Sub-plan:** `docs/superpowers/plans/2026-04-12-phase3-ai-agent-mcp.md`

**完成时间:** 2026-04-12

### 已完成
- [x] MCP Server 实现 (FastMCP)
- [x] MCP Tools (学生、成绩、座位相关)
- [x] Langchain Agent 配置
- [x] SSE 流式响应
- [x] 人类确认机制
- [x] 短期会话记忆

**待完成:** MCP 工具调用与 Agent Chain 的完整集成（Agent 执行实际操作）

---

## Phase 4: Flutter 前端 🚧 进行中

**目标:** 完成 Flutter 多平台应用

**Sub-plan:** `docs/superpowers/plans/2026-04-12-phase4-flutter-frontend.md`

### 包含内容
- [ ] Flutter 项目搭建 (Riverpod)
- [ ] 认证 UI (登录/注册)
- [ ] 班级管理 UI
- [ ] 学生管理 UI
- [ ] 成绩管理 UI
- [ ] 座位管理 UI
- [ ] Agent 对话 UI
- [ ] 展示端模式
- [ ] Excel 导入/导出

---

## Phase 5: 生产部署 ⏳ 待开始

**目标:** 完成生产环境部署配置

**Sub-plan:** `docs/superpowers/plans/2026-04-12-phase5-production-deployment.md`

### 包含内容
- [ ] Docker Compose 生产配置
- [ ] Nginx 配置
- [ ] 环境变量文档
- [ ] CI/CD 流水线 (可选)

---

## Phase 依赖关系

```
Phase 1 (基础设施)
    │
    ├── Phase 2 (CRUD API) ─────────────┐
    │                                    │
    └── Phase 3 (AI Agent) ─────────────┼── Phase 4 (Flutter)
    │                                    │
    └── Phase 5 (部署) ◄────────────────┘
```

---

## 快速开始 (MVP)

### 开发环境启动

```bash
# 1. 克隆项目
cd teacher-tool

# 2. 启动基础设施 (PostgreSQL, Redis, MinIO)
docker-compose -f deploy/docker-compose.dev.yml up -d

# 3. 安装后端依赖
cd backend
pip install -r requirements.txt

# 4. 运行后端
python run.py

# 5. 启动 Flutter (新终端)
cd flutter_app
flutter run
```

### 环境变量

参考 `deploy/.env.example`
