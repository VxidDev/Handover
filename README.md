# Handover

A community-powered platform for exchanging skills and support. Neighbors helping neighbors, skill by skill: find help nearby, request it, chat privately, then rate and tip to say thanks.

## How it works

1. Create a profile and add skills to your wallet (with photos if you like).
2. Search nearby skills by keyword and radius. You only ever see a rough
   area and a distance, never anyone's exact location.
3. Send a request. The provider accepts or declines and chooses whether to
   share a phone number for that request only.
4. Chat in a private room (short-lived access tokens, full history for members).
5. Close the loop with a rating and an optional tip (80% to the neighbor).

## Repository layout

```
.
├── backend/        # FastAPI + SQLAlchemy API (see backend/README.md)
├── frontend/       # Flutter app for Android, iOS, web and desktop
├── nginx.conf      # Reverse proxy in front of the API (TLS + WebSockets)
└── docker-compose.yml
```

## Quickstart (Docker)

```bash
cp backend/.env.example backend/.env
# Edit backend/.env: set SECRET_KEY and CONTACT_ENCRYPTION_KEY (see comments inside)
docker compose up --build
```

The API is served through nginx on port 80.

## Quickstart (local dev)

Backend (Python 3.11+):

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
granian app.main:app --interface asgi --host 127.0.0.1 --port 9000
```

API docs: http://127.0.0.1:9000/docs — health: http://127.0.0.1:9000/health

Frontend (Flutter 3.x):

```bash
cd frontend
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:9000
```

See `backend/README.md` and `frontend/README.md` for details.

## Safety and privacy

Handover is designed for real-world trust: coarse location only, encrypted
private contacts with per-request sharing consent, toxicity and image
screening, user reports with blocking, and public legal, child-safety and
account-deletion pages served by the API.
