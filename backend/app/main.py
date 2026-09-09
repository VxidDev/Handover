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


# Play Child Safety Standards – required for Social/Dating categories (CSAE). Must be publicly
# reachable without auth, non-editable, not a PDF. Uses legal.py §5A as single source of truth.
@app.get("/child-safety", include_in_schema=False)
@app.get("/handover/child-safety", include_in_schema=False)
@app.get("/safety/child-safety", include_in_schema=False)
def child_safety_page():
    from fastapi.responses import HTMLResponse

    html = """<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Handover — Child Safety Standards</title>
<style>body{font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;max-width:720px;margin:40px auto;padding:0 20px;color:#1a1a1a;line-height:1.65}a{color:#b85c38}h1{font-size:28px}h2{font-size:18px;margin-top:28px}.box{background:#fdf8f3;border:1px solid #f0d9c8;border-radius:12px;padding:16px 20px}li{margin:6px 0}</style>
</head><body>
<h1>Handover — Child Safety Standards</h1>
<p><b>Effective date:</b> 2026-09-01 &nbsp;|&nbsp; Controller: Handover Community, Poland<br>
<b>Designated child safety contact (CSAE):</b> <a href="mailto:support@fvlabs.org">support@fvlabs.org</a> — also reachable at <a href="mailto:void@fvlabs.org">void@fvlabs.org</a> (developer account). This contact is monitored and able to discuss CSAM prevention and compliance with Google Play and law enforcement.</p>
<div class="box">
<h2 style="margin-top:0">Zero tolerance for CSAM/CSAE</h2>
<p>Handover has <b>zero tolerance</b> for child sexual abuse material (CSAM) and any conduct that endangers children. You must not create, upload, store, share, or distribute:</p>
<ul>
<li>CSAM or any sexual content involving minors (including solicitation, acquisition, or distribution)</li>
<li>Grooming, sexualization, or sexual exploitation of a minor, including forming relationships with minors for sexual purposes</li>
<li>Sextortion, trafficking, or employment of minors in sexual services, or predatory behavior toward children</li>
<li>Romantic or sexual relationships between adults and minors, or content that encourages them</li>
</ul>
<p>We prohibit any content that depicts, describes, enables, or encourages the above. See Terms of Service §5A.</p>
</div>
<h2>What we do</h2>
<ul>
<li><b>Remove immediately</b> upon discovery, terminate offending accounts, and cooperate with law enforcement as required</li>
<li><b>Report</b> to the <a href="https://report.cybertip.org/">NCMEC CyberTipline</a> (or your regional authority: <a href="https://support.google.com/websearch/answer/148666">google.com/websearch/answer/148666</a>) when we obtain actual knowledge of CSAM — preserving evidence where legally required</li>
<li><b>Moderate 24/7:</b> in-app <b>Report</b> on every skill and chat message + <b>Block</b> for 1:1 interactions, Detoxify toxicity screening + Hive/Google Vision image checks, human review; violating content hidden within 24 hours, warnings/bans issued</li>
<li><b>Not directed to children:</b> Handover requires age 16+ and is not intended for use by children (Privacy Policy §10)</li>
</ul>
<h2>How to report</h2>
<ul>
<li>In-app: tap <b>Report</b> on any skill or message, or <b>Block</b> a user</li>
<li>Email: <a href="mailto:support@fvlabs.org">support@fvlabs.org</a> (and <a href="mailto:void@fvlabs.org">void@fvlabs.org</a>) with subject “Child safety report”</li>
<li>External: <a href="https://report.cybertip.org/">NCMEC</a> or your local authority</li>
</ul>
<p>We review child-safety reports promptly and comply with all relevant child-safety laws, including reporting to regional and national authorities.</p>
<p><a href="/api/legal">Full legal (API)</a> • <a href="/delete-account">Delete account</a></p>
</body></html>"""
    return HTMLResponse(content=html)


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
