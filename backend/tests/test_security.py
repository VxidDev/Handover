import base64
import hashlib

import pytest

from app.security import (
    _verify_legacy_pbkdf2,
    create_token,
    decode_room_token,
    decode_token,
    decrypt_contact,
    encrypt_contact,
    hash_password,
    verify_password,
)


class TestPasswordHashing:
    def test_roundtrip(self):
        stored = hash_password("hunter2")
        assert stored.startswith("$argon2")
        assert stored != "hunter2"
        assert verify_password("hunter2", stored) is True
        assert verify_password("wrong", stored) is False

    def test_accepts_unique_salts(self):
        first = hash_password("same")
        second = hash_password("same")
        assert first != second
        assert verify_password("same", first) is True
        assert verify_password("same", second) is True

    def test_verifies_legacy_pbkdf2(self):
        salt = b"\x00\x01\x02\x03"
        digest = hashlib.pbkdf2_hmac(
            "sha256", b"legacy-password", salt, iterations=1000
        )
        stored = (
            f"1000${base64.b64encode(salt).decode()}"
            f"${base64.b64encode(digest).decode()}"
        )
        assert _verify_legacy_pbkdf2("legacy-password", stored) is True
        assert _verify_legacy_pbkdf2("wrong", stored) is False

    def test_rejects_malformed_stored_hash(self):
        assert verify_password("password", "not-a-hash") is False


class TestTokens:
    def test_roundtrip(self):
        token = create_token({"sub": "42"})
        payload = decode_token(token)
        assert payload["sub"] == "42"
        assert payload["exp"] > payload["iat"]
        assert payload["jti"]

    def test_rejects_garbage(self):
        with pytest.raises(ValueError):
            decode_token("not.a.jwt")

    def test_room_token_scoping(self):
        token = create_token(
            {"sub": "7", "scope": "request_room", "request_id": 42}, ttl_seconds=900
        )
        assert decode_room_token(token, 42) == 7

    def test_room_token_rejects_wrong_request(self):
        token = create_token({"sub": "7", "scope": "request_room", "request_id": 42})
        with pytest.raises(ValueError):
            decode_room_token(token, 99)

    def test_room_token_rejects_wrong_scope(self):
        token = create_token({"sub": "7", "scope": "something_else", "request_id": 42})
        with pytest.raises(ValueError):
            decode_room_token(token, 42)


class TestContactEncryption:
    def test_roundtrip(self):
        encrypted = encrypt_contact("555-0100")
        assert encrypted != "555-0100"
        assert decrypt_contact(encrypted) == "555-0100"

    def test_ciphertext_differs_between_calls(self):
        assert encrypt_contact("555-0100") != encrypt_contact("555-0100")
