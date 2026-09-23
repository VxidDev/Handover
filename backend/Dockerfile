FROM python:3.11-slim

# System dependencies for building argon2-cffi and other C extensions
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libc-dev \
    libffi-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

COPY . .

# Directory for SQLite (created upfront so the volume mounts cleanly)
RUN mkdir -p /app/data

EXPOSE 8099

# NOTE: host 0.0.0.0 for access from the nginx container.
# Port 8099 stays internal, it is not published.
CMD ["granian", "app.main:app", "--interface", "asgi", "--host", "0.0.0.0", "--port", "8099"]