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

## 9. 部署考虑

- 数据库：SQLite (MVP) → PostgreSQL (生产)
- 文件存储：本地文件系统 → 阿里云 OSS / S3 兼容
- 会话存储：内存 → Redis（可选）
- 后端部署：Docker 或直接运行
