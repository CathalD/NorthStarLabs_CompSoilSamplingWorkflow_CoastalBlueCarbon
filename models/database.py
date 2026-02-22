from __future__ import annotations

from pathlib import Path
from sqlalchemy import Column, Float, Integer, create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker


class Base(DeclarativeBase):
    pass


class AllometricReference(Base):
    """Reference lookup table linking crown geometry to stored carbon."""

    __tablename__ = "allometric_reference"

    id = Column(Integer, primary_key=True, autoincrement=True)
    crown_diameter_m = Column(Float, nullable=False)
    height_m = Column(Float, nullable=False)
    carbon_tonnes = Column(Float, nullable=False)


class DatabaseManager:
    def __init__(self, db_url: str = "sqlite:///data/opencarbon.db") -> None:
        if db_url.startswith("sqlite:///"):
            Path("data").mkdir(parents=True, exist_ok=True)
        self.engine = create_engine(db_url, future=True)
        self._session_factory = sessionmaker(bind=self.engine, class_=Session, expire_on_commit=False)

    def create_tables(self) -> None:
        Base.metadata.create_all(self.engine)

    def get_session(self) -> Session:
        return self._session_factory()

    def seed_defaults(self) -> None:
        """Seed simple default relationships for first run/demo mode."""
        with self.get_session() as session:
            exists = session.query(AllometricReference).first()
            if exists:
                return
            sample_rows = [
                AllometricReference(crown_diameter_m=2.0, height_m=4.0, carbon_tonnes=0.03),
                AllometricReference(crown_diameter_m=4.0, height_m=8.0, carbon_tonnes=0.12),
                AllometricReference(crown_diameter_m=6.0, height_m=12.0, carbon_tonnes=0.35),
                AllometricReference(crown_diameter_m=8.0, height_m=16.0, carbon_tonnes=0.75),
            ]
            session.add_all(sample_rows)
            session.commit()
