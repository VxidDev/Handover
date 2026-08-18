from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, String, Text, false
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    name: Mapped[str] = mapped_column(String(100))
    is_available: Mapped[bool] = mapped_column(Boolean, default=True)
    karma: Mapped[int] = mapped_column(default=0)
    lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    grid: Mapped[str | None] = mapped_column(String(20), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    skills: Mapped[list["Skill"]] = relationship(
        back_populates="owner",
        cascade="all, delete-orphan",
    )
    sent_requests: Mapped[list["Request"]] = relationship(
        back_populates="requester",
        foreign_keys="Request.requester_id",
        cascade="all, delete-orphan",
    )
    received_requests: Mapped[list["Request"]] = relationship(
        back_populates="provider",
        foreign_keys="Request.provider_id",
        cascade="all, delete-orphan",
    )
    private_contact: Mapped["PrivateContact | None"] = relationship(
        back_populates="user",
        cascade="all, delete-orphan",
        uselist=False,
    )


class PrivateContact(Base):
    __tablename__ = "private_contacts"

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    encrypted_phone: Mapped[str] = mapped_column(Text)

    user: Mapped["User"] = relationship(back_populates="private_contact")


class Skill(Base):
    __tablename__ = "skills"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    name: Mapped[str] = mapped_column(String(100))
    blurb: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    owner: Mapped["User"] = relationship(back_populates="skills")

    requests: Mapped[list["Request"]] = relationship(
        back_populates="skill",
        passive_deletes=True,
    )

    images: Mapped[list["SkillImage"]] = relationship(
        back_populates="skill",
        cascade="all, delete-orphan",
        order_by="SkillImage.order",
    )

class SkillImage(Base):
    __tablename__ = "skill_images"

    id: Mapped[int] = mapped_column(primary_key=True)
    skill_id: Mapped[int] = mapped_column(
        ForeignKey("skills.id", ondelete="CASCADE"), index=True
    )
    path: Mapped[str] = mapped_column(String(500))
    order: Mapped[int] = mapped_column(default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    skill: Mapped["Skill"] = relationship(back_populates="images")


class Request(Base):
    __tablename__ = "requests"

    id: Mapped[int] = mapped_column(primary_key=True)
    requester_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    provider_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    skill_id: Mapped[int] = mapped_column(
        ForeignKey("skills.id", ondelete="CASCADE"), index=True
    )
    message: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="pending")
    provider_share_phone: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default=false()
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow
    )

    requester: Mapped["User"] = relationship(
        back_populates="sent_requests", foreign_keys=[requester_id]
    )
    provider: Mapped["User"] = relationship(
        back_populates="received_requests", foreign_keys=[provider_id]
    )
    skill: Mapped["Skill"] = relationship(back_populates="requests")
    messages: Mapped[list["ChatMessage"]] = relationship(
        back_populates="request",
        cascade="all, delete-orphan",
    )
    disclosures: Mapped[list["DisclosureLog"]] = relationship(
        back_populates="request",
        cascade="all, delete-orphan",
    )


class DisclosureLog(Base):
    __tablename__ = "disclosure_logs"

    id: Mapped[int] = mapped_column(primary_key=True)
    request_id: Mapped[int] = mapped_column(
        ForeignKey("requests.id", ondelete="CASCADE"), index=True
    )
    owner_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    viewer_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    field: Mapped[str] = mapped_column(String(50))
    reason: Mapped[str] = mapped_column(String(100))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    request: Mapped["Request"] = relationship(back_populates="disclosures")


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id: Mapped[int] = mapped_column(primary_key=True)
    request_id: Mapped[int] = mapped_column(
        ForeignKey("requests.id", ondelete="CASCADE"), index=True
    )
    sender_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    body: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    request: Mapped["Request"] = relationship(back_populates="messages")
    sender: Mapped["User"] = relationship()
