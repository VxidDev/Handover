from collections import namedtuple

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.cache import cache
from app.database import Base, get_db
from app.main import app
from app.models import Skill, User
from app.security import create_token, hash_password

ApiFixture = namedtuple(
    "ApiFixture",
    [
        "client",
        "session",
        "ids",
        "provider_token",
        "requester_token",
        "far_token",
    ],
)


@pytest.fixture
def api(tmp_path):
    engine = create_engine(
        f"sqlite:///{tmp_path / 'test.db'}",
        connect_args={"check_same_thread": False},
    )
    Base.metadata.create_all(engine)
    TestingSession = sessionmaker(bind=engine, expire_on_commit=False)

    with TestingSession() as db:
        provider = User(
            email="provider@example.com",
            password_hash=hash_password("password"),
            name="Provider",
            lat=37.7749,
            lng=-122.4195,
            grid="D4",
            karma=3,
        )
        requester = User(
            email="requester@example.com",
            password_hash=hash_password("password"),
            name="Requester",
            lat=37.7849,
            lng=-122.4295,
            grid="D4",
            karma=1,
        )
        far_user = User(
            email="far@example.com",
            password_hash=hash_password("password"),
            name="Far Away",
            lat=40.0,
            lng=-73.9,
            grid="G2",
        )
        db.add_all([provider, requester, far_user])
        db.flush()

        plumbing = Skill(
            user_id=provider.id, name="Plumbing", blurb="Faucet and drain fixes"
        )
        yoga = Skill(user_id=far_user.id, name="Yoga", blurb="Morning classes")
        db.add_all([plumbing, yoga])
        db.flush()
        db.commit()

        ids = {
            "provider_id": provider.id,
            "requester_id": requester.id,
            "far_id": far_user.id,
            "plumbing_id": plumbing.id,
            "yoga_id": yoga.id,
        }
        tokens = {
            "provider": create_token({"sub": str(provider.id)}),
            "requester": create_token({"sub": str(requester.id)}),
            "far": create_token({"sub": str(far_user.id)}),
        }

    def override_db():
        with TestingSession() as db:
            yield db

    app.dependency_overrides[get_db] = override_db
    cache.clear()

    client = TestClient(app)
    yield ApiFixture(
        client=client,
        session=TestingSession,
        ids=ids,
        provider_token=tokens["provider"],
        requester_token=tokens["requester"],
        far_token=tokens["far"],
    )
    client.close()
    app.dependency_overrides.clear()
    cache.clear()
    engine.dispose()


def auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}
