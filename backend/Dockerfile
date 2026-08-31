FROM python:3.11-slim

# Системные зависимости для сборки argon2-cffi и других C-extensions
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

# Директория для SQLite (создаем заранее, чтобы volume корректно примонтировался)
RUN mkdir -p /app/data

EXPOSE 8099

# ВАЖНО: host 0.0.0.0 для доступа из контейнера nginx.
# Порт 8099 остается внутренним, наружу не публикуется.
CMD ["granian", "app.main:app", "--interface", "asgi", "--host", "0.0.0.0", "--port", "8099"]