from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.database import init_db
from app.api.auth import router as auth_router
from app.api.class_ import router as class_router
from app.api.students import router as students_router
from app.api.grades import router as grades_router
from app.api.seating import router as seating_router
from app.api.schedules import router as schedules_router
from app.api.agent import router as agent_router

app = FastAPI(title="Teacher Tool API")

# CORS
# Note: In production, restrict CORS to specific origins
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
app.include_router(class_router, prefix="/api/v1")
app.include_router(students_router, prefix="/api/v1")
app.include_router(grades_router, prefix="/api/v1")
app.include_router(seating_router, prefix="/api/v1")
app.include_router(schedules_router, prefix="/api/v1")
app.include_router(agent_router, prefix="/api/v1")


@app.get("/health")
async def health_check():
    return {"status": "healthy"}
