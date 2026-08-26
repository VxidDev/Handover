import hashlib
import secrets
from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, patch

from conftest import auth

from app.models import (
    BlockedUser,
    ChatMessage,
    PasswordResetToken,
    Rating,
    Report,
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _accept_request(api, request_id: int) -> dict:
    return api.client.patch(
        f"/api/requests/{request_id}",
        headers=auth(api.provider_token),
        json={"status": "accepted", "share_phone": False},
    ).json()


def _complete_request(api, request_id: int) -> dict:
    _accept_request(api, request_id)
    return api.client.patch(
        f"/api/requests/{request_id}",
        headers=auth(api.requester_token),
        json={"status": "completed"},
    ).json()


def _create_request(api, skill_key: str = "plumbing_id") -> dict:
    return api.client.post(
        "/api/requests",
        headers=auth(api.requester_token),
        json={"skill_id": api.ids[skill_key], "message": "Help needed"},
    ).json()


# ===========================================================================
# Forgot / Reset Password
# ===========================================================================


class TestForgotPassword:
    def test_forgot_password_sends_email_for_existing_user(self, api):
        mock_send = AsyncMock()
        with patch("app.routers.auth.send_password_reset_email", mock_send):
            resp = api.client.post(
                "/api/auth/forgot-password",
                json={"email": "provider@example.com"},
            )
        assert resp.status_code == 200
        body = resp.json()
        assert body["message"] == "If the email exists, a reset link has been sent"
        assert "token" not in body
        mock_send.assert_called_once()
        args = mock_send.call_args
        assert args[0][0] == "provider@example.com"

    def test_forgot_password_for_unknown_email_returns_same_message(self, api):
        mock_send = AsyncMock()
        with patch("app.routers.auth.send_password_reset_email", mock_send):
            resp = api.client.post(
                "/api/auth/forgot-password",
                json={"email": "nobody@example.com"},
            )
        assert resp.status_code == 200
        body = resp.json()
        assert "token" not in body
        assert "If the email exists" in body["message"]
        mock_send.assert_not_called()

    def test_forgot_password_rejects_invalid_email(self, api):
        resp = api.client.post(
            "/api/auth/forgot-password",
            json={"email": "not-an-email"},
        )
        assert resp.status_code == 422

    def test_reset_password_succeeds_with_valid_token(self, api):
        mock_send = AsyncMock()
        with patch("app.routers.auth.send_password_reset_email", mock_send):
            api.client.post(
                "/api/auth/forgot-password",
                json={"email": "provider@example.com"},
            )
        raw_token = mock_send.call_args[0][1]

        resp = api.client.post(
            "/api/auth/reset-password",
            json={"token": raw_token, "new_password": "newpass123"},
        )
        assert resp.status_code == 200
        assert resp.json()["message"] == "Password has been reset"

        login = api.client.post(
            "/api/auth/login",
            json={"email": "provider@example.com", "password": "newpass123"},
        )
        assert login.status_code == 200

    def test_reset_password_rejects_old_password(self, api):
        mock_send = AsyncMock()
        with patch("app.routers.auth.send_password_reset_email", mock_send):
            api.client.post(
                "/api/auth/forgot-password",
                json={"email": "provider@example.com"},
            )
        raw_token = mock_send.call_args[0][1]

        api.client.post(
            "/api/auth/reset-password",
            json={"token": raw_token, "new_password": "newpass123"},
        )
        login = api.client.post(
            "/api/auth/login",
            json={"email": "provider@example.com", "password": "password"},
        )
        assert login.status_code == 401

    def test_reset_password_rejects_used_token(self, api):
        mock_send = AsyncMock()
        with patch("app.routers.auth.send_password_reset_email", mock_send):
            api.client.post(
                "/api/auth/forgot-password",
                json={"email": "provider@example.com"},
            )
        raw_token = mock_send.call_args[0][1]

        api.client.post(
            "/api/auth/reset-password",
            json={"token": raw_token, "new_password": "newpass123"},
        )
        resp = api.client.post(
            "/api/auth/reset-password",
            json={"token": raw_token, "new_password": "anotherpass"},
        )
        assert resp.status_code == 400

    def test_reset_password_rejects_invalid_token(self, api):
        resp = api.client.post(
            "/api/auth/reset-password",
            json={"token": "bogus-token", "new_password": "newpass123"},
        )
        assert resp.status_code == 400

    def test_reset_password_rejects_expired_token(self, api):
        from app.models import User as UserModel

        with api.session() as db:
            user = db.query(UserModel).filter_by(email="provider@example.com").first()
            raw_token = secrets.token_urlsafe(32)
            token_hash = hashlib.sha256(raw_token.encode()).hexdigest()
            db.add(
                PasswordResetToken(
                    user_id=user.id,
                    token_hash=token_hash,
                    expires_at=datetime.now(UTC) - timedelta(hours=1),
                )
            )
            db.commit()

        resp = api.client.post(
            "/api/auth/reset-password",
            json={"token": raw_token, "new_password": "newpass123"},
        )
        assert resp.status_code == 400

    def test_reset_password_rejects_short_password(self, api):
        mock_send = AsyncMock()
        with patch("app.routers.auth.send_password_reset_email", mock_send):
            api.client.post(
                "/api/auth/forgot-password",
                json={"email": "provider@example.com"},
            )
        raw_token = mock_send.call_args[0][1]

        resp = api.client.post(
            "/api/auth/reset-password",
            json={"token": raw_token, "new_password": "short"},
        )
        assert resp.status_code == 422


# ===========================================================================
# User Reporting / Blocking
# ===========================================================================


class TestReporting:
    def test_report_user(self, api):
        resp = api.client.post(
            "/api/safety/report",
            headers=auth(api.requester_token),
            json={
                "reported_id": api.ids["provider_id"],
                "reason": "Spam",
            },
        )
        assert resp.status_code == 201
        assert resp.json()["message"] == "Report submitted"

    def test_report_with_details(self, api):
        resp = api.client.post(
            "/api/safety/report",
            headers=auth(api.requester_token),
            json={
                "reported_id": api.ids["provider_id"],
                "reason": "Harassment",
                "details": "Send inappropriate messages",
            },
        )
        assert resp.status_code == 201

    def test_report_self_rejected(self, api):
        resp = api.client.post(
            "/api/safety/report",
            headers=auth(api.requester_token),
            json={
                "reported_id": api.ids["requester_id"],
                "reason": "Spam",
            },
        )
        assert resp.status_code == 400

    def test_report_nonexistent_user(self, api):
        resp = api.client.post(
            "/api/safety/report",
            headers=auth(api.requester_token),
            json={"reported_id": 99999, "reason": "Spam"},
        )
        assert resp.status_code == 404

    def test_report_stored_in_database(self, api):
        api.client.post(
            "/api/safety/report",
            headers=auth(api.requester_token),
            json={
                "reported_id": api.ids["provider_id"],
                "reason": "Fake profile",
            },
        )
        with api.session() as db:
            report = db.query(Report).first()
            assert report is not None
            assert report.reporter_id == api.ids["requester_id"]
            assert report.reported_id == api.ids["provider_id"]
            assert report.reason == "Fake profile"

    def test_requires_authentication(self, api):
        resp = api.client.post(
            "/api/safety/report",
            json={"reported_id": 1, "reason": "Spam"},
        )
        assert resp.status_code == 401


class TestBlocking:
    def test_block_user(self, api):
        resp = api.client.post(
            "/api/safety/block",
            headers=auth(api.requester_token),
            json={"blocked_id": api.ids["provider_id"]},
        )
        assert resp.status_code == 201
        assert resp.json()["message"] == "User blocked"

    def test_block_self_rejected(self, api):
        resp = api.client.post(
            "/api/safety/block",
            headers=auth(api.requester_token),
            json={"blocked_id": api.ids["requester_id"]},
        )
        assert resp.status_code == 400

    def test_block_nonexistent_user(self, api):
        resp = api.client.post(
            "/api/safety/block",
            headers=auth(api.requester_token),
            json={"blocked_id": 99999},
        )
        assert resp.status_code == 404

    def test_block_already_blocked(self, api):
        api.client.post(
            "/api/safety/block",
            headers=auth(api.requester_token),
            json={"blocked_id": api.ids["provider_id"]},
        )
        resp = api.client.post(
            "/api/safety/block",
            headers=auth(api.requester_token),
            json={"blocked_id": api.ids["provider_id"]},
        )
        assert resp.status_code == 201
        assert resp.json()["message"] == "Already blocked"

    def test_block_stored_in_database(self, api):
        api.client.post(
            "/api/safety/block",
            headers=auth(api.requester_token),
            json={"blocked_id": api.ids["provider_id"]},
        )
        with api.session() as db:
            block = db.query(BlockedUser).first()
            assert block is not None
            assert block.blocker_id == api.ids["requester_id"]
            assert block.blocked_id == api.ids["provider_id"]

    def test_unblock_user(self, api):
        api.client.post(
            "/api/safety/block",
            headers=auth(api.requester_token),
            json={"blocked_id": api.ids["provider_id"]},
        )
        resp = api.client.post(
            "/api/safety/unblock",
            headers=auth(api.requester_token),
            json={"blocked_id": api.ids["provider_id"]},
        )
        assert resp.status_code == 204
        with api.session() as db:
            block = db.query(BlockedUser).first()
            assert block is None

    def test_unblock_nonexistent_block(self, api):
        resp = api.client.post(
            "/api/safety/unblock",
            headers=auth(api.requester_token),
            json={"blocked_id": api.ids["provider_id"]},
        )
        assert resp.status_code == 204

    def test_block_requires_authentication(self, api):
        resp = api.client.post(
            "/api/safety/block",
            json={"blocked_id": 1},
        )
        assert resp.status_code == 401


# ===========================================================================
# Rating System
# ===========================================================================


class TestRating:
    def test_rate_completed_request(self, api):
        req = _create_request(api)
        _complete_request(api, req["id"])

        resp = api.client.post(
            f"/api/requests/{req['id']}/rate",
            headers=auth(api.requester_token),
            json={"stars": 5, "review": "Great help!"},
        )
        assert resp.status_code == 201
        body = resp.json()
        assert body["stars"] == 5
        assert body["review"] == "Great help!"
        assert body["rater_id"] == api.ids["requester_id"]
        assert body["rated_id"] == api.ids["provider_id"]

    def test_rate_without_review(self, api):
        req = _create_request(api)
        _complete_request(api, req["id"])

        resp = api.client.post(
            f"/api/requests/{req['id']}/rate",
            headers=auth(api.requester_token),
            json={"stars": 4},
        )
        assert resp.status_code == 201
        assert resp.json()["review"] is None

    def test_rate_by_provider(self, api):
        req = _create_request(api)
        _complete_request(api, req["id"])

        resp = api.client.post(
            f"/api/requests/{req['id']}/rate",
            headers=auth(api.provider_token),
            json={"stars": 3},
        )
        assert resp.status_code == 201
        assert resp.json()["rated_id"] == api.ids["requester_id"]

    def test_cannot_rate_pending_request(self, api):
        req = _create_request(api)
        resp = api.client.post(
            f"/api/requests/{req['id']}/rate",
            headers=auth(api.requester_token),
            json={"stars": 5},
        )
        assert resp.status_code == 409

    def test_cannot_rate_twice(self, api):
        req = _create_request(api)
        _complete_request(api, req["id"])
        api.client.post(
            f"/api/requests/{req['id']}/rate",
            headers=auth(api.requester_token),
            json={"stars": 5},
        )
        resp = api.client.post(
            f"/api/requests/{req['id']}/rate",
            headers=auth(api.requester_token),
            json={"stars": 4},
        )
        assert resp.status_code == 409

    def test_non_participant_cannot_rate(self, api):
        req = _create_request(api)
        _complete_request(api, req["id"])
        resp = api.client.post(
            f"/api/requests/{req['id']}/rate",
            headers=auth(api.far_token),
            json={"stars": 5},
        )
        assert resp.status_code == 403

    def test_rate_nonexistent_request(self, api):
        resp = api.client.post(
            "/api/requests/99999/rate",
            headers=auth(api.requester_token),
            json={"stars": 5},
        )
        assert resp.status_code == 404

    def test_rate_rejects_invalid_stars(self, api):
        req = _create_request(api)
        _complete_request(api, req["id"])
        resp = api.client.post(
            f"/api/requests/{req['id']}/rate",
            headers=auth(api.requester_token),
            json={"stars": 6},
        )
        assert resp.status_code == 422
        resp = api.client.post(
            f"/api/requests/{req['id']}/rate",
            headers=auth(api.requester_token),
            json={"stars": 0},
        )
        assert resp.status_code == 422

    def test_rating_stored_in_database(self, api):
        req = _create_request(api)
        _complete_request(api, req["id"])
        api.client.post(
            f"/api/requests/{req['id']}/rate",
            headers=auth(api.requester_token),
            json={"stars": 5, "review": "Excellent"},
        )
        with api.session() as db:
            rating = db.query(Rating).first()
            assert rating is not None
            assert rating.stars == 5
            assert rating.review == "Excellent"
            assert rating.request_id == req["id"]

    def test_rate_requires_authentication(self, api):
        resp = api.client.post(
            "/api/requests/1/rate",
            json={"stars": 5},
        )
        assert resp.status_code == 401


# ===========================================================================
# Search Filters
# ===========================================================================


class TestSearchFilters:
    def test_available_filter_true(self, api):
        resp = api.client.get("/api/skills", params={"available": "true"})
        names = {s["skill_name"] for s in resp.json()}
        assert "Yoga" in names
        assert "Plumbing" in names

    def test_available_filter_excludes_unavailable(self, api):
        api.client.patch(
            "/api/users/me",
            headers=auth(api.provider_token),
            json={"is_available": False},
        )
        from app.routers.skills import invalidate_catalog

        invalidate_catalog()
        resp = api.client.get("/api/skills", params={"available": "true"})
        names = {s["skill_name"] for s in resp.json()}
        assert "Plumbing" not in names
        assert "Yoga" in names

    def test_sort_by_karma(self, api):
        resp = api.client.get(
            "/api/skills",
            params={"sort": "karma"},
        )
        results = resp.json()
        karmas = [r["karma"] for r in results]
        assert karmas == sorted(karmas, reverse=True)

    def test_sort_by_name(self, api):
        resp = api.client.get(
            "/api/skills",
            params={"sort": "name"},
        )
        results = resp.json()
        names = [r["skill_name"].lower() for r in results]
        assert names == sorted(names)

    def test_sort_by_distance_requires_coords(self, api):
        resp = api.client.get(
            "/api/skills",
            params={
                "lat": 37.7849,
                "lng": -122.4295,
                "sort": "distance",
            },
        )
        results = resp.json()
        distances = [r["distance_km"] for r in results if r["distance_km"] is not None]
        assert distances == sorted(distances)

    def test_sort_invalid_value_rejected(self, api):
        resp = api.client.get("/api/skills", params={"sort": "invalid"})
        assert resp.status_code == 422

    def test_combined_filters(self, api):
        api.client.patch(
            "/api/users/me",
            headers=auth(api.far_token),
            json={"is_available": False},
        )
        from app.routers.skills import invalidate_catalog

        invalidate_catalog()
        resp = api.client.get(
            "/api/skills",
            params={"available": "true", "sort": "name"},
        )
        for r in resp.json():
            assert r["available"] is True


# ===========================================================================
# Request Pagination
# ===========================================================================


class TestRequestPagination:
    def test_offset_skips_results(self, api):
        for _ in range(3):
            api.client.post(
                "/api/requests",
                headers=auth(api.requester_token),
                json={"skill_id": api.ids["plumbing_id"]},
            )
        all_reqs = api.client.get(
            "/api/requests",
            params={"role": "sent"},
            headers=auth(api.requester_token),
        ).json()
        assert len(all_reqs) == 3

        page = api.client.get(
            "/api/requests",
            params={"role": "sent", "offset": 1, "amount": 10},
            headers=auth(api.requester_token),
        ).json()
        assert len(page) == 2

    def test_amount_limits_results(self, api):
        for _ in range(5):
            api.client.post(
                "/api/requests",
                headers=auth(api.requester_token),
                json={"skill_id": api.ids["plumbing_id"]},
            )
        page = api.client.get(
            "/api/requests",
            params={"role": "sent", "amount": 2},
            headers=auth(api.requester_token),
        ).json()
        assert len(page) == 2


# ===========================================================================
# Unread Message Tracking
# ===========================================================================


class TestUnreadTracking:
    def _setup_chat(self, api):
        req = _create_request(api)
        _accept_request(api, req["id"])
        return req

    def test_mark_read(self, api):
        req = self._setup_chat(api)
        with api.session() as db:
            db.add(
                ChatMessage(
                    request_id=req["id"],
                    sender_id=api.ids["provider_id"],
                    body="Hello",
                )
            )
            db.commit()

        resp = api.client.post(
            f"/api/requests/{req['id']}/read",
            headers=auth(api.requester_token),
        )
        assert resp.status_code == 200
        assert resp.json()["last_read_message_id"] > 0

    def test_unread_counts(self, api):
        req = self._setup_chat(api)
        with api.session() as db:
            db.add(
                ChatMessage(
                    request_id=req["id"],
                    sender_id=api.ids["provider_id"],
                    body="Hello",
                )
            )
            db.commit()

        resp = api.client.get(
            "/api/requests/unread-counts",
            headers=auth(api.requester_token),
        )
        assert resp.status_code == 200
        counts = resp.json()["counts"]
        assert str(req["id"]) in counts
        assert counts[str(req["id"])] == 1

    def test_unread_count_zero_after_read(self, api):
        req = self._setup_chat(api)
        with api.session() as db:
            db.add(
                ChatMessage(
                    request_id=req["id"],
                    sender_id=api.ids["provider_id"],
                    body="Hello",
                )
            )
            db.commit()

        api.client.post(
            f"/api/requests/{req['id']}/read",
            headers=auth(api.requester_token),
        )
        resp = api.client.get(
            "/api/requests/unread-counts",
            headers=auth(api.requester_token),
        )
        counts = resp.json()["counts"]
        assert str(req["id"]) not in counts

    def test_own_messages_not_counted_as_unread(self, api):
        req = self._setup_chat(api)
        with api.session() as db:
            db.add(
                ChatMessage(
                    request_id=req["id"],
                    sender_id=api.ids["requester_id"],
                    body="I sent this",
                )
            )
            db.commit()

        resp = api.client.get(
            "/api/requests/unread-counts",
            headers=auth(api.requester_token),
        )
        counts = resp.json()["counts"]
        assert str(req["id"]) not in counts

    def test_mark_read_requires_participant(self, api):
        req = self._setup_chat(api)
        resp = api.client.post(
            f"/api/requests/{req['id']}/read",
            headers=auth(api.far_token),
        )
        assert resp.status_code == 403


# ===========================================================================
# Conversations Endpoint
# ===========================================================================


class TestConversations:
    def _setup_chat(self, api):
        req = _create_request(api)
        _accept_request(api, req["id"])
        with api.session() as db:
            db.add(
                ChatMessage(
                    request_id=req["id"],
                    sender_id=api.ids["provider_id"],
                    body="Hey there",
                )
            )
            db.commit()
        return req

    def test_conversations_returns_accepted_requests(self, api):
        req = self._setup_chat(api)
        resp = api.client.get(
            "/api/requests/conversations",
            headers=auth(api.requester_token),
        )
        assert resp.status_code == 200
        convos = resp.json()
        assert len(convos) >= 1
        ids = [c["id"] for c in convos]
        assert req["id"] in ids

    def test_conversations_includes_last_message(self, api):
        req = self._setup_chat(api)
        resp = api.client.get(
            "/api/requests/conversations",
            headers=auth(api.requester_token),
        )
        convo = next(c for c in resp.json() if c["id"] == req["id"])
        assert convo["last_message"] is not None
        assert convo["last_message"]["body"] == "Hey there"

    def test_conversations_includes_unread_count(self, api):
        req = self._setup_chat(api)
        resp = api.client.get(
            "/api/requests/conversations",
            headers=auth(api.requester_token),
        )
        convo = next(c for c in resp.json() if c["id"] == req["id"])
        assert convo["unread_count"] == 1

    def test_conversations_excludes_pending_requests(self, api):
        _create_request(api)
        resp = api.client.get(
            "/api/requests/conversations",
            headers=auth(api.requester_token),
        )
        assert len(resp.json()) == 0

    def test_conversations_sorted_by_last_message(self, api):
        self._setup_chat(api)
        req2_id = api.client.post(
            "/api/requests",
            headers=auth(api.requester_token),
            json={"skill_id": api.ids["yoga_id"]},
        ).json()["id"]
        api.client.patch(
            f"/api/requests/{req2_id}",
            headers=auth(api.far_token),
            json={"status": "accepted", "share_phone": False},
        )
        with api.session() as db:
            db.add(
                ChatMessage(
                    request_id=req2_id,
                    sender_id=api.ids["far_id"],
                    body="Later message",
                )
            )
            db.commit()

        resp = api.client.get(
            "/api/requests/conversations",
            headers=auth(api.requester_token),
        )
        convos = resp.json()
        assert len(convos) >= 2
        assert convos[0]["id"] == req2_id


# ===========================================================================
# Image Messages
# ===========================================================================


class TestImageMessages:
    def test_websocket_image_message(self, api):
        req = _create_request(api)
        _accept_request(api, req["id"])
        token = api.client.post(
            f"/api/requests/{req['id']}/room-token",
            headers=auth(api.requester_token),
        ).json()["token"]

        with api.client.websocket_connect(
            f"/api/requests/{req['id']}/chat?token={token}"
        ) as ws:
            ws.receive_json()
            ws.send_json(
                {
                    "type": "message",
                    "body": "",
                    "image_url": "/uploads/test.jpg",
                }
            )
            event = ws.receive_json()
            assert event["type"] == "message"
            assert event["message"]["image_url"] == "/uploads/test.jpg"
            assert event["message"]["body"] == ""

    def test_websocket_empty_message_and_no_image_rejected(self, api):
        req = _create_request(api)
        _accept_request(api, req["id"])
        token = api.client.post(
            f"/api/requests/{req['id']}/room-token",
            headers=auth(api.requester_token),
        ).json()["token"]

        with api.client.websocket_connect(
            f"/api/requests/{req['id']}/chat?token={token}"
        ) as ws:
            ws.receive_json()
            ws.send_json({"type": "message", "body": ""})
            event = ws.receive_json()
            assert event["type"] == "error"
            assert "body or image_url" in event["detail"]

    def test_image_url_too_long_rejected(self, api):
        req = _create_request(api)
        _accept_request(api, req["id"])
        token = api.client.post(
            f"/api/requests/{req['id']}/room-token",
            headers=auth(api.requester_token),
        ).json()["token"]

        with api.client.websocket_connect(
            f"/api/requests/{req['id']}/chat?token={token}"
        ) as ws:
            ws.receive_json()
            ws.send_json(
                {
                    "type": "message",
                    "body": "",
                    "image_url": "/uploads/" + "x" * 500 + ".jpg",
                }
            )
            event = ws.receive_json()
            assert event["type"] == "error"
            assert "image_url too long" in event["detail"]

    def test_image_message_in_history(self, api):
        req = _create_request(api)
        _accept_request(api, req["id"])
        with api.session() as db:
            db.add(
                ChatMessage(
                    request_id=req["id"],
                    sender_id=api.ids["requester_id"],
                    body="",
                    image_url="/uploads/photo.jpg",
                )
            )
            db.commit()

        resp = api.client.get(
            f"/api/requests/{req['id']}/messages",
            headers=auth(api.requester_token),
        )
        assert resp.status_code == 200
        msgs = resp.json()
        img_msgs = [m for m in msgs if m["image_url"] is not None]
        assert len(img_msgs) == 1
        assert img_msgs[0]["image_url"] == "/uploads/photo.jpg"


# ===========================================================================
# Typing Indicators
# ===========================================================================


class TestTypingIndicators:
    def test_typing_broadcast(self, api):
        req = _create_request(api)
        _accept_request(api, req["id"])
        token_r = api.client.post(
            f"/api/requests/{req['id']}/room-token",
            headers=auth(api.requester_token),
        ).json()["token"]
        token_p = api.client.post(
            f"/api/requests/{req['id']}/room-token",
            headers=auth(api.provider_token),
        ).json()["token"]

        with (
            api.client.websocket_connect(
                f"/api/requests/{req['id']}/chat?token={token_r}"
            ) as ws_r,
            api.client.websocket_connect(
                f"/api/requests/{req['id']}/chat?token={token_p}"
            ) as ws_p,
        ):
            ws_r.receive_json()
            ws_p.receive_json()

            ws_r.send_json({"type": "typing"})
            event = ws_p.receive_json()
            assert event["type"] == "typing"
            assert event["user_id"] == api.ids["requester_id"]

    def test_typing_not_echoed_to_sender(self, api):
        req = _create_request(api)
        _accept_request(api, req["id"])
        token_r = api.client.post(
            f"/api/requests/{req['id']}/room-token",
            headers=auth(api.requester_token),
        ).json()["token"]
        token_p = api.client.post(
            f"/api/requests/{req['id']}/room-token",
            headers=auth(api.provider_token),
        ).json()["token"]

        with (
            api.client.websocket_connect(
                f"/api/requests/{req['id']}/chat?token={token_r}"
            ) as ws_r,
            api.client.websocket_connect(
                f"/api/requests/{req['id']}/chat?token={token_p}"
            ) as ws_p,
        ):
            ws_r.receive_json()
            ws_p.receive_json()

            ws_r.send_json({"type": "typing"})
            event = ws_p.receive_json()
            assert event["type"] == "typing"
            assert event["user_id"] == api.ids["requester_id"]
