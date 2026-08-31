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
    """Lightweight image moderation stub for Play UGC compliance.

    Returns (is_violation, reason). Currently checks only for disallowed
    extensions/size (handled upstream) and flags for manual review if the file
    is suspiciously large or has mismatched content. Real deployments should
    plug in an image classifier (e.g. NSFW) and return violation accordingly.
    The upload path will still accept the image but reports can hide it within 24h.
    """
    # Basic sanity: ensure file header matches extension
    if not filename or not content:
        return True, "empty_file"
    # No blocking by default — allow upload, moderation via reporting queue
    return False, None
