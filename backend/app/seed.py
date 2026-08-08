"""Seed the database with demo neighbors if it is empty.

Coordinates are fictional, roughly centered on a neighborhood so the
haversine distance in the search results is believable.
"""

from .database import SessionLocal
from .models import Skill, User
from .security import hash_password

DEMO_PASSWORD = "demo1234"

DEMO_USERS = [
    {
        "name": "Maya R.",
        "email": "maya@example.com",
        "lat": 37.77490,
        "lng": -122.41950,
        "grid": "Grid D4",
        "skills": [
            {
                "name": "Plumbing",
                "blurb": "Happy to help with leaky faucets, clogged drains, toilet fixes.",
            }
        ],
    },
    {
        "name": "Diego S.",
        "email": "diego@example.com",
        "lat": 37.77610,
        "lng": -122.41770,
        "grid": "Grid D5",
        "skills": [
            {
                "name": "Spanish Tutoring",
                "blurb": "Native speaker — translation or lessons for community events.",
            }
        ],
    },
    {
        "name": "Priya K.",
        "email": "priya@example.com",
        "lat": 37.77620,
        "lng": -122.42100,
        "grid": "Grid C3",
        "is_available": False,
        "skills": [
            {
                "name": "Computer Help",
                "blurb": "Software dev. WiFi, laptops, printers, phone setup.",
            }
        ],
    },
    {
        "name": "Owen T.",
        "email": "owen@example.com",
        "lat": 37.77440,
        "lng": -122.41890,
        "grid": "Grid D3",
        "skills": [
            {
                "name": "Bike Repair",
                "blurb": "Flats, brakes, gear tuning. Come by any evening.",
            }
        ],
    },
]


def run() -> None:
    with SessionLocal() as db:
        if db.query(User).first() is not None:
            return
        for data in DEMO_USERS:
            skills = data.pop("skills")
            user = User(password_hash=hash_password(DEMO_PASSWORD), **data)
            user.skills = [
                Skill(name=s["name"], blurb=s["blurb"]) for s in skills
            ]
            db.add(user)
        db.commit()


if __name__ == "__main__":
    run()