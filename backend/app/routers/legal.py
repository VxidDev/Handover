from fastapi import APIRouter

from ..legal import (
    CONTROLLER_ADDRESS,
    CONTROLLER_EMAIL,
    CONTROLLER_NAME,
    EFFECTIVE_DATE,
    PRIVACY_POLICY,
    PRIVACY_VERSION,
    TERMS_OF_SERVICE,
    TOS_VERSION,
    format_document,
)

router = APIRouter(prefix="/legal", tags=["legal"])


@router.get("")
def legal_documents() -> dict:
    return {
        "controller": {
            "name": CONTROLLER_NAME,
            "email": CONTROLLER_EMAIL,
            "address": CONTROLLER_ADDRESS,
        },
        "tos": {
            "version": TOS_VERSION,
            "effective_date": EFFECTIVE_DATE,
            "content": format_document(TERMS_OF_SERVICE, TOS_VERSION),
        },
        "privacy": {
            "version": PRIVACY_VERSION,
            "effective_date": EFFECTIVE_DATE,
            "content": format_document(PRIVACY_POLICY, PRIVACY_VERSION),
        },
    }
