from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .config import UPLOAD_DIR, settings
from .database import Base, engine, run_startup_migrations
from .routers import (
    auth,
    legal,
    notifications,
    onesignal,
    reports,
    requests,
    rooms,
    safety,
    skills,
    tips,
    uploads,
    users,
)
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
<li><b>Moderate:</b> in-app <b>Report</b> on every skill and chat message + <b>Block</b> for 1:1 interactions; Detoxify toxicity screening for text + structural image validation (magic-byte/Pillow/5 MB cap); violating content hidden upon report, warnings/bans issued. Reports requiring manual review are queued at <a href="/admin/moderation">/admin/moderation</a> (admin access)</li>
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


@app.get("/admin/moderation", include_in_schema=False)
def moderation_queue(request: __import__("fastapi").Request):
    from fastapi import HTTPException as _HE
    from fastapi.responses import HTMLResponse as _HR

    # Simple gate — ?key=SECRET_KEY (SECRET_KEY from backend/.env). Keeps the queue private
    # without needing a full admin login.
    from .config import settings as _settings

    if request.query_params.get("key") != _settings.SECRET_KEY:
        raise _HE(status_code=403, detail="Forbidden — provide ?key=SECRET_KEY")

    # inline to avoid circular import at top
    from sqlalchemy.orm import Session

    from .database import SessionLocal
    from .models import (
        ChatMessage as _CM,
    )
    from .models import (
        Report as _Report,
    )  # noqa
    from .models import (
        Skill as _Skill,
    )
    from .models import (
        User as _User,
    )

    db: Session = SessionLocal()
    try:
        reports = db.query(_Report).order_by(_Report.created_at.desc()).limit(100).all()
        # preload content previews
        rows_html = ""
        for r in reports:
            preview = ""
            try:
                if r.content_type == "skill":
                    s = db.get(_Skill, r.content_id)
                    preview = f"{s.name} — {s.blurb[:80]}" if s else "(deleted)"
                elif r.content_type == "chat_message":
                    m = db.get(_CM, r.content_id)
                    preview = m.body[:100] if m else "(deleted)"
                else:
                    preview = f"user {r.reported_id}"
            except Exception:
                preview = "—"
            # reporter name
            reporter = db.get(_User, r.reporter_id)
            reporter_label = reporter.email if reporter else str(r.reporter_id)
            color = {
                "pending_review": "#b7791f",
                "warning_issued": "#c53030",
                "dismissed": "#38a169",
            }.get(r.status or "", "#555")
            # resolve owner id for ban action
            owner_id = None
            try:
                if r.content_type == "skill":
                    s = db.get(_Skill, r.content_id)
                    owner_id = s.user_id if s else None
                elif r.content_type == "chat_message":
                    m = db.get(_CM, r.content_id)
                    owner_id = m.sender_id if m else None
                else:
                    owner_id = r.reported_id
            except Exception:
                pass
            key = request.query_params.get("key") or ""
            actions = ""
            if owner_id:
                actions = f"""<form method="post" action="/admin/moderation/ban?key={key}" style="display:inline"><input type="hidden" name="user_id" value="{owner_id}"><input type="hidden" name="report_id" value="{r.id}"><button style="background:#c53030;color:#fff;border:0;padding:4px 8px;border-radius:6px;cursor:pointer;font-size:12px">Ban 7d</button></form> <form method="post" action="/admin/moderation/dismiss?key={key}" style="display:inline"><input type="hidden" name="report_id" value="{r.id}"><button style="background:#718096;color:#fff;border:0;padding:4px 8px;border-radius:6px;cursor:pointer;font-size:12px">Dismiss</button></form>"""
            if r.content_type == "skill":
                actions += f""" <form method="post" action="/admin/moderation/delete-skill?key={key}" style="display:inline" onsubmit="return confirm('Permanently delete this skill post?')"><input type="hidden" name="report_id" value="{r.id}"><button style="background:#742a2a;color:#fff;border:0;padding:4px 8px;border-radius:6px;cursor:pointer;font-size:12px">Delete post</button></form>"""
            rows_html += f"<tr><td>{r.id}</td><td>{r.content_type or 'user'}</td><td>{r.content_id or r.reported_id or '—'}</td><td style='max-width:220px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap' title='{preview}'>{preview}</td><td>{reporter_label}</td><td>{r.reason[:30]}</td><td><span style='background:{color};color:#fff;padding:2px 8px;border-radius:999px;font-size:12px'>{r.status}</span></td><td>{round(r.toxicity_score, 3) if r.toxicity_score is not None else '—'}</td><td>{r.created_at.strftime('%m-%d %H:%M') if r.created_at else ''}</td><td>{actions}</td></tr>"
        if not rows_html:
            rows_html = "<tr><td colspan=10 style='text-align:center;color:#777;padding:24px'>No reports yet — queue is empty.</td></tr>"
        html = f"""<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Handover — Moderation Queue</title>
<style>body{{font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;max-width:1100px;margin:32px auto;padding:0 16px;color:#1a1a1a;line-height:1.5}}table{{width:100%;border-collapse:collapse;font-size:13px}}th,td{{text-align:left;padding:8px 10px;border-bottom:1px solid #eee}}th{{background:#fdf8f3;font-weight:600}}a{{color:#b85c38}}.badge{{display:inline-block}}.muted{{color:#777;font-size:12px}}</style>
</head><body>
<h1>Moderation queue</h1>
<p class="muted">Internal — {len(reports)} most recent reports. Auto-hidden content is already removed from search/chat (<code>is_hidden</code>); use this queue to review <code>pending_review</code> and act. Append <code>?key=SECRET_KEY</code> to keep access (from <code>backend/.env</code>).</p>
<table><thead><tr><th>#</th><th>Type</th><th>ID</th><th>Content preview</th><th>Reporter</th><th>Reason</th><th>Status</th><th>Toxicity</th><th>When</th><th>Actions</th></tr></thead><tbody>{rows_html}</tbody></table>
<p style="margin-top:20px"><a href="/child-safety">Child Safety Standards</a> • <a href="/api/reports/mine">My reports (API)</a> • <a href="/health">Health</a></p>
</body></html>"""
        return _HR(content=html)
    finally:
        db.close()


@app.post("/admin/moderation/ban", include_in_schema=False)
def moderation_ban(
    request: __import__("fastapi").Request,
    user_id: int = __import__("fastapi").Form(...),
    report_id: int = __import__("fastapi").Form(...),
):
    from datetime import UTC, datetime, timedelta

    from fastapi import HTTPException as _HE
    from fastapi.responses import RedirectResponse as _RR

    from .config import settings as _settings

    if request.query_params.get("key") != _settings.SECRET_KEY:
        raise _HE(status_code=403, detail="Forbidden")
    from .database import SessionLocal
    from .models import Report as _Report
    from .models import User as _User
    from .models import Warning as _Warning

    db = SessionLocal()
    try:
        u = db.get(_User, user_id)
        if u:
            u.banned_until = datetime.now(UTC) + timedelta(
                days=_settings.WARNING_BAN_DURATION_DAYS
            )
            db.add(u)
            r = db.get(_Report, report_id)
            if r:
                r.status = "warning_issued"
                db.add(r)
                db.add(
                    _Warning(
                        user_id=u.id,
                        report_id=r.id,
                        reason="manual ban from moderation queue",
                    )
                )
            db.commit()
    finally:
        db.close()
    key = request.query_params.get("key") or ""
    return _RR(url=f"/admin/moderation?key={key}", status_code=303)


@app.post("/admin/moderation/dismiss", include_in_schema=False)
def moderation_dismiss(
    request: __import__("fastapi").Request,
    report_id: int = __import__("fastapi").Form(...),
):
    from fastapi import HTTPException as _HE
    from fastapi.responses import RedirectResponse as _RR

    from .config import settings as _settings

    if request.query_params.get("key") != _settings.SECRET_KEY:
        raise _HE(status_code=403, detail="Forbidden")
    from .database import SessionLocal
    from .models import Report as _Report

    db = SessionLocal()
    try:
        r = db.get(_Report, report_id)
        if r:
            r.status = "dismissed"
            db.add(r)
            db.commit()
    finally:
        db.close()
    key = request.query_params.get("key") or ""
    return _RR(url=f"/admin/moderation?key={key}", status_code=303)


@app.post("/admin/moderation/delete-skill", include_in_schema=False)
def moderation_delete_skill(
    request: __import__("fastapi").Request,
    report_id: int = __import__("fastapi").Form(...),
):
    from fastapi import HTTPException as _HE
    from fastapi.responses import RedirectResponse as _RR

    from .config import settings as _settings

    key = request.query_params.get("key") or ""
    if key != _settings.SECRET_KEY:
        raise _HE(status_code=403, detail="Forbidden")

    from .cache import SKILLS_CATALOG_KEY, cache
    from .database import SessionLocal
    from .models import Report as _Report
    from .models import Skill as _Skill

    db = SessionLocal()
    try:
        report = db.get(_Report, report_id)
        if report is None or report.content_type != "skill":
            raise _HE(status_code=404, detail="Skill report not found")
        skill = db.get(_Skill, report.content_id)
        if skill is not None:
            db.delete(skill)
            db.commit()
            cache.delete(SKILLS_CATALOG_KEY)
    finally:
        db.close()
    return _RR(url=f"/admin/moderation?key={key}", status_code=303)


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
