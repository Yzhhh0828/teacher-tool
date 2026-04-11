# 教师工具 (Teacher Tool) - 产品设计

## 1. 概述

一款面向班主任和教师的班级管理工具，以 AI Agent 为核心交互方式，简化数据录入流程。支持多平台（移动端、桌面端、Web），后端采用 Python 构建。

### 1.1 MVP 范围

| 模块 | 描述 |
|------|------|
| 班级管理 | 学生、成绩、课表、座位 CRUD |
| AI Agent | 对话 + 图片识别 + 人类确认 + MCP 工具调用 |
| 用户体系 | 手机号注册、JWT 认证、RBAC 权限 |
| Excel 导入/导出 | 学生信息、成绩批量操作 |
| 展示端 | 投影模式、大字体界面 |

### 1.2 未来扩展

- 教师维度功能（备课、出卷）
- 家长角色
- 更多 LLM 供应商
- 长期对话记忆
- 第三方登录

---

## 2. 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                      Flutter App (多平台)                    │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   管理端    │  │   展示端    │  │    Agent 对话 UI    │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│                      REST API + SSE                          │
└────────────────────────────┬────────────────────────────────┘
                             │
┌────────────────────────────┼────────────────────────────────┐
│            Python FastAPI Backend                            │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐  │
│  │  REST API    │  │  MCP Server   │  │  Langchain v1     │  │
│  │  (CRUD)      │  │  (工具暴露)    │  │  (对话理解)       │  │
│  └──────────────┘  └──────────────┘  └────────────────────┘  │
│                  SQLAlchemy ORM + 云存储 (OSS/S3)            │
└─────────────────────────────────────────────────────────────┘
```

### 2.1 技术栈

| 层级 | 技术 |
|------|------|
| 后端框架 | FastAPI |
| ORM | SQLAlchemy |
| AI Agent | Langchain v1 + Langgraph |
| MCP | FastMCP |
| 数据库 | SQLite (MVP) / PostgreSQL (生产) |
| 文件存储 | 阿里云 OSS / S3 兼容 |
| 前端 | Flutter + Riverpod |
| 状态管理 | Riverpod |
| 通信 | REST API + SSE |
| LLM | OpenAI / Anthropic 兼容（可切换 base_url + api_key）|

---

## 3. 数据模型

```
User (用户)
├── id (PK)
├── phone (手机号，唯一)
├── password_hash
└── created_at

Class (班级)
├── id (PK)
├── name (班级名称)
├── grade (年级)
├── owner_id (FK → User)
└── created_at

ClassMember (班级成员关联)
├── id (PK)
├── class_id (FK → Class)
├── user_id (FK → User)
├── role (owner/teacher)
├── subject (教授科目，仅教师)
└── joined_at

Student (学生)
├── id (PK)
├── class_id (FK → Class)
├── name
├── gender
├── phone
├── parent_phone
└── created_at

Exam (考试)
├── id (PK)
├── class_id (FK → Class)
├── name
├── date
└── subjects (JSON array)

Grade (成绩)
├── id (PK)
├── exam_id (FK → Exam)
├── student_id (FK → Student)
├── subject
└── score

Schedule (课程表，班级维度)
├── id (PK)
├── class_id (FK → Class)
├── day_of_week (0-6)
├── period (第几节课)
├── subject
├── teacher_name
└── classroom

Seating (座位表)
├── id (PK)
├── class_id (FK → Class, unique)
├── rows
├── cols
├── seats (JSON: 二维数组存储学生ID)
└── updated_at
```

### 3.1 设计说明

- 一个学生只能属于一个班级
- 课程表是班级维度
- 座位表固定座位，每次考试可重新排
- Seats 用 JSON 存储座位矩阵，支持拖动修改

---

## 4. 用户体系与权限

### 4.1 角色定义

| 角色 | 标识 | 描述 |
|------|------|------|
| 班主任 | `owner` | 班级创建者，最高权限 |
| 教师 | `teacher` | 被邀请加入，学科权限 |

### 4.2 权限矩阵

| 操作 | 班主任 (owner) | 教师 (teacher) |
|------|----------------|----------------|
| 班级设置 | ✅ | ❌ |
| 邀请教师 | ✅ | ❌ |
| 移除教师 | ✅ | ❌ |
| 添加/删除学生 | ✅ | ❌ |
| 查看学生列表 | ✅ | ✅ |
| 录入/修改成绩 | ✅ | ✅（仅教授科目） |
| 查看成绩 | ✅ | ✅（仅教授科目） |
| 管理座位表 | ✅ | ❌ |
| 使用 Agent | ✅ | ✅ |
| Excel 导入 | ✅ | ✅（仅成绩） |

### 4.3 邀请码机制

- 班主任生成邀请码
- 教师输入邀请码 + 选择教授科目加入班级
- 未来可扩展：手机号邀请、站内信

### 4.4 认证机制

- JWT Access Token (1小时)
- JWT Refresh Token (7天)
- 第三方登录保留扩展性（微信等）

---

## 5. Agent 与 MCP 架构

### 5.1 Agent 工作流程

```
用户输入（文字/图片）
       ↓
┌──────────────────┐
│  Langchain v1    │
│  (意图理解 + 工具调用) │
└────────┬─────────┘
         ↓
┌─────────────────────────┐
│     人类确认 (Human-in-Loop) │
│  (新增/修改/删除操作前暂停)   │
└────────┬────────────────┘
         ↓
┌──────────────────┐
│    MCP Tools     │
└──────────────────┘
         ↓
┌──────────────────┐
│   FastAPI 执行   │
└──────────────────┘
         ↓
流式响应 (SSE) → Flutter App
```

### 5.2 MCP Tools (MVP)

| Tool | 参数 | 说明 |
|------|------|------|
| `get_students` | class_id | 获取班级学生列表 |
| `add_student` | class_id, name, gender, phone... | 新增学生 |
| `update_student` | student_id, fields | 更新学生信息 |
| `delete_student` | student_id | 删除学生 |
| `get_grades` | class_id, exam_id | 获取成绩 |
| `add_grade` | exam_id, student_id, subject, score | 录入成绩 |
| `update_grade` | grade_id, score | 修改成绩 |
| `get_seating` | class_id | 获取座位表 |
| `update_seating` | class_id, seats | 更新座位表 |
| `random_shuffle_seats` | class_id | 随机换座位 |

### 5.3 确认机制分级

| 级别 | 查询 | 新增 | 修改 | 删除 |
|------|------|------|------|------|
| 低 | 直接 | 确认 | 确认 | 确认 |
| 中（默认） | 直接 | 确认 | 确认 | 二次确认 |
| 高 | 直接 | 确认 | 确认 | 二次确认 |

用户可调整，默认中级别。

### 5.4 对话记忆

- 短期记忆（Session 级别）
- 存储在数据库
- 支持扩展长期记忆

---

## 6. Flutter 应用结构

### 6.1 页面结构

```
Flutter App
├── 登录/注册
│   └── 手机号 + 验证码
│
├── 主页面 (BottomNavigation)
│   ├── 班级列表
│   │   ├── 创建班级
│   │   └── 加入班级 (邀请码)
│   │
│   ├── 学生管理
│   │   ├── 学生列表
│   │   ├── 添加学生 (手动/拍照)
│   │   └── 批量导入 (Excel)
│   │
│   ├── 成绩管理
│   │   ├── 考试列表
│   │   ├── 录入成绩 (手动/拍照)
│   │   └── 成绩统计
│   │
│   └── 座位管理
│       ├── 座位表编辑 (拖拽)
│       ├── 随机换座位
│       └── 导出座位表
│
├── 展示端 (切换模式)
│   └── 大字体、只读
│
└── Agent 助手
    ├── 对话界面
    ├── 图片上传
    └── 历史记录
```

### 6.2 状态管理 (Riverpod)

```
providers/
├── auth_provider.dart
├── class_provider.dart
├── student_provider.dart
├── grade_provider.dart
├── seating_provider.dart
├── agent_provider.dart
└── settings_provider.dart
```

### 6.3 跨平台适配

- 手机：标准布局
- 平板/桌面：侧边栏导航
- 展示端：大字体、高对比度

---

## 7. API 接口

### 7.1 认证

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/v1/auth/send_code` | 发送验证码 |
| POST | `/api/v1/auth/login` | 登录 |
| POST | `/api/v1/auth/refresh` | 刷新 Token |
| POST | `/api/v1/auth/logout` | 登出 |

### 7.2 班级

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/v1/classes` | 创建班级 |
| GET | `/api/v1/classes` | 班级列表 |
| GET | `/api/v1/classes/{id}` | 班级详情 |
| PUT | `/api/v1/classes/{id}` | 更新班级 |
| DELETE | `/api/v1/classes/{id}` | 删除班级 |
| POST | `/api/v1/classes/{id}/invite_code` | 生成邀请码 |
| POST | `/api/v1/classes/join` | 加入班级 |

### 7.3 学生

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/v1/students` | 添加学生 |
| GET | `/api/v1/classes/{class_id}/students` | 学生列表 |
| PUT | `/api/v1/students/{id}` | 更新学生 |
| DELETE | `/api/v1/students/{id}` | 删除学生 |
| POST | `/api/v1/students/batch_import` | 批量导入 |
| GET | `/api/v1/students/export` | 导出学生 |

### 7.4 成绩

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/v1/exams` | 创建考试 |
| GET | `/api/v1/classes/{class_id}/exams` | 考试列表 |
| POST | `/api/v1/grades` | 录入成绩 |
| GET | `/api/v1/exams/{exam_id}/grades` | 成绩列表 |
| PUT | `/api/v1/grades/{id}` | 更新成绩 |
| POST | `/api/v1/grades/batch_import` | 批量导入成绩 |

### 7.5 座位

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/v1/classes/{class_id}/seating` | 获取座位表 |
| PUT | `/api/v1/classes/{class_id}/seating` | 更新座位表 |
| POST | `/api/v1/classes/{class_id}/seating/shuffle` | 随机换座位 |

### 7.6 Agent

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/v1/agent/chat` | 发送消息（SSE 流式） |
| GET | `/api/v1/agent/history/{session_id}` | 对话历史 |

---

## 8. 项目结构

### 8.1 后端 (Python)

```
backend/
├── app/
│   ├── main.py
│   ├── config.py
│   ├── database.py
│   ├── models/
│   ├── schemas/
│   ├── api/
│   ├── mcp/
│   ├── agent/
│   └── core/
├── requirements.txt
├── alembic/
└── run.py
```

### 8.2 前端 (Flutter)

```
flutter_app/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   ├── data/
│   ├── providers/
│   ├── ui/
│   └── agent/
├── pubspec.yaml
└── ...
```

---

## 9. 参考项目

以下项目在功能或架构上提供了参考：

### 9.1 功能参考

| 项目 | 来源 | 参考价值 |
|------|------|----------|
| [PersonalLearningPro](https://github.com/NitishKumar-ai/PersonalLearningPro) | GitHub | AI辅导、智能出卷、OCR扫描、角色RBAC |
| [AI-Powered Smart School](https://github.com/Tharusha200219/AI-Powered-Smart-School-Safety-and-Performance-Monitoring-System) | GitHub | 智能座位优化算法 |
| [An Agentic AI Education](https://github.com/zainab34iiee/An-Agentic-AI-Based-Intelligent-Education-Service-Assistance-System) | GitHub | AI Agent + RAG 架构参考 |
| [SaralKakshyaProject](https://github.com/AlenPariyarOct10/SaralKakshyaProject) | GitHub | Laravel + Flask 混合架构 |
| [E_schooll](https://github.com/muluken16/E_schooll) | GitHub | Django + React 成绩管理 |

### 9.2 技术参考

| 项目/框架 | 参考价值 |
|-----------|----------|
| [Langchain](https://github.com/langchain-ai/langchain) | Agent 核心框架 |
| [FastMCP](https://github.com/jlowin/fastmcp) | MCP Server 实现 |
| [ school management system ](https://github.com/) | 更多学校管理系统搜索关键词 |

---

## 10. 未来待开发功能

### 10.1 近期扩展

| 功能 | 描述 | 优先级 |
|------|------|--------|
| 课表管理 | 班级维度课程表 CRUD | P1 |
| Excel 批量导入/导出 | 学生信息、成绩批量操作 | P1 |
| 展示端 | 投影模式、大字体界面 | P1 |
| 长期对话记忆 | 跨设备、跨会话的记忆 | P2 |
| 成绩分布可视化 | 柱状图、饼图、趋势图 | P2 |
| 课堂投票/问答 | 展示端互动功能 | P2 |

### 10.2 中期规划

| 功能 | 描述 | 优先级 |
|------|------|--------|
| 教师备课功能 | 教案管理、教学资源 | P3 |
| 出卷功能 | 题库、组卷、打印 | P3 |
| 家长角色 | 查看学生成绩、班级通知 | P3 |
| 第三方登录 | 微信登录 | P3 |
| 更多 LLM 供应商 | 硅基流动、火山引擎等 | P3 |
| 班级通知推送 | 推送给家长/学生 | P3 |

### 10.3 远期规划

| 功能 | 描述 | 优先级 |
|------|------|--------|
| AI 出卷 | 根据知识点自动生成试卷 | P4 |
| 学情分析 | AI 分析学生学习情况 | P4 |
| 课堂互动 | 实时问答、投票、分组 | P4 |
| 付费会员体系 | 基础版/专业版分层 | P4 |
| 多语言支持 | 国际化 | P4 |

### 10.4 头脑风暴功能点

以下功能可在后续版本考虑：

**课堂互动类：**
- 🎯 随机点名（支持排除已点名）
- ⏱️ 倒计时器（小组讨论计时）
- 🎲 分组工具（一键随机分组、成绩分层分组）
- 📊 课堂投票/问答（选择题、简答题）
- 🏆 积分系统（学生课堂表现积分）

**管理增强类：**
- 📈 成绩分布可视化（柱状图、饼图、排名）
- 📅 出勤统计（迟到率、请假统计）
- 📢 班级通知（推送/短信）
- 🔔 考试提醒（到期提醒）
- 📋 班级事务管理（值日表、班委）

**AI 增强类：**
- 📸 OCR 拍照识别（试卷、答题卡）
- 🎤 语音输入
- 📝 作业批改辅助
- 📚 知识点关联（学生成绩 ↔ 知识点掌握）

**展示端功能：**
- 📺 班级荣誉墙
- 🎬 倒计时大屏
- 🎯 抽奖/随机选择器
- 📊 成绩龙虎榜

---

## 11. 部署方案

### 11.1 Docker Compose 架构

```
┌─────────────────────────────────────────────────────────────┐
│                      Docker Compose                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Nginx     │  │  Backend    │  │   Redis     │         │
│  │  (反向代理)   │  │  (FastAPI)  │  │  (缓存)     │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│         │                │                                   │
│         │                │                ┌─────────────┐  │
│         │                └───────────────►│ PostgreSQL  │  │
│         │                                 │  (数据库)    │  │
│         │                                 └─────────────┘  │
│         │                                              │     │
│         │                ┌─────────────┐               │     │
│         └───────────────►│  MinIO       │◄──────────────┘     │
│                          │  (对象存储)   │                      │
│                          └─────────────┘                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 11.2 容器说明

| 容器 | 镜像 | 说明 |
|------|------|------|
| Nginx | nginx:alpine | 反向代理、SSL  termination、静态资源 |
| Backend | 自定义 Python 镜像 | FastAPI 应用 |
| PostgreSQL | postgres:15-alpine | 主数据库 |
| Redis | redis:7-alpine | 会话存储、缓存 |
| MinIO | minio/minio | S3 兼容对象存储（可选阿里云 OSS） |

### 11.3 目录结构

```
deploy/
├── docker-compose.yml          # 容器编排
├── docker-compose.dev.yml      # 开发环境
├── docker-compose.prod.yml    # 生产环境
├── nginx/
│   ├── nginx.conf             # Nginx 配置
│   └── ssl/                   # SSL 证书
├── backend/
│   ├── Dockerfile
│   └── ...
├── flutter/
│   └── Dockerfile             # Web 构建
├── backups/                    # 备份脚本
│   └── backup.sh
└── scripts/
    ├── init-db.sh             # 数据库初始化
    └── migrate.sh             # 数据库迁移
```

### 11.4 环境变量

```bash
# 数据库
DATABASE_URL=postgresql://user:password@postgres:5432/teacher_tool

# Redis
REDIS_URL=redis://redis:6379/0

# JWT
JWT_SECRET_KEY=your-secret-key
JWT_ALGORITHM=HS256

# LLM (OpenAI 或 Anthropic)
LLM_PROVIDER=openai
OPENAI_API_KEY=sk-...
OPENAI_BASE_URL=https://api.openai.com/v1
# 或
ANTHROPIC_API_KEY=sk-ant-...
ANTHROPIC_BASE_URL=https://api.anthropic.com

# 对象存储 (MinIO 或 S3)
STORAGE_TYPE=minio
MINIO_ENDPOINT=minio:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_BUCKET=teacher-tool
# 或使用阿里云 OSS
# OSS_ENDPOINT=oss-cn-hangzhou.aliyuncs.com
# OSS_ACCESS_KEY=...
# OSS_SECRET_KEY=...
# OSS_BUCKET=...

# SMS (短信验证码)
SMS_PROVIDER=aliyun
SMS_ACCESS_KEY=...
SMS_SECRET_KEY=...
```

### 11.5 部署命令

```bash
# 开发环境
docker-compose -f docker-compose.dev.yml up -d

# 生产环境
docker-compose -f docker-compose.prod.yml up -d

# 备份数据库
./backups/backup.sh

# 查看日志
docker-compose logs -f backend
```

### 11.6 未来扩展

| 组件 | 说明 |
|------|------|
| Prometheus + Grafana | 监控告警 |
| ELK Stack | 日志收集分析 |
| Caddy | 替代 Nginx（自动 HTTPS） |
| Traefik | 动态路由（微服务扩展） |
| Drone CI / GitHub Actions | CI/CD 流水线 |

---

## 12. 验证码短信

MVP 阶段短信验证码可选方案：

| 方案 | 说明 |
|------|------|
| 阿里云短信 | 国内主流，按量付费 |
| 腾讯云短信 | 同上 |
| 模拟模式 | 开发环境使用，固定验证码 123456 |
