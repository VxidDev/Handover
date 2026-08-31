from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .config import UPLOAD_DIR, settings
from .database import Base, engine, run_startup_migrations
from .routers import auth, legal, notifications, onesignal, reports, requests, rooms, safety, skills, tips, uploads, users
from .seed import run as run_seed


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    run_startup_migrations()
    run_seed()
    # Warm up detoxify in background — first /reports call otherwise blocks 3-8s downloading/loading model
    try:
        import threading

        from .moderation import get_model

        threading.Thread(target=get_model, daemon=True).start()
    except Exception:
        pass
    yield


app = FastAPI(title=settings.APP_NAME, version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/uploads", StaticFiles(directory=str(UPLOAD_DIR)), name="uploads")

app.include_router(uploads.router, prefix=settings.API_PREFIX)
app.include_router(auth.router, prefix=settings.API_PREFIX)
app.include_router(users.router, prefix=settings.API_PREFIX)
app.include_router(skills.router, prefix=settings.API_PREFIX)
app.include_router(requests.router, prefix=settings.API_PREFIX)
app.include_router(rooms.router, prefix=settings.API_PREFIX)
app.include_router(reports.router, prefix=settings.API_PREFIX)
app.include_router(notifications.router, prefix=settings.API_PREFIX)
app.include_router(onesignal.router, prefix=settings.API_PREFIX)
app.include_router(safety.router, prefix=settings.API_PREFIX)
app.include_router(tips.router, prefix=settings.API_PREFIX)

if settings.ENVIRONMENT != "production":
    from fastapi.openapi.docs import get_redoc_html, get_swagger_ui_html

    @app.get("/docs", include_in_schema=False)
    async def swagger_ui():
        return get_swagger_ui_html(
            openapi_url=app.openapi_url,
            title=f"{settings.APP_NAME} - Swagger UI",
        )

    @app.get("/redoc", include_in_schema=False)
    async def redoc_ui():
        return get_redoc_html(
            openapi_url=app.openapi_url,
            title=f"{settings.APP_NAME} - ReDoc",
        )


@app.get("/health", tags=["meta"])
def health():
    return {"status": "ok", "app": settings.APP_NAME}
