from __future__ import annotations

from sqlalchemy import func, select

from models.database import AllometricReference, DatabaseManager


class Calculator:
    """Queries a local SQL database to estimate carbon from diameter+height."""

    def __init__(self, db: DatabaseManager) -> None:
        self.db = db

    def estimate_carbon_tonnes(self, crown_diameter_m: float, height_m: float) -> float:
        """Nearest-neighbor lookup in (diameter,height) space.

        For production projects, replace this with project-specific allometric equations
        or interpolation from denser calibration tables.
        """
        with self.db.get_session() as session:
            distance_expr = (
                func.pow(AllometricReference.crown_diameter_m - crown_diameter_m, 2)
                + func.pow(AllometricReference.height_m - height_m, 2)
            )
            stmt = (
                select(AllometricReference)
                .order_by(distance_expr.asc())
                .limit(1)
            )
            row = session.execute(stmt).scalar_one_or_none()
            return float(row.carbon_tonnes) if row else 0.0
