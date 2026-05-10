from contextlib import asynccontextmanager
from pathlib import Path
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from app.database import init_db, close_db
from app.config import settings
from app.api.auth import router as auth_router
from app.api.class_ import router as class_router
from app.api.students import router as students_router
from app.api.grades import router as grades_router
from app.api.seating import router as seating_router
from app.api.schedules import router as schedules_router
from app.api.agent import router as agent_router
from app.api.analytics import router as analytics_router
from app.api.classroom import router as classroom_router
from app.api.dashboard import router as dashboard_router
from app.api.behavior import router as behavior_router

FLUTTER_WEB_DIR = Path(__file__).parent.parent.parent / "flutter_app" / "build" / "web"


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield
    await close_db()


app = FastAPI(title="Teacher Tool API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.BACKEND_CORS_ORIGINS,
    allow_credentials=settings.cors_allow_credentials,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router, prefix="/api/v1")
app.include_router(class_router, prefix="/api/v1")
app.include_router(students_router, prefix="/api/v1")
app.include_router(grades_router, prefix="/api/v1")
app.include_router(seating_router, prefix="/api/v1")
app.include_router(schedules_router, prefix="/api/v1")
app.include_router(agent_router, prefix="/api/v1")
app.include_router(analytics_router, prefix="/api/v1")
app.include_router(classroom_router, prefix="/api/v1")
app.include_router(dashboard_router, prefix="/api/v1")
app.include_router(behavior_router, prefix="/api/v1")


@app.get("/health")
async def health_check():
    from sqlalchemy import text
    from app.database import async_session_maker

    db_ok = True
    try:
        async with async_session_maker() as session:
            await session.execute(text("SELECT 1"))
    except Exception:
        db_ok = False

    status = "healthy" if db_ok else "degraded"
    return {"status": status, "database": "ok" if db_ok else "unreachable"}


# Serve Flutter web build — SPA fallback: unknown routes → index.html
if FLUTTER_WEB_DIR.exists():
    app.mount("/", StaticFiles(directory=str(FLUTTER_WEB_DIR), html=True), name="flutter")
