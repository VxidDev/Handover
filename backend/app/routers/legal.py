from fastapi import APIRouter

from ..legal import (
    CHILD_SAFETY_EMAIL,
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
        "safety_contact": CHILD_SAFETY_EMAIL,
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


# Play Data Safety – external account deletion instructions (no auth required)
# This is referenced as https://fvlabs.org/delete-account in Play Console
@router.get("/account-deletion", include_in_schema=False)
def account_deletion_info() -> dict:
    return {
        "url": "https://fvlabs.org/delete-account",
        "api_url": "/api/legal/account-deletion",
        "in_app": "Settings → Delete account (erases all data immediately)",
        "external": "If you cannot log in, email support@fvlabs.org from your registered email with subject 'Delete my account'. We verify ownership and delete within 7 days, with backups purged per legal retention schedule.",
        "retention_note": "Deletion is hard-delete (FERNET keys remain but encrypted phone becomes unrecoverable). We retain no data after deletion except where law requires (e.g., fraud prevention logs, anonymized).",
        "contact": CONTROLLER_EMAIL,
        "safety_contact": CHILD_SAFETY_EMAIL,
    }
