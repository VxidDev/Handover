import logging
import os
import time
from collections import defaultdict
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text

from .config import UPLOAD_DIR, settings
from .database import Base, engine, run_startup_migrations
from .routers import auth, legal, requests, rooms, safety, skills, uploads, users
from .seed import run as run_seed

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
logger = logging.getLogger("handover")

_rate_limit_store: dict[str, list[float]] = defaultdict(list)
RATE_LIMIT_WINDOW = 60.0
RATE_LIMIT_MAX = int(os.getenv("RATE_LIMIT_MAX", "30"))


def _check_rate_limit(key: str) -> bool:
    now = time.time()
    _rate_limit_store[key] = [
        t for t in _rate_limit_store[key] if now - t < RATE_LIMIT_WINDOW
    ]
    if len(_rate_limit_store[key]) >= RATE_LIMIT_MAX:
        return False
    _rate_limit_store[key].append(now)
    return True


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    run_startup_migrations()
    run_seed()
    logger.info("Handover API started")
    yield
    logger.info("Handover API shutting down")


app = FastAPI(title=settings.APP_NAME, version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)


@app.middleware("http")
async def security_headers(request: Request, call_next):
    response: Response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Strict-Transport-Security"] = (
        "max-age=63072000; includeSubDomains"
    )
    return response


@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    path = request.url.path
    if path.startswith("/api/auth/login") or path.startswith("/api/auth/signup"):
        client_ip = request.client.host if request.client else "unknown"
        key = f"auth:{client_ip}"
        if not _check_rate_limit(key):
            return JSONResponse(
                status_code=429,
                content={"detail": "Too many requests. Please try again later."},
            )
    return await call_next(request)


if settings.ENVIRONMENT == "production":

    @app.middleware("http")
    async def https_redirect(request: Request, call_next):
        if request.headers.get("X-Forwarded-Proto") == "http":
            url = request.url.replace(scheme="https")
            return JSONResponse(status_code=301, headers={"Location": str(url)})
        return await call_next(request)


app.mount("/uploads", StaticFiles(directory=str(UPLOAD_DIR)), name="uploads")

app.include_router(uploads.router, prefix=settings.API_PREFIX)
app.include_router(auth.router, prefix=settings.API_PREFIX)
app.include_router(legal.router, prefix=settings.API_PREFIX)
app.include_router(users.router, prefix=settings.API_PREFIX)
app.include_router(skills.router, prefix=settings.API_PREFIX)
app.include_router(requests.router, prefix=settings.API_PREFIX)
app.include_router(rooms.router, prefix=settings.API_PREFIX)
app.include_router(safety.router, prefix=settings.API_PREFIX)

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
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        db_status = "connected"
    except Exception:
        logger.exception("Database health check failed")
        db_status = "disconnected"

    status_code = 200 if db_status == "connected" else 503
    return JSONResponse(
        status_code=status_code,
        content={
            "status": "ok" if db_status == "connected" else "degraded",
            "app": settings.APP_NAME,
            "db": db_status,
        },
    )
