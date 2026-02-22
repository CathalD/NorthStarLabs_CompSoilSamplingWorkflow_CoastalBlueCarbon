"""High-level orchestration helpers for OpenCarbon."""

from __future__ import annotations

from models.calculator import Calculator


def summarize_total_carbon(diameters_m: list[float], heights_m: list[float], calculator: Calculator) -> float:
    total = 0.0
    for d, h in zip(diameters_m, heights_m):
        total += calculator.estimate_carbon_tonnes(d, h)
    return total
