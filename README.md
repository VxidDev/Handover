# Handover

Neighbors helping neighbors, skill by skill. A community-powered platform for exchanging skills and support.

## Prerequisites

- Python 3.12+
- Flutter 3.44+
- Docker (optional, for containerized deployment)

## Quick Start

### Backend

```bash
cd backend

# Create and activate virtual environment
python -m venv .venv
source .venv/bin/activate  # Linux/macOS
# .venv\Scripts\activate   # Windows

# Install dependencies
pip install -r requirements.txt

# Set up environment
cp .env.example .env
# Edit .env and generate SECRET_KEY and CONTACT_ENCRYPTION_KEY:
#   python -c "import secrets; print(secrets.token_hex(32))"
#   python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"

# Run the server
granian app.main:app --interface asgi --host 0.0.0.0 --port 9000 --reload
```

### Frontend

```bash
cd frontend

# Install dependencies
flutter pub get

# Set up environment
cp .env.example .env
# Edit .env to point to your backend URL

# Run the app
flutter run
```

### Demo Data (Development Only)

To seed demo users on first start:

```bash
# In backend/.env
SEED_DEMO_DATA=true
```

## Docker Deployment

```bash
cd backend

# Build and run
docker build -t handover-api .
docker run -p 9000:9000 \
  -e SECRET_KEY=$(python -c "import secrets; print(secrets.token_hex(32))") \
  -e CONTACT_ENCRYPTION_KEY=$(python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())") \
  -e ENVIRONMENT=production \
  -e CORS_ORIGINS=https://your-frontend-domain.com \
  handover-api
```

## Environment Variables

### Backend

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SECRET_KEY` | Yes | — | JWT signing key (64-char hex) |
| `CONTACT_ENCRYPTION_KEY` | Yes | — | Fernet key for phone encryption |
| `DATABASE_URL` | No | SQLite | Database connection URL |
| `ENVIRONMENT` | No | `development` | `development` or `production` |
| `CORS_ORIGINS` | No | `*` | Comma-separated allowed origins |
| `SEED_DEMO_DATA` | No | `false` | Seed demo users on first start |
| `RATE_LIMIT_MAX` | No | `30` | Max auth requests/min/IP |

### Frontend

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `API_BASE_URL` | No | `http://127.0.0.1:9000` | Backend API URL |

Build with custom URL:
```bash
flutter run --dart-define=API_BASE_URL=https://api.handover.app
```

## Production Deployment

1. Set `ENVIRONMENT=production` on the backend
2. Configure `CORS_ORIGINS` to your frontend domain
3. Use HTTPS (via reverse proxy like nginx/Caddy)
4. Use PostgreSQL instead of SQLite for production
5. Disable Swagger UI (automatically hidden in production)

## API Documentation

When running in development mode, API docs are available at:
- Swagger UI: `http://localhost:9000/docs`
- ReDoc: `http://localhost:9000/redoc`

## License

Private — All rights reserved.
