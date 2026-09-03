import logging

logger = logging.getLogger(__name__)

# Any category scoring at or above this threshold is treated as toxic.
TOXICITY_THRESHOLD = 0.75

_model = None


def get_model():
    global _model
    if _model is None:
        from detoxify import Detoxify

        _model = Detoxify("original")
    return _model


def analyze(text: str) -> tuple[bool, dict[str, float]]:
    """Run Detoxify on ``text`` and return (is_toxic, per-label scores).

    If the model cannot be loaded (missing dependency or download), we return
    empty scores so caller can route to human review (pending_review) rather
    than silently marking as safe. Wrapped in timeout — if model hangs >5s we also queue.
    """
    text = (text or "").strip()
    if not text:
        return False, {}
    try:
        import concurrent.futures

        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as ex:
            fut = ex.submit(lambda: get_model().predict(text))
            scores: dict[str, float] = fut.result(timeout=5.0)
    except Exception as exc:  # noqa: BLE001
        logger.warning("Detoxify unavailable/slow, queuing for manual review: %s", exc)
        return False, {}
    peak = max(scores.values(), default=0.0)
    return peak >= TOXICITY_THRESHOLD, scores


def moderate_image(filename: str, content: bytes) -> tuple[bool, str | None]:
    """Play UGC image moderation.

    Returns (is_violation, reason). Checks magic bytes vs extension, rejects
    non-image payloads and mismatched content (common CSAM evasion). Does NOT
    replace a dedicated NSFW classifier — see README. Valid images pass;
    violating uploads are blocked before storage and logged. Reports can still
    hide content within 24h via /reports.
    """
    if not filename or not content:
        return True, "empty_file"
    if len(content) < 12:
        return True, "file_too_small"

    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    header = content[:12]

    # Magic-byte checks
    is_jpeg = header.startswith(b"\xff\xd8\xff")
    is_png = header.startswith(b"\x89PNG\r\n\x1a\n")
    is_webp = header.startswith(b"RIFF") and content[8:12] == b"WEBP"

    # Detect actual type
    if is_jpeg:
        actual = "jpg"
    elif is_png:
        actual = "png"
    elif is_webp:
        actual = "webp"
    else:
        logger.warning("Image upload rejected: unknown magic bytes for %s", filename)
        return True, "unsupported_or_mismatched_content"

    # Extension must match content — prevents .jpg hiding executable, etc.
    ext_normalized = "jpg" if ext in ("jpg", "jpeg") else ext
    if ext_normalized != actual:
        logger.warning("Image extension mismatch: %s claims .%s but is %s", filename, ext, actual)
        return True, "extension_mismatch"

    # WebP/JPEG/PNG only; size already capped at 5MB upstream, but double-check
    if len(content) > 5 * 1024 * 1024:
        return True, "file_too_large"

    # Hook for NSFW/CSAM classifier: plug in (e.g. NudeNet, Hive, Google Vision SafeSearch)
    # Example: if nsfw_score > 0.85: return True, "nsfw_blocked"
    # Currently no model bundled; rely on user reporting + 24h takedown.
    return False, None
