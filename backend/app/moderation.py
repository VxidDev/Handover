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

    If the model cannot be loaded (missing dependency or download), the call
    degrades gracefully to a non-toxic verdict and the scores are empty so
    moderation can keep working without blocking reports.
    """
    text = (text or "").strip()
    if not text:
        return False, {}
    try:
        scores: dict[str, float] = get_model().predict(text)
    except Exception as exc:  # noqa: BLE001
        logger.warning("Detoxify unavailable, treating content as safe: %s", exc)
        return False, {}
    peak = max(scores.values(), default=0.0)
    return peak >= TOXICITY_THRESHOLD, scores
