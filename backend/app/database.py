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


def run_startup_migrations() -> None:
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
        if "banned_until" not in user_columns:
            with engine.begin() as connection:
                connection.execute(
                    text("ALTER TABLE users ADD COLUMN banned_until DATETIME")
                )

    if "reports" in inspector.get_table_names():
        indexes = {index["name"] for index in inspector.get_indexes("reports")}
        if "uq_report_target" not in indexes:
            with engine.begin() as connection:
                connection.execute(
                    text(
                        "CREATE UNIQUE INDEX IF NOT EXISTS uq_report_target "
                        "ON reports (reporter_id, content_type, content_id)"
                    )
                )

    if "users" in inspector.get_table_names():
        user_columns = {column["name"] for column in inspector.get_columns("users")}
        tfa_columns = {
            "totp_secret": "TEXT",
            "two_factor_enabled": "BOOLEAN NOT NULL DEFAULT FALSE",
            "recovery_codes": "TEXT",
        }
        tfa_missing = {
            name: ddl
            for name, ddl in tfa_columns.items()
            if name not in user_columns
        }
        if tfa_missing:
            with engine.begin() as connection:
                for name, ddl in tfa_missing.items():
                    connection.execute(
                        text(f"ALTER TABLE users ADD COLUMN {name} {ddl}")
                    )

    if "hidden_requests" not in inspector.get_table_names():
        with engine.begin() as connection:
            connection.execute(
                text(
                    "CREATE TABLE hidden_requests ("
                    "user_id INTEGER NOT NULL "
                    "REFERENCES users(id) ON DELETE CASCADE, "
                    "request_id INTEGER NOT NULL "
                    "REFERENCES requests(id) ON DELETE CASCADE, "
                    "created_at DATETIME NOT NULL, "
                    "PRIMARY KEY (user_id, request_id)"
                    ")"
                )
            )

    if "onesignal_players" not in inspector.get_table_names():
        with engine.begin() as connection:
            connection.execute(
                text(
                    "CREATE TABLE onesignal_players ("
                    "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                    "user_id INTEGER NOT NULL "
                    "REFERENCES users(id) ON DELETE CASCADE, "
                    "player_id VARCHAR(255) NOT NULL UNIQUE, "
                    "created_at DATETIME NOT NULL"
                    ")"
                )
            )

    if "password_reset_codes" not in inspector.get_table_names():
        with engine.begin() as connection:
            connection.execute(
                text(
                    "CREATE TABLE password_reset_codes ("
                    "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                    "user_id INTEGER NOT NULL "
                    "REFERENCES users(id) ON DELETE CASCADE, "
                    "code_hash VARCHAR(64) NOT NULL, "
                    "expires_at DATETIME NOT NULL, "
                    "used BOOLEAN NOT NULL DEFAULT FALSE, "
                    "created_at DATETIME NOT NULL"
                    ")"
                )
            )

    if "tips" not in inspector.get_table_names():
        with engine.begin() as connection:
            connection.execute(
                text(
                    "CREATE TABLE tips ("
                    "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                    "sender_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
                    "recipient_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
                    "amount_cents INTEGER NOT NULL, "
                    "recipient_amount_cents INTEGER NOT NULL DEFAULT 0, "
                    "platform_fee_cents INTEGER NOT NULL DEFAULT 0, "
                    "currency VARCHAR(10) NOT NULL DEFAULT 'USD', "
                    "product_id VARCHAR(100), "
                    "transaction_id VARCHAR(255), "
                    "status VARCHAR(20) NOT NULL DEFAULT 'pending', "
                    "payout_status VARCHAR(20) NOT NULL DEFAULT 'pending', "
                    "created_at DATETIME NOT NULL"
                    ")"
                )
            )
    if "tips" in inspector.get_table_names():
        cols = {c["name"] for c in inspector.get_columns("tips")}
        for col, ddl in [
            ("recipient_amount_cents", "INTEGER NOT NULL DEFAULT 0"),
            ("platform_fee_cents", "INTEGER NOT NULL DEFAULT 0"),
            ("payout_status", "VARCHAR(20) NOT NULL DEFAULT 'pending'"),
        ]:
            if col not in cols:
                with engine.begin() as connection:
                    connection.execute(text(f"ALTER TABLE tips ADD COLUMN {col} {ddl}"))


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
