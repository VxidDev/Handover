import bcrypt
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from pydantic import BaseModel

SECRET = "change-me"   # env var later
ALG = "HS256"

router = APIRouter(prefix="/auth")
oauth2 = OAuth2PasswordBearer(tokenUrl="/auth/login")

mock_users = {
    "test": "abcd1234",
    "admin": "mango6767"
}

class RegisterBody(BaseModel):
    email: str; password: str

class LoginBody(BaseModel):
    email: str; password: str

def create_access_token(data: dict, expires_delta: timedelta | None = None) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=30))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET, algorithm=ALG)

@router.post("/login")
def login(body: LoginBody):
    if not mock_users.get(body.email, "") == body.password:
        return {"error": "invalid credentials"}

    token = create_access_token({"sub": body.email})
    return {"access_token": token, "token_type": "bearer"}