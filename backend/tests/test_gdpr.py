from conftest import auth

from app.models import ChatMessage, DisclosureLog, Request, User


def _set_up_request(api) -> dict:
    created = api.client.post(
        "/api/requests",
        headers=auth(api.requester_token),
        json={"skill_id": api.ids["plumbing_id"], "message": "Sink is dripping"},
    ).json()
    accepted = api.client.patch(
        f"/api/requests/{created['id']}",
        headers=auth(api.provider_token),
        json={"status": "accepted", "share_phone": True},
    ).json()
    assert accepted["status"] == "accepted"
    return created


def _add_message(api, request_id: int, sender_id: int, body: str) -> None:
    with api.session() as db:
        db.add(ChatMessage(request_id=request_id, sender_id=sender_id, body=body))
        db.commit()


class TestLegal:
    def test_serves_legal_documents(self, api):
        response = api.client.get("/api/legal")
        assert response.status_code == 200
        body = response.json()
        assert body["tos"]["version"] == "1.0.0"
        assert "Terms of Service" in body["tos"]["content"]
        assert body["privacy"]["version"] == "1.0.0"
        assert "Privacy Policy" in body["privacy"]["content"]
        assert body["controller"]["email"]


class TestExport:
    def test_export_includes_account_and_skills(self, api):
        response = api.client.get(
            "/api/users/me/export", headers=auth(api.provider_token)
        )
        assert response.status_code == 200
        body = response.json()
        assert body["account"]["email"] == "provider@example.com"
        assert body["account"]["phone"] is None
        assert {s["name"] for s in body["skills"]} == {"Plumbing"}
        assert body["controller"]["name"]

    def test_export_includes_requests_and_messages(self, api):
        created = _set_up_request(api)
        _add_message(
            api,
            created["id"],
            api.ids["requester_id"],
            "Hello, is Thursday still good?",
        )

        response = api.client.get(
            "/api/users/me/export", headers=auth(api.requester_token)
        )
        assert response.status_code == 200
        body = response.json()
        assert any(r["id"] == created["id"] for r in body["requests"])
        assert any(
            "Thursday" in m["body"] for m in body["chat_messages"]
        )

    def test_export_includes_encrypted_phone_decrypted(self, api):
        api.client.patch(
            "/api/users/me",
            headers=auth(api.provider_token),
            json={"phone": "555-0100"},
        )
        response = api.client.get(
            "/api/users/me/export", headers=auth(api.provider_token)
        )
        assert response.json()["account"]["phone"] == "555-0100"


class TestDeleteAccount:
    def test_delete_erases_user_and_all_related_data(self, api, tmp_path, monkeypatch):
        from app.routers import users

        monkeypatch.setattr(users, "UPLOAD_DIR", tmp_path)

        skill = api.client.post(
            "/api/users/me/skills",
            headers=auth(api.provider_token),
            json={
                "name": "Gardening",
                "blurb": "Planters and pruning",
                "image_paths": ["/uploads/fake.jpg"],
            },
        ).json()
        image_file = tmp_path / "fake.jpg"
        image_file.write_bytes(b"fake-image")

        profile_image_file = tmp_path / "profile.jpg"
        profile_image_file.write_bytes(b"fake-profile-image")
        api.client.patch(
            "/api/users/me",
            headers=auth(api.provider_token),
            json={"profile_image": "/uploads/profile.jpg"},
        )

        created = _set_up_request(api)
        _add_message(
            api, created["id"], api.ids["requester_id"], "See you Saturday."
        )

        response = api.client.delete(
            "/api/users/me", headers=auth(api.provider_token)
        )
        assert response.status_code == 204

        with api.session() as db:
            assert db.get(User, api.ids["provider_id"]) is None
            assert db.query(Request).filter(Request.id == created["id"]).first() is None
            assert (
                db.query(ChatMessage)
                .filter(ChatMessage.sender_id == api.ids["provider_id"])
                .first()
                is None
            )
            assert (
                db.query(DisclosureLog)
                .filter(DisclosureLog.owner_id == api.ids["provider_id"])
                .first()
                is None
            )

        assert not image_file.exists()
        assert not profile_image_file.exists()
        catalog_ids = {
            s["skill_id"] for s in api.client.get("/api/skills").json()
        }
        assert skill["id"] not in catalog_ids

    def test_delete_returns_401_afterwards(self, api):
        api.client.delete("/api/users/me", headers=auth(api.requester_token))
        response = api.client.get("/api/users/me", headers=auth(api.requester_token))
        assert response.status_code == 401

    def test_delete_requires_authentication(self, api):
        assert api.client.delete("/api/users/me").status_code == 401
