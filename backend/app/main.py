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
    allow_origins=settings.CORS_ORIGINS,
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
app.include_router(legal.router, prefix=settings.API_PREFIX)


# Play Account Deletion – external web resource requirement (must be reachable without auth)
# Serves /delete-account, /handover/delete-account and /account-deletion for flexibility; Play Console + static site use https://fvlabs.org/handover/delete-account and https://fvlabs.org/delete-account
@app.get("/delete-account", include_in_schema=False)
@app.get("/handover/delete-account", include_in_schema=False)
@app.get("/account-deletion", include_in_schema=False)
def delete_account_page():
    from fastapi.responses import HTMLResponse

    html = """<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Delete Your Handover Account</title>
<style>body{font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;max-width:680px;margin:40px auto;padding:0 20px;color:#1a1a1a;line-height:1.6}a{color:#b85c38}code{background:#f5f0ea;padding:2px 6px;border-radius:6px}h1{font-size:28px}h2{font-size:18px;margin-top:28px}.box{background:#fdf8f3;border:1px solid #f0d9c8;border-radius:12px;padding:16px}</style>
</head><body>
<h1>Delete Your Handover Account</h1>
<p>Handover lets you delete your account and all associated data at any time.</p>
<div class="box">
<h2 style="margin-top:0">Option 1 — In the app (fastest)</h2>
<ol><li>Open Handover → <b>Settings</b> → <b>Data &amp; privacy</b> → <b>Delete account</b></li><li>Confirm with your email. All data (profile, skills, messages, images, tips, phone) is hard-deleted immediately; backups purged on schedule.</li></ol>
</div>
<h2>Option 2 — Without logging in (external)</h2>
<p>Email <a href="mailto:support@fvlabs.org">support@fvlabs.org</a> from your registered email address with subject <code>Delete my account</code>. Include your account email. We verify ownership and delete within <b>7 days</b>.</p>
<p><b>What is deleted:</b> name, email, encrypted phone, location/grid, skills, requests, chat messages, images (<code>/uploads/</code>), ratings, tips, blocks, reports. FERNET-encrypted phone becomes unrecoverable after row deletion.</p>
<p><b>Retention:</b> We retain no identifiable data after deletion unless law requires (e.g., fraud prevention). See Privacy Policy §6.</p>
<p>Questions: <a href="mailto:support@fvlabs.org">support@fvlabs.org</a> — Controller: Handover Community, Poland — Child safety: <a href="mailto:support@fvlabs.org">support@fvlabs.org</a></p>
<p><a href="/api/legal">API: /api/legal</a> • <a href="/api/legal/account-deletion">/api/legal/account-deletion</a></p>
</body></html>"""
    return HTMLResponse(content=html)


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
