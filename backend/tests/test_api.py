from conftest import auth

from app.models import Request, Skill, User
from app.routers.uploads import _write_file


def test_health(api):
    response = api.client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_requires_authentication(api):
    response = api.client.get("/api/users/me")
    assert response.status_code == 401

    response = api.client.get("/api/requests")
    assert response.status_code == 401


class TestAuth:
    def test_signup_creates_user_and_returns_token(self, api):
        response = api.client.post(
            "/api/auth/signup",
            json={
                "email": "new@example.com",
                "password": "secret123",
                "name": "  New Person  ",
                "lat": 37.5,
                "lng": -122.4,
                "accept_tos": True,
                "accept_privacy": True,
            },
        )
        assert response.status_code == 201
        payload = response.json()
        assert payload["token"]
        assert payload["user"]["email"] == "new@example.com"
        assert payload["user"]["name"] == "New Person"
        assert payload["user"]["is_available"] is True
        assert payload["user"]["skills"] == []

        with api.session() as db:
            user = db.query(User).filter(User.email == "new@example.com").one()
            assert user.password_hash != "secret123"
            assert user.tos_accepted_at is not None
            assert user.privacy_accepted_at is not None
            assert user.tos_version == "1.0.0"
            assert user.privacy_version == "1.0.0"

    def test_signup_rejects_missing_consent(self, api):
        response = api.client.post(
            "/api/auth/signup",
            json={
                "email": "noconsent@example.com",
                "password": "secret123",
                "name": "No Consent",
                "accept_tos": True,
            },
        )
        assert response.status_code == 422

        response = api.client.post(
            "/api/auth/signup",
            json={
                "email": "noconsent@example.com",
                "password": "secret123",
                "name": "No Consent",
            },
        )
        assert response.status_code == 422

    def test_signup_rejects_duplicate_email(self, api):
        response = api.client.post(
            "/api/auth/signup",
            json={
                "email": "provider@example.com",
                "password": "secret123",
                "name": "Duplicate",
                "accept_tos": True,
                "accept_privacy": True,
            },
        )
        assert response.status_code == 409

    def test_signup_rejects_short_password(self, api):
        response = api.client.post(
            "/api/auth/signup",
            json={
                "email": "a@example.com",
                "password": "123",
                "name": "A",
                "accept_tos": True,
                "accept_privacy": True,
            },
        )
        assert response.status_code == 422

    def test_login_succeeds(self, api):
        response = api.client.post(
            "/api/auth/login",
            json={"email": "PROVIDER@example.com", "password": "password"},
        )
        assert response.status_code == 200
        assert response.json()["token"]
        assert response.json()["user"]["name"] == "Provider"

    def test_login_rejects_wrong_password(self, api):
        response = api.client.post(
            "/api/auth/login",
            json={"email": "provider@example.com", "password": "wrong"},
        )
        assert response.status_code == 401

    def test_login_rejects_unknown_email(self, api):
        response = api.client.post(
            "/api/auth/login",
            json={"email": "nobody@example.com", "password": "password"},
        )
        assert response.status_code == 401


class TestSkillsSearch:
    def test_returns_catalog(self, api):
        response = api.client.get("/api/skills")
        assert response.status_code == 200
        names = {s["skill_name"] for s in response.json()}
        assert names == {"Plumbing", "Yoga"}

    def test_filters_by_keyword(self, api):
        response = api.client.get("/api/skills", params={"q": "drain"})
        body = response.json()
        assert len(body) == 1
        assert body[0]["skill_name"] == "Plumbing"

    def test_hides_own_skills_for_authenticated_user(self, api):
        response = api.client.get("/api/skills", headers=auth(api.provider_token))
        names = {s["skill_name"] for s in response.json()}
        assert "Plumbing" not in names
        assert "Yoga" in names

    def test_radius_filter(self, api):
        response = api.client.get(
            "/api/skills",
            params={"lat": 37.7849, "lng": -122.4295, "radius_km": 10},
        )
        assert {s["skill_name"] for s in response.json()} == {"Plumbing"}

    def test_radius_filter_excludes_far_skills(self, api):
        response = api.client.get(
            "/api/skills",
            params={"lat": 37.7849, "lng": -122.4295, "radius_km": 1},
        )
        assert response.json() == []

    def test_distance_is_reported(self, api):
        response = api.client.get(
            "/api/skills",
            params={"lat": 37.7849, "lng": -122.4295},
        )
        by_name = {s["skill_name"]: s for s in response.json()}
        assert by_name["Plumbing"]["distance_km"] == 1.4
        assert by_name["Yoga"]["distance_km"] == 4155.0


class TestUsers:
    def test_me_returns_profile(self, api):
        response = api.client.get("/api/users/me", headers=auth(api.provider_token))
        assert response.status_code == 200
        body = response.json()
        assert body["name"] == "Provider"
        assert body["email"] == "provider@example.com"
        assert body["is_available"] is True

    def test_update_profile_fields(self, api):
        response = api.client.patch(
            "/api/users/me",
            headers=auth(api.provider_token),
            json={"name": "Renamed", "is_available": False, "grid": "E1"},
        )
        assert response.status_code == 200
        body = response.json()
        assert body["name"] == "Renamed"
        assert body["is_available"] is False
        assert body["grid"] == "E1"

    def test_add_and_delete_skill(self, api):
        add = api.client.post(
            "/api/users/me/skills",
            headers=auth(api.requester_token),
            json={
                "name": "  Painting  ",
                "blurb": "  Walls  ",
                "image_paths": ["/uploads/a.png"],
            },
        )
        assert add.status_code == 201
        skill = add.json()
        assert skill["name"] == "Painting"
        assert skill["blurb"] == "Walls"
        assert skill["images"][0]["path"] == "/uploads/a.png"

        delete = api.client.delete(
            f"/api/users/me/skills/{skill['id']}",
            headers=auth(api.requester_token),
        )
        assert delete.status_code == 204

    def test_cannot_delete_another_users_skill(self, api):
        response = api.client.delete(
            f"/api/users/me/skills/{api.ids['plumbing_id']}",
            headers=auth(api.requester_token),
        )
        assert response.status_code == 404
        with api.session() as db:
            assert db.get(Skill, api.ids["plumbing_id"]) is not None

    def test_update_phone_is_stored_encrypted(self, api):
        response = api.client.patch(
            "/api/users/me",
            headers=auth(api.provider_token),
            json={"phone": " 555-0100 "},
        )
        assert response.status_code == 200
        assert response.json()["phone"] == "555-0100"
        with api.session() as db:
            user = db.get(User, api.ids["provider_id"])
            assert user.private_contact.encrypted_phone != "555-0100"


class TestRequests:
    def test_create_request(self, api):
        response = api.client.post(
            "/api/requests",
            headers=auth(api.requester_token),
            json={"skill_id": api.ids["plumbing_id"], "message": "Sink is dripping"},
        )
        assert response.status_code == 201
        body = response.json()
        assert body["status"] == "pending"
        assert body["requester_name"] == "Requester"
        assert body["provider_name"] == "Provider"
        assert body["skill_name"] == "Plumbing"

    def test_cannot_request_own_skill(self, api):
        response = api.client.post(
            "/api/requests",
            headers=auth(api.provider_token),
            json={"skill_id": api.ids["plumbing_id"]},
        )
        assert response.status_code == 400

    def test_cannot_request_missing_skill(self, api):
        response = api.client.post(
            "/api/requests",
            headers=auth(api.requester_token),
            json={"skill_id": 9999},
        )
        assert response.status_code == 404

    def test_list_requests_by_role(self, api):
        for skill_id in (api.ids["plumbing_id"], api.ids["yoga_id"]):
            response = api.client.post(
                "/api/requests",
                headers=auth(api.requester_token),
                json={"skill_id": skill_id},
            )
            assert response.status_code == 201

        sent = api.client.get(
            "/api/requests", params={"role": "sent"}, headers=auth(api.requester_token)
        )
        assert len(sent.json()) == 2

        received = api.client.get(
            "/api/requests",
            params={"role": "received"},
            headers=auth(api.provider_token),
        )
        assert len(received.json()) == 1
        assert received.json()[0]["skill_name"] == "Plumbing"

    def test_cancel_request(self, api):
        created = api.client.post(
            "/api/requests",
            headers=auth(api.requester_token),
            json={"skill_id": api.ids["plumbing_id"]},
        ).json()
        cancelled = api.client.delete(
            f"/api/requests/{created['id']}", headers=auth(api.requester_token)
        )
        assert cancelled.status_code == 200
        assert cancelled.json()["status"] == "cancelled"

    def test_only_requester_can_cancel(self, api):
        created = api.client.post(
            "/api/requests",
            headers=auth(api.requester_token),
            json={"skill_id": api.ids["plumbing_id"]},
        ).json()
        response = api.client.delete(
            f"/api/requests/{created['id']}", headers=auth(api.provider_token)
        )
        assert response.status_code == 403

    def test_cannot_cancel_answered_request(self, api):
        created = api.client.post(
            "/api/requests",
            headers=auth(api.requester_token),
            json={"skill_id": api.ids["plumbing_id"]},
        ).json()
        api.client.patch(
            f"/api/requests/{created['id']}",
            headers=auth(api.provider_token),
            json={"status": "accepted", "share_phone": False},
        )
        response = api.client.delete(
            f"/api/requests/{created['id']}", headers=auth(api.requester_token)
        )
        assert response.status_code == 409

    def test_only_provider_can_respond(self, api):
        created = api.client.post(
            "/api/requests",
            headers=auth(api.requester_token),
            json={"skill_id": api.ids["plumbing_id"]},
        ).json()
        response = api.client.patch(
            f"/api/requests/{created['id']}",
            headers=auth(api.requester_token),
            json={"status": "accepted", "share_phone": False},
        )
        assert response.status_code == 403

    def test_accepting_requires_share_phone_choice(self, api):
        created = api.client.post(
            "/api/requests",
            headers=auth(api.requester_token),
            json={"skill_id": api.ids["plumbing_id"]},
        ).json()
        response = api.client.patch(
            f"/api/requests/{created['id']}",
            headers=auth(api.provider_token),
            json={"status": "accepted"},
        )
        assert response.status_code == 422

    def test_decline_clears_phone_sharing(self, api):
        created = api.client.post(
            "/api/requests",
            headers=auth(api.requester_token),
            json={"skill_id": api.ids["plumbing_id"]},
        ).json()
        declined = api.client.patch(
            f"/api/requests/{created['id']}",
            headers=auth(api.provider_token),
            json={"status": "declined", "share_phone": True},
        )
        assert declined.status_code == 200
        with api.session() as db:
            request = db.get(Request, created["id"])
            assert request.provider_share_phone is False


class TestUploads:
    def test_upload_image(self, api, tmp_path, monkeypatch):
        from app.routers import uploads

        monkeypatch.setattr(uploads, "UPLOAD_DIR", tmp_path)
        response = api.client.post(
            "/api/uploads/images",
            headers=auth(api.provider_token),
            files={"file": ("photo.png", b"fake-image-bytes", "image/png")},
        )
        assert response.status_code == 200
        path = response.json()["path"]
        assert path.startswith("/uploads/")
        assert (tmp_path / path.removeprefix("/uploads/")).exists()

    def test_upload_rejects_unsupported_type(self, api, tmp_path, monkeypatch):
        from app.routers import uploads

        monkeypatch.setattr(uploads, "UPLOAD_DIR", tmp_path)
        response = api.client.post(
            "/api/uploads/images",
            headers=auth(api.provider_token),
            files={"file": ("virus.exe", b"MZ...", "application/octet-stream")},
        )
        assert response.status_code == 400

    def test_upload_rejects_large_file(self, api, tmp_path, monkeypatch):
        from app.routers import uploads

        monkeypatch.setattr(uploads, "UPLOAD_DIR", tmp_path)
        response = api.client.post(
            "/api/uploads/images",
            headers=auth(api.provider_token),
            files={
                "file": (
                    "big.png",
                    b"x" * (uploads.MAX_FILE_SIZE + 1),
                    "image/png",
                )
            },
        )
        assert response.status_code == 400


def test_write_file_roundtrip(tmp_path):
    filepath = tmp_path / "a.bin"
    _write_file(filepath, b"payload")
    assert filepath.read_bytes() == b"payload"
