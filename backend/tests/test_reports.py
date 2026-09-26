from datetime import UTC, datetime, timedelta

from conftest import auth

from app import database
from app.config import settings
from app.models import Report, Skill, User, Warning
from app.routers import reports


def _report_skill(api, token, skill_id, reason="Spam"):
    return api.client.post(
        "/api/reports",
        headers=auth(token),
        json={"content_type": "skill", "content_id": skill_id, "reason": reason},
    )


def test_report_requires_auth(api):
    response = api.client.post(
        "/api/reports",
        json={"content_type": "skill", "content_id": 1, "reason": "Spam"},
    )
    assert response.status_code == 401


def test_report_missing_skill(api):
    response = _report_skill(api, api.requester_token, 9999)
    assert response.status_code == 404


def test_cannot_report_own_skill(api):
    response = _report_skill(api, api.provider_token, api.ids["plumbing_id"])
    assert response.status_code == 400


def test_report_dismisses_safe_content(api, monkeypatch):
    monkeypatch.setattr(reports, "analyze", lambda text: (False, {"toxicity": 0.1}))
    response = _report_skill(api, api.requester_token, api.ids["plumbing_id"])
    assert response.status_code == 201
    body = response.json()
    assert body["status"] == "dismissed"
    assert body["warning_issued"] is False
    assert body["toxicity_score"] == 0.1
    with api.session() as db:
        assert db.query(Warning).count() == 0


def test_cannot_report_same_content_twice(api, monkeypatch):
    monkeypatch.setattr(reports, "analyze", lambda text: (True, {"toxicity": 0.9}))
    first = _report_skill(api, api.requester_token, api.ids["plumbing_id"])
    assert first.status_code == 201

    second = _report_skill(api, api.requester_token, api.ids["plumbing_id"])
    assert second.status_code == 409
    assert "already reported" in second.json()["detail"]

    with api.session() as db:
        assert db.query(Report).count() == 1


def test_report_issues_warning_for_toxic_content(api, monkeypatch):
    monkeypatch.setattr(reports, "analyze", lambda text: (True, {"toxicity": 0.99}))
    response = _report_skill(api, api.requester_token, api.ids["plumbing_id"])
    assert response.status_code == 201
    body = response.json()
    assert body["status"] == "warning_issued"
    assert body["warning_issued"] is True

    with api.session() as db:
        report = db.get(Report, body["id"])
        assert report.status == "warning_issued"
        warning = db.query(Warning).one()
        assert warning.user_id == api.ids["provider_id"]
        assert warning.report_id == report.id


def test_report_chat_message(api, monkeypatch):
    with api.session() as db:
        from app.models import ChatMessage

        message = ChatMessage(
            request_id=1,
            sender_id=api.ids["provider_id"],
            body="A plain message",
        )
        db.add(message)
        db.commit()
        message_id = message.id

    monkeypatch.setattr(reports, "analyze", lambda text: (True, {"toxicity": 0.9}))
    response = api.client.post(
        "/api/reports",
        headers=auth(api.requester_token),
        json={
            "content_type": "chat_message",
            "content_id": message_id,
            "reason": "Rude",
        },
    )
    assert response.status_code == 201
    assert response.json()["warning_issued"] is True


def test_my_reports_lists_only_own(api, monkeypatch):
    monkeypatch.setattr(reports, "analyze", lambda text: (False, {"toxicity": 0.1}))
    _report_skill(api, api.requester_token, api.ids["plumbing_id"])
    _report_skill(api, api.far_token, api.ids["plumbing_id"])

    mine = api.client.get("/api/reports/mine", headers=auth(api.requester_token)).json()
    assert len(mine) == 1
    assert mine[0]["content_id"] == api.ids["plumbing_id"]


def test_warnings_visible_to_warned_user(api, monkeypatch):
    monkeypatch.setattr(reports, "analyze", lambda text: (True, {"toxicity": 0.9}))
    _report_skill(api, api.requester_token, api.ids["plumbing_id"])

    warnings = api.client.get(
        "/api/reports/warnings", headers=auth(api.provider_token)
    ).json()
    assert len(warnings) == 1
    assert warnings[0]["reason"] == "inappropriate post"


def test_expired_warnings_do_not_count(api):
    with api.session() as db:
        db.add_all(
            [
                Warning(
                    user_id=api.ids["provider_id"],
                    report_id=1,
                    reason="inappropriate post",
                    created_at=datetime.now(UTC) - timedelta(days=8),
                )
                for _ in range(15)
            ]
        )
        db.commit()

        provider = db.get(User, api.ids["provider_id"])
        assert reports.active_warning_count(db, provider) == 0


def test_ban_after_more_than_threshold_warnings(api):
    with api.session() as db:
        report = Report(
            reporter_id=api.ids["requester_id"],
            content_type="skill",
            content_id=api.ids["plumbing_id"],
            reason="spam",
            status="warning_issued",
        )
        db.add(report)
        db.flush()
        for _ in range(11):
            db.add(
                Warning(
                    user_id=api.ids["provider_id"],
                    report_id=report.id,
                    reason="inappropriate post",
                )
            )
        db.commit()
        provider = db.get(User, api.ids["provider_id"])
        reports.apply_ban_if_needed(db, provider)
        db.commit()

    with api.session() as db:
        provider = db.get(User, api.ids["provider_id"])
        assert provider.banned_until is not None

    # Authenticated requests are rejected while banned.
    response = api.client.get("/api/users/me", headers=auth(api.provider_token))
    assert response.status_code == 403
    assert "banned" in response.json()["detail"]

    # Login is also rejected while banned.
    login = api.client.post(
        "/api/auth/login",
        json={"email": "provider@example.com", "password": "password"},
    )
    assert login.status_code == 403


def test_ban_cleared_after_expiry(api):
    with api.session() as db:
        provider = db.get(User, api.ids["provider_id"])
        provider.banned_until = datetime.now(UTC) - timedelta(days=1)
        db.commit()

    response = api.client.get("/api/users/me", headers=auth(api.provider_token))
    assert response.status_code == 200
    with api.session() as db:
        provider = db.get(User, api.ids["provider_id"])
        assert provider.banned_until is None


def test_moderator_can_delete_reported_skill(api, monkeypatch):
    monkeypatch.setattr(settings, "SECRET_KEY", "test-moderation-key")
    monkeypatch.setattr(database, "SessionLocal", api.session)
    with api.session() as db:
        report = Report(
            reporter_id=api.ids["requester_id"],
            content_type="skill",
            content_id=api.ids["plumbing_id"],
            reason="Inappropriate",
            status="pending_review",
        )
        db.add(report)
        db.commit()
        report_id = report.id

    response = api.client.post(
        "/admin/moderation/delete-skill?key=test-moderation-key",
        data={"report_id": report_id},
        follow_redirects=False,
    )

    assert response.status_code == 303
    with api.session() as db:
        assert db.get(Skill, api.ids["plumbing_id"]) is None


def test_moderator_cannot_delete_skill_without_secret(api, monkeypatch):
    monkeypatch.setattr(settings, "SECRET_KEY", "test-moderation-key")
    response = api.client.post(
        "/admin/moderation/delete-skill?key=wrong",
        data={"report_id": 1},
    )
    assert response.status_code == 403
