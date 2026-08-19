"""Thread-safe in-memory TTL cache for static query results."""

import threading
import time
from collections.abc import Callable
from typing import Any

_MISS = object()


class TTLCache:
    def __init__(self, default_ttl: float = 300.0):
        self._data: dict[str, tuple[float, Any]] = {}
        self._default_ttl = default_ttl
        self._lock = threading.Lock()

    def get(self, key: str, default: Any = None) -> Any:
        with self._lock:
            item = self._data.get(key)
            if item is None:
                return default
            expires_at, value = item
            if expires_at < time.monotonic():
                del self._data[key]
                return default
            return value

    def set(self, key: str, value: Any, ttl: float | None = None) -> None:
        ttl = self._default_ttl if ttl is None else ttl
        with self._lock:
            self._data[key] = (time.monotonic() + ttl, value)

    def get_or_set(
        self, key: str, producer: Callable[[], Any], ttl: float | None = None
    ) -> Any:
        cached = self.get(key, _MISS)
        if cached is not _MISS:
            return cached
        value = producer()
        self.set(key, value, ttl)
        return value

    def delete(self, key: str) -> None:
        with self._lock:
            self._data.pop(key, None)

    def clear(self) -> None:
        with self._lock:
            self._data.clear()


# Default 5-minute TTL for static-ish data.
cache = TTLCache(default_ttl=300.0)

# Skills catalog key: the full "who offers what" list backing the search.
SKILLS_CATALOG_KEY = "skills_catalog"
