from sqlalchemy import create_engine, event, inspect, text
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from .config import DATA_DIR, settings

for _dir in (DATA_DIR,):
    _dir.mkdir(parents=True, exist_ok=True)

connect_args = (
    {"check_same_thread": False} if settings.DATABASE_URL.startswith("sqlite") else {}
)

engine = create_engine(settings.DATABASE_URL, connect_args=connect_args)


@event.listens_for(engine, "connect")
def set_sqlite_pragma(dbapi_connection, connection_record):
    if not settings.DATABASE_URL.startswith("sqlite"):
        return
    cursor = dbapi_connection.cursor()
    cursor.execute("PRAGMA foreign_keys=ON")
    cursor.close()


SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def run_startup_migrations() -> None:  # noqa: C901
    inspector = inspect(engine)
    if "requests" not in inspector.get_table_names():
        return
    columns = {column["name"] for column in inspector.get_columns("requests")}
    if "provider_share_phone" not in columns:
        with engine.begin() as connection:
            connection.execute(
                text(
                    "ALTER TABLE requests ADD COLUMN provider_share_phone "
                    "BOOLEAN NOT NULL DEFAULT FALSE"
                )
            )

    if "users" in inspector.get_table_names():
        user_columns = {column["name"] for column in inspector.get_columns("users")}
        consent_columns = {
            "tos_accepted_at": "DATETIME",
            "privacy_accepted_at": "DATETIME",
            "tos_version": "VARCHAR(20)",
            "privacy_version": "VARCHAR(20)",
        }
        missing = {
            name: ddl
            for name, ddl in consent_columns.items()
            if name not in user_columns
        }
        if missing:
            with engine.begin() as connection:
                for name, ddl in missing.items():
                    connection.execute(
                        text(f"ALTER TABLE users ADD COLUMN {name} {ddl}")
                    )

        if "profile_image" not in user_columns:
            with engine.begin() as connection:
                connection.execute(
                    text("ALTER TABLE users ADD COLUMN profile_image VARCHAR(500)")
                )

    if "blocked_tokens" not in inspector.get_table_names():
        with engine.begin() as connection:
            connection.execute(
                text(
                    "CREATE TABLE blocked_tokens ("
                    "jti VARCHAR(32) PRIMARY KEY, "
                    "blocked_at DATETIME NOT NULL"
                    ")"
                )
            )

    if "password_reset_tokens" not in inspector.get_table_names():
        with engine.begin() as connection:
            connection.execute(
                text(
                    "CREATE TABLE password_reset_tokens ("
                    "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                    "user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
                    "token_hash VARCHAR(64) NOT NULL UNIQUE, "
                    "expires_at DATETIME NOT NULL, "
                    "used BOOLEAN NOT NULL DEFAULT FALSE, "
                    "created_at DATETIME NOT NULL"
                    ")"
                )
            )

    if "reports" not in inspector.get_table_names():
        with engine.begin() as connection:
            connection.execute(
                text(
                    "CREATE TABLE reports ("
                    "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                    "reporter_id INTEGER NOT NULL "
                    "REFERENCES users(id) ON DELETE CASCADE, "
                    "reported_id INTEGER NOT NULL "
                    "REFERENCES users(id) ON DELETE CASCADE, "
                    "reason VARCHAR(50) NOT NULL, "
                    "details TEXT, "
                    "created_at DATETIME NOT NULL"
                    ")"
                )
            )

    if "blocked_users" not in inspector.get_table_names():
        with engine.begin() as connection:
            connection.execute(
                text(
                    "CREATE TABLE blocked_users ("
                    "blocker_id INTEGER NOT NULL "
                    "REFERENCES users(id) ON DELETE CASCADE, "
                    "blocked_id INTEGER NOT NULL "
                    "REFERENCES users(id) ON DELETE CASCADE, "
                    "created_at DATETIME NOT NULL, "
                    "PRIMARY KEY (blocker_id, blocked_id)"
                    ")"
                )
            )

    if "ratings" not in inspector.get_table_names():
        with engine.begin() as connection:
            connection.execute(
                text(
                    "CREATE TABLE ratings ("
                    "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                    "request_id INTEGER NOT NULL "
                    "REFERENCES requests(id) "
                    "ON DELETE CASCADE UNIQUE, "
                    "rater_id INTEGER NOT NULL "
                    "REFERENCES users(id) ON DELETE CASCADE, "
                    "rated_id INTEGER NOT NULL "
                    "REFERENCES users(id) ON DELETE CASCADE, "
                    "stars INTEGER NOT NULL, "
                    "review TEXT, "
                    "created_at DATETIME NOT NULL"
                    ")"
                )
            )

    if "message_read_cursors" not in inspector.get_table_names():
        with engine.begin() as connection:
            connection.execute(
                text(
                    "CREATE TABLE message_read_cursors ("
                    "user_id INTEGER NOT NULL "
                    "REFERENCES users ON DELETE CASCADE, "
                    "request_id INTEGER NOT NULL "
                    "REFERENCES requests ON DELETE CASCADE, "
                    "last_read_message_id INTEGER NOT NULL DEFAULT 0, "
                    "updated_at DATETIME NOT NULL, "
                    "PRIMARY KEY (user_id, request_id)"
                    ")"
                )
            )

    if "chat_messages" in inspector.get_table_names():
        chat_columns = {
            column["name"] for column in inspector.get_columns("chat_messages")
        }
        if "image_url" not in chat_columns:
            with engine.begin() as connection:
                connection.execute(
                    text("ALTER TABLE chat_messages ADD COLUMN image_url VARCHAR(500)")
                )


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
