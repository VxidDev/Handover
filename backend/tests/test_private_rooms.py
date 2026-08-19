import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import sessionmaker

from app import database
from app.database import Base, get_db
from app.main import app
from app.models import DisclosureLog, PrivateContact, Request, Skill, User
from app.routers import rooms
from app.security import create_token, hash_password


@pytest.fixture
def room_data(tmp_path, monkeypatch):
    engine = create_engine(
        f"sqlite:///{tmp_path / 'test.db'}", connect_args={"check_same_thread": False}
    )
    Base.metadata.create_all(engine)
    TestingSession = sessionmaker(bind=engine)
    with TestingSession() as db:
        requester = User(
            email="requester@example.com",
            password_hash=hash_password("password"),
            name="Requester",
        )
        provider = User(
            email="provider@example.com",
            password_hash=hash_password("password"),
            name="Provider",
        )
        db.add_all([requester, provider])
        db.flush()
        skill = Skill(user_id=provider.id, name="Repair", blurb="")
        db.add(skill)
        db.flush()
        request = Request(
            requester_id=requester.id,
            provider_id=provider.id,
            skill_id=skill.id,
        )
        db.add(request)
        db.commit()
        ids = requester.id, provider.id, request.id

    def override_db():
        with TestingSession() as db:
            yield db

    app.dependency_overrides[get_db] = override_db
    monkeypatch.setattr(rooms, "SessionLocal", TestingSession)
    client = TestClient(app)
    yield client, TestingSession, ids
    client.close()
    app.dependency_overrides.clear()
    engine.dispose()


def _headers(user_id: int) -> dict[str, str]:
    return {"Authorization": f"Bearer {create_token({'sub': str(user_id)})}"}


def test_private_phone_acceptance_and_disclosure(room_data):
    client, Session, (requester_id, provider_id, request_id) = room_data

    response = client.patch(
        "/api/users/me",
        headers=_headers(provider_id),
        json={"phone": " 555-0100 "},
    )
    assert response.status_code == 200
    assert response.json()["phone"] == "555-0100"
    with Session() as db:
        contact = db.get(PrivateContact, provider_id)
        assert contact.encrypted_phone != "555-0100"

    missing_choice = client.patch(
        f"/api/requests/{request_id}",
        headers=_headers(provider_id),
        json={"status": "accepted"},
    )
    assert missing_choice.status_code == 422

    accepted = client.patch(
        f"/api/requests/{request_id}",
        headers=_headers(provider_id),
        json={"status": "accepted", "share_phone": True},
    )
    assert accepted.status_code == 200
    assert "phone" not in accepted.json()
    assert "provider_share_phone" not in accepted.json()

    provider_room = client.post(
        f"/api/requests/{request_id}/room-token", headers=_headers(provider_id)
    )
    assert provider_room.status_code == 200
    assert provider_room.json()["contact_info"] == {}

    requester_room = client.post(
        f"/api/requests/{request_id}/room-token", headers=_headers(requester_id)
    )
    assert requester_room.status_code == 200
    assert requester_room.json()["contact_info"] == {"phone": "555-0100"}
    with Session() as db:
        log = db.query(DisclosureLog).one()
        assert (log.owner_id, log.viewer_id, log.field) == (
            provider_id,
            requester_id,
            "phone",
        )


def test_decline_forces_phone_sharing_off(room_data):
    client, Session, (_, provider_id, request_id) = room_data
    response = client.patch(
        f"/api/requests/{request_id}",
        headers=_headers(provider_id),
        json={"status": "declined", "share_phone": True},
    )
    assert response.status_code == 200
    with Session() as db:
        request = db.get(Request, request_id)
        assert request.provider_share_phone is False


def test_websocket_persists_and_broadcasts_message(room_data):
    client, _, (requester_id, provider_id, request_id) = room_data
    accepted = client.patch(
        f"/api/requests/{request_id}",
        headers=_headers(provider_id),
        json={"status": "accepted", "share_phone": False},
    )
    assert accepted.status_code == 200
    token = client.post(
        f"/api/requests/{request_id}/room-token", headers=_headers(requester_id)
    ).json()["token"]

    with client.websocket_connect(
        f"/api/requests/{request_id}/chat?token={token}"
    ) as websocket:
        assert websocket.receive_json() == {"type": "history", "messages": []}
        websocket.send_json({"type": "message", "body": "  Hello  "})
        event = websocket.receive_json()
        assert event["type"] == "message"
        assert event["message"]["body"] == "Hello"

    history = client.get(
        f"/api/requests/{request_id}/messages", headers=_headers(provider_id)
    )
    assert history.status_code == 200
    assert history.json()[0]["sender_id"] == requester_id


def test_startup_migration_is_idempotent(tmp_path, monkeypatch):
    engine = create_engine(f"sqlite:///{tmp_path / 'legacy.db'}")
    with engine.begin() as connection:
        connection.execute(text("CREATE TABLE requests (id INTEGER PRIMARY KEY)"))
        connection.execute(text("INSERT INTO requests (id) VALUES (1)"))
    monkeypatch.setattr(database, "engine", engine)

    database.run_startup_migrations()
    database.run_startup_migrations()

    assert "provider_share_phone" in {
        column["name"] for column in inspect(engine).get_columns("requests")
    }
    with engine.connect() as connection:
        assert connection.execute(
            text("SELECT provider_share_phone FROM requests WHERE id = 1")
        ).scalar_one() in (False, 0)
