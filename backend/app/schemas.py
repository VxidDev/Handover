from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class SignupIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6, max_length=128)
    name: str = Field(min_length=1, max_length=100)
    lat: Optional[float] = None
    lng: Optional[float] = None


class LoginIn(BaseModel):
    email: EmailStr
    password: str


class SkillOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    blurb: str


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: EmailStr
    name: str
    is_available: bool
    karma: int
    grid: Optional[str] = None
    created_at: datetime


class UserMeOut(UserOut):
    skills: list[SkillOut] = []


class AuthOut(BaseModel):
    token: str
    user: UserMeOut


class UserUpdateIn(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=100)
    is_available: Optional[bool] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    grid: Optional[str] = Field(default=None, max_length=20)


class SkillCreateIn(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    blurb: str = Field(default="", max_length=500)


class SkillSearchOut(BaseModel):
    skill_id: int
    skill_name: str
    blurb: str
    owner_id: int
    owner_name: str
    grid: Optional[str] = None
    distance_km: Optional[float] = None
    available: bool
    karma: int


class RequestCreateIn(BaseModel):
    skill_id: int
    message: Optional[str] = Field(default=None, max_length=500)


class RequestOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    status: str
    message: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    requester_id: int
    requester_name: str
    provider_id: int
    provider_name: str
    skill_name: str


class RequestUpdateIn(BaseModel):
    status: str = Field(pattern="^(accepted|declined)$")