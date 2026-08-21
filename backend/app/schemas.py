from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field, model_validator


class SignupIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6, max_length=128)
    name: str = Field(min_length=1, max_length=100)
    lat: float | None = None
    lng: float | None = None
    accept_tos: bool = False
    accept_privacy: bool = False

    @model_validator(mode="after")
    def require_consent(self):
        if not self.accept_tos:
            raise ValueError("You must accept the Terms of Service to continue")
        if not self.accept_privacy:
            raise ValueError("You must accept the Privacy Policy to continue")
        return self


class LoginIn(BaseModel):
    email: EmailStr
    password: str


class SkillImageOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    path: str
    order: int


class SkillOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    blurb: str
    images: list[SkillImageOut] = []


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: EmailStr
    name: str
    is_available: bool
    karma: int
    grid: str | None = None
    created_at: datetime


class UserMeOut(UserOut):
    skills: list[SkillOut] = []
    phone: str | None = None
    tos_accepted_at: datetime | None = None
    privacy_accepted_at: datetime | None = None


class AuthOut(BaseModel):
    token: str
    user: UserMeOut


class UserUpdateIn(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    is_available: bool | None = None
    lat: float | None = None
    lng: float | None = None
    grid: str | None = Field(default=None, max_length=20)
    phone: str | None = Field(default=None, max_length=50)


class SkillCreateIn(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    blurb: str = Field(default="", max_length=500)
    image_paths: list[str] = Field(default=[], max_length=3)


class SkillSearchOut(BaseModel):
    skill_id: int
    skill_name: str
    blurb: str
    owner_id: int
    owner_name: str
    grid: str | None = None
    distance_km: float | None = None
    available: bool
    karma: int
    images: list[str] = []


class RequestCreateIn(BaseModel):
    skill_id: int
    message: str | None = Field(default=None, max_length=500)


class RequestOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    status: str
    message: str | None = None
    created_at: datetime
    updated_at: datetime
    requester_id: int
    requester_name: str
    provider_id: int
    provider_name: str
    skill_name: str


class RequestUpdateIn(BaseModel):
    status: str = Field(pattern="^(accepted|declined)$")
    share_phone: bool | None = None

    @model_validator(mode="after")
    def require_acceptance_choice(self):
        if self.status == "accepted" and self.share_phone is None:
            raise ValueError("share_phone is required when accepting")
        return self


class ChatMessageOut(BaseModel):
    id: int
    request_id: int
    sender_id: int
    sender_name: str
    body: str
    created_at: datetime


class RoomTokenOut(BaseModel):
    token: str
    expires_at: datetime
    request: RequestOut
    contact_info: dict[str, str]
