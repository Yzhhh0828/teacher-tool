# Phase 1: 后端基础设施

**目标:** 搭建项目结构、数据库模型、认证系统

**Sub-plan for:** [主计划](./2026-04-12-teacher-tool-master-plan.md)

---

## 文件结构

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py              # FastAPI 入口
│   ├── config.py            # 配置
│   ├── database.py          # SQLAlchemy 连接
│   ├── models/
│   │   ├── __init__.py
│   │   ├── user.py          # User 模型
│   │   ├── class_.py        # Class, ClassMember 模型
│   │   ├── student.py       # Student 模型
│   │   ├── exam.py          # Exam, Grade 模型
│   │   ├── schedule.py      # Schedule 模型
│   │   └── seating.py       # Seating 模型
│   ├── schemas/
│   │   ├── __init__.py
│   │   ├── auth.py          # 认证 Pydantic 模型
│   │   ├── user.py
│   │   ├── class_.py
│   │   ├── student.py
│   │   ├── grade.py
│   │   └── seating.py
│   ├── api/
│   │   ├── __init__.py
│   │   ├── deps.py          # 依赖注入 (get_db, get_current_user)
│   │   └── auth.py          # 认证路由
│   └── core/
│       ├── __init__.py
│       ├── security.py      # JWT, 密码哈希
│       └── config.py        # 配置模型
├── tests/
│   ├── __init__.py
│   ├── conftest.py
│   ├── test_auth.py
│   └── test_models.py
├── deploy/
│   ├── docker-compose.dev.yml
│   └── .env.example
├── requirements.txt
└── run.py
```

---

## Task 1: 项目基础结构

**Files:**
- Create: `backend/requirements.txt`
- Create: `backend/run.py`
- Create: `backend/app/__init__.py`
- Create: `backend/app/config.py`
- Create: `backend/app/database.py`

- [ ] **Step 1: Create requirements.txt**

```txt
# Core
fastapi==0.115.0
uvicorn[standard]==0.30.0
pydantic==2.9.0
pydantic-settings==2.5.0

# Database
sqlalchemy==2.0.35
asyncpg==0.29.0
alembic==1.13.3
aiosqlite==0.20.0

# Auth
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
python-multipart==0.0.12

# Redis
redis==5.0.0

# AI / Agent
langchain==0.3.0
langchain-core==0.3.0
langchain-openai==0.2.0
langchain-anthropic==0.3.0
langgraph==0.2.0
fastmcp==0.1.0

# File Storage
boto3==1.35.0
python-multipart==0.0.12

# Utils
python-dotenv==1.0.0
```

- [ ] **Step 2: Create run.py**

```python
import uvicorn

if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
    )
```

- [ ] **Step 3: Create app/config.py**

```python
from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # App
    APP_NAME: str = "Teacher Tool"
    DEBUG: bool = True

    # Database
    DATABASE_URL: str = "sqlite+aiosqlite:///./teacher_tool.db"

    # JWT
    JWT_SECRET_KEY: str = "your-secret-key-change-in-production"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"

    # LLM
    LLM_PROVIDER: str = "openai"  # openai or anthropic
    OPENAI_API_KEY: str = ""
    OPENAI_BASE_URL: str = "https://api.openai.com/v1"
    ANTHROPIC_API_KEY: str = ""
    ANTHROPIC_BASE_URL: str = "https://api.anthropic.com"

    # Storage
    STORAGE_TYPE: str = "local"  # local, minio, oss
    MINIO_ENDPOINT: str = "localhost:9000"
    MINIO_ACCESS_KEY: str = "minioadmin"
    MINIO_SECRET_KEY: str = "minioadmin"
    MINIO_BUCKET: str = "teacher-tool"

    class Config:
        env_file = ".env"


@lru_cache()
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
```

- [ ] **Step 4: Create app/database.py**

```python
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase

from app.config import settings


class Base(DeclarativeBase):
    pass


engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.DEBUG,
)

async_session_maker = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


async def get_db():
    async with async_session_maker() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def init_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
```

- [ ] **Step 5: Commit**

```bash
cd backend && git init && git add -A && git commit -m "feat: add backend project structure"
```

---

## Task 2: 用户认证模型

**Files:**
- Create: `backend/app/models/user.py`
- Create: `backend/app/models/__init__.py`
- Modify: `backend/app/models/` (add other models later)

- [ ] **Step 1: Create app/models/user.py**

```python
from datetime import datetime
from sqlalchemy import String, DateTime
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    phone: Mapped[str] = mapped_column(String(20), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    # Relationships
    owned_classes: Mapped[list["Class"]] = relationship("Class", back_populates="owner")
    memberships: Mapped[list["ClassMember"]] = relationship("ClassMember", back_populates="user")
```

- [ ] **Step 2: Create app/models/__init__.py**

```python
from app.models.user import User

__all__ = ["User"]
```

- [ ] **Step 3: Create tests/test_models.py**

```python
import pytest
from datetime import datetime
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from app.database import Base
from app.models.user import User


@pytest.fixture
async def db_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    async with async_session() as session:
        yield session


@pytest.mark.asyncio
async def test_create_user(db_session):
    user = User(phone="13800138000", password_hash="hashed_password")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    assert user.id is not None
    assert user.phone == "13800138000"
    assert user.created_at is not None
```

- [ ] **Step 4: Run test to verify it fails**

Run: `cd backend && pytest tests/test_models.py -v`
Expected: FAIL - models not created yet

- [ ] **Step 5: Create all model files (Student, Class, etc.)**

Create files with empty models for now (full implementation in Phase 2)

```python
# app/models/class_.py
from sqlalchemy import String, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class Class(Base):
    __tablename__ = "classes"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    grade: Mapped[str] = mapped_column(String(50))
    owner_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    owner: Mapped["User"] = relationship("User", back_populates="owned_classes")
    members: Mapped[list["ClassMember"]] = relationship("ClassMember", back_populates="class_")
    students: Mapped[list["Student"]] = relationship("Student", back_populates="class_")


class ClassMember(Base):
    __tablename__ = "class_members"

    id: Mapped[int] = mapped_column(primary_key=True)
    class_id: Mapped[int] = mapped_column(ForeignKey("classes.id"))
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    role: Mapped[str] = mapped_column(String(20))  # owner, teacher
    subject: Mapped[str] = mapped_column(String(50), nullable=True)
    joined_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    class_: Mapped["Class"] = relationship("Class", back_populates="members")
    user: Mapped["User"] = relationship("User", back_populates="memberships")
```

- [ ] **Step 6: Run tests**

Run: `cd backend && pytest tests/test_models.py -v`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: add User and Class models"
```

---

## Task 3: JWT 认证

**Files:**
- Create: `backend/app/core/security.py`
- Create: `backend/app/core/__init__.py`
- Create: `backend/app/schemas/auth.py`
- Create: `backend/app/schemas/user.py`
- Create: `backend/app/api/auth.py`
- Create: `backend/app/api/deps.py`
- Modify: `backend/app/models/user.py` (add verify_password method)

- [ ] **Step 1: Create app/core/security.py**

```python
from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from app.config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire, "type": "access"})
    encoded_jwt = jwt.encode(to_encode, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)
    return encoded_jwt


def create_refresh_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode.update({"exp": expire, "type": "refresh"})
    encoded_jwt = jwt.encode(to_encode, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)
    return encoded_jwt


def decode_token(token: str) -> Optional[dict]:
    try:
        payload = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        return payload
    except JWTError:
        return None
```

- [ ] **Step 2: Create app/schemas/auth.py**

```python
from pydantic import BaseModel


class SendCodeRequest(BaseModel):
    phone: str


class LoginRequest(BaseModel):
    phone: str
    code: str  # 验证码


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class RefreshTokenRequest(BaseModel):
    refresh_token: str
```

- [ ] **Step 3: Create app/schemas/user.py**

```python
from pydantic import BaseModel
from datetime import datetime


class UserBase(BaseModel):
    phone: str


class UserCreate(UserBase):
    password: str


class UserResponse(UserBase):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True
```

- [ ] **Step 4: Create app/api/deps.py**

```python
from typing import Annotated
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.core.security import decode_token
from app.models.user import User

security = HTTPBearer()


async def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(security)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> User:
    token = credentials.credentials
    payload = decode_token(token)

    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
        )

    if payload.get("type") != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token type",
        )

    user_id = payload.get("sub")
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
        )

    from sqlalchemy import select
    result = await db.execute(select(User).where(User.id == int(user_id)))
    user = result.scalar_one_or_none()

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )

    return user
```

- [ ] **Step 5: Create app/api/auth.py**

```python
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.models.user import User
from app.schemas.auth import SendCodeRequest, LoginRequest, TokenResponse, RefreshTokenRequest
from app.schemas.user import UserResponse
from app.core.security import (
    get_password_hash,
    verify_password,
    create_access_token,
    create_refresh_token,
    decode_token,
)

router = APIRouter(prefix="/auth", tags=["auth"])

# 模拟验证码存储 (生产用 Redis)
verification_codes = {}


@router.post("/send_code")
async def send_code(request: SendCodeRequest, db: AsyncSession = Depends(get_db)):
    # 检查用户是否存在，不存在则创建
    result = await db.execute(select(User).where(User.phone == request.phone))
    user = result.scalar_one_or_none()

    if user is None:
        # 自动注册
        user = User(phone=request.phone, password_hash=get_password_hash("123456"))  # 默认密码
        db.add(user)
        await db.commit()
        await db.refresh(user)

    # 生成验证码 (开发环境固定 123456)
    code = "123456"
    verification_codes[request.phone] = code

    return {"message": "Code sent", "code": code}  # 开发环境返回验证码


@router.post("/login", response_model=TokenResponse)
async def login(request: LoginRequest, db: AsyncSession = Depends(get_db)):
    # 验证验证码
    stored_code = verification_codes.get(request.phone)
    if stored_code is None or stored_code != request.code:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid verification code",
        )

    # 获取用户
    result = await db.execute(select(User).where(User.phone == request.phone))
    user = result.scalar_one_or_none()

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    # 生成 Token
    access_token = create_access_token(data={"sub": str(user.id)})
    refresh_token = create_refresh_token(data={"sub": str(user.id)})

    # 清理验证码
    del verification_codes[request.phone]

    return TokenResponse(access_token=access_token, refresh_token=refresh_token)


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(request: RefreshTokenRequest):
    payload = decode_token(request.refresh_token)

    if payload is None or payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token",
        )

    user_id = payload.get("sub")
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UN_REQUEST,
            detail="Invalid refresh token payload",
        )

    access_token = create_access_token(data={"sub": user_id})
    new_refresh_token = create_refresh_token(data={"sub": user_id})

    return TokenResponse(access_token=access_token, refresh_token=new_refresh_token)


@router.get("/me", response_model=UserResponse)
async def get_me(user: User = Depends(get_current_user)):
    return user
```

- [ ] **Step 6: Create app/main.py**

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.database import init_db
from app.api.auth import router as auth_router

app = FastAPI(title="Teacher Tool API")

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup():
    await init_db()


app.include_router(auth_router, prefix="/api/v1")
```

- [ ] **Step 7: Run tests**

Run: `cd backend && pytest -v`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "feat: add JWT authentication system"
```

---

## Task 4: Docker Compose 开发环境

**Files:**
- Create: `backend/deploy/docker-compose.dev.yml`
- Create: `backend/deploy/.env.example`

- [ ] **Step 1: Create docker-compose.dev.yml**

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: teacher_tool
      POSTGRES_PASSWORD: teacher_tool_dev
      POSTGRES_DB: teacher_tool
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

  minio:
    image: minio/minio
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    ports:
      - "9000:9000"
      - "9001:9001"
    volumes:
      - minio_data:/data

volumes:
  postgres_data:
  redis_data:
  minio_data:
```

- [ ] **Step 2: Create .env.example**

```bash
# Database
DATABASE_URL=postgresql+asyncpg://teacher_tool:teacher_tool_dev@localhost:5432/teacher_tool

# Redis
REDIS_URL=redis://localhost:6379/0

# JWT
JWT_SECRET_KEY=change-this-secret-key-in-production
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60
REFRESH_TOKEN_EXPIRE_DAYS=7

# LLM
LLM_PROVIDER=openai
OPENAI_API_KEY=your-api-key
OPENAI_BASE_URL=https://api.openai.com/v1
ANTHROPIC_API_KEY=your-api-key
ANTHROPIC_BASE_URL=https://api.anthropic.com

# Storage (MinIO)
STORAGE_TYPE=minio
MINIO_ENDPOINT=localhost:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_BUCKET=teacher-tool
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: add Docker Compose dev environment"
```

---

## 自检清单

- [ ] 项目结构正确
- [ ] 所有模型可创建
- [ ] 认证流程可运行 (发送验证码 → 登录 → 获取 Token)
- [ ] JWT 验证中间件正常工作
- [ ] Docker Compose 可启动 PostgreSQL, Redis, MinIO
- [ ] 测试通过
