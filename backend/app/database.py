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


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
