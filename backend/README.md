# Handover Backend

FastAPI + SQLAlchemy API backing the Handover Flutter app. Ships with a signed-token auth scheme (no third-party auth dependency), a seeded demo neighborhood, and a SQLite database so it runs with zero setup.

## Requirements

- Python 3.11+

## Setup

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate          # PowerShell (Windows)
pip install -r requirements.txt
```

## Run

```bash
granian app.main:app --interface asgi --host 127.0.0.1 --port 9000
```

For development with auto-reload:

```bash
granian --reload app.main:app --interface asgi --host 127.0.0.1 --port 9000
```

- Interactive API docs: http://127.0.0.1:8099/docs
- Health check: http://127.0.0.1:8099/health

> On first startup the app creates `data/handover.db` and seeds four demo
> neighbors (matching the frontend's mock data). The default port in the
> README is 8099 because 8000 is reserved by Windows on some machines.

## Demo accounts

All seeded users share the password `demo1234`:

| Email                | Name    | Skill            | Available |
|----------------------|---------|------------------|-----------|
| maya@example.com     | Maya R. | Plumbing         | yes       |
| diego@example.com    | Diego S.| Spanish Tutoring | yes       |
| priya@example.com    | Priya K.| Computer Help    | no        |
| owen@example.com     | Owen T. | Bike Repair      | yes       |

## Connecting the Flutter app

The frontend points at `http://127.0.0.1:9000` by default. For other targets
override at build time:

```
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8099   # Android emulator
```

## API

All routes live under `/api` and return JSON. Interactive docs describe each
request/response shape.

| Method | Path                          | Auth | Description                                  |
|--------|-------------------------------|------|----------------------------------------------|
| POST   | `/api/auth/signup`            |      | Create an account, returns token + profile   |
| POST   | `/api/auth/login`             |      | Log in, returns token + profile              |
| GET    | `/api/users/me`               | ✔    | Current profile + skills                     |
| PATCH  | `/api/users/me`               | ✔    | Update name / availability / location        |
| POST   | `/api/users/me/skills`        | ✔    | Add a skill to your wallet                   |
| DELETE | `/api/users/me/skills/{id}`   | ✔    | Remove a skill                               |
| GET    | `/api/skills`                 |      | Search skills (keyword, radius, location)    |
| POST   | `/api/requests`               | ✔    | Ask a neighbor for help                      |
| GET    | `/api/requests`               | ✔    | List requests (`role=sent/received`, `status`) |
| PATCH  | `/api/requests/{id}`          | ✔    | Accept/decline (owner only)                  |

Example search with a 5 km radius:

```
GET /api/skills?q=plumbing&lat=37.7749&lng=-122.4195&radius_km=5
```

Distances are computed with the haversine formula using the latitude/longitude
that users register. A `grid` string is attached to each user so the app can
show a rough area without revealing exact locations — exact coordinates are
never exposed in search responses.

## Config

| Env var            | Default               | Description                    |
|--------------------|-----------------------|--------------------------------|
| `DATABASE_URL`     | `sqlite:///data/handover.db` | SQLAlchemy connection URL |
| `SECRET_KEY`       | random per-process    | Signs auth tokens; set a fixed one in production |
| `TOKEN_TTL_SECONDS`| 604800 (7 days)       | Auth token lifetime          |

Tokens are JWT (HS256, signed with `SECRET_KEY`, stateless). Passwords are
hashed with PBKDF2-SHA256 (260k iterations) using per-password salts so no
hashing library is required.

## Layout

```
backend/
├─ app/
│  ├─ main.py        # FastAPI app, lifespan (create tables + seed), CORS
│  ├─ config.py      # Settings from env vars
│  ├─ database.py    # SQLAlchemy engine/session
│  ├─ models.py      # User, Skill, Request
│  ├─ schemas.py     # Pydantic request/response models
│  ├─ security.py    # Password hashing (PBKDF2) + JWT create/verify
│  ├─ deps.py        # get_current_user dependency
│  ├─ seed.py        # Demo-neighbor seed data
│  └─ routers/       # auth, users, skills, requests
├─ data/             # SQLite database (gitignored, created on startup)
├─ requirements.txt
└─ .env.example
```