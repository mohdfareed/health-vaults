"""
Pure Python re-implementation of HealthVaults analytics math.

Mirrors:
  - Shared/Services/Analytics/IntakeAnalyticsService.swift
  - Shared/Services/Analytics/MaintenanceService.swift
  - Shared/Services/Analytics/BudgetService.swift

All functions are stateless. No HealthKit, no Swift dependencies.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, timedelta

import numpy as np

from constants import *


# =============================================================================
# Sub-models
# =============================================================================


def ewma(
    series: dict[date, float],
    alpha: float = MAINTENANCE_ALPHA,
    ref_date: date | None = None,
    window_days: int = REGRESSION_WINDOW_DAYS,
) -> float | None:
    """Gap-aware EWMA matching IntakeAnalyticsService.computeEWMA.

    Args:
        series: date → value (e.g. daily calorie intake).
        alpha: smoothing factor.
        ref_date: end of window (default: latest date in series).
        window_days: only include data within this many days before ref_date.

    Returns:
        Smoothed value, or None if series is empty.
    """
    if not series:
        return None

    if ref_date is None:
        ref_date = max(series)

    cutoff = ref_date - timedelta(days=window_days)
    points = sorted((d, v) for d, v in series.items() if d > cutoff and d <= ref_date)
    if not points:
        return None

    s = points[0][1]
    for i in range(1, len(points)):
        gap = max(1, (points[i][0] - points[i - 1][0]).days)
        a_k = 1.0 - (1.0 - alpha) ** gap
        s = a_k * points[i][1] + (1.0 - a_k) * s
    return s


def wls_slope(
    weights: dict[date, float],
    ref_date: date | None = None,
    window_days: int = REGRESSION_WINDOW_DAYS,
    decay: float = REGRESSION_DECAY,
) -> float | None:
    """Weighted least squares slope matching MaintenanceService.computeWeightedSlope.

    Args:
        weights: date → weight in kg.
        ref_date: end of window.
        window_days: regression window.
        decay: exponential decay per day (λ).

    Returns:
        Slope in kg/day, or None if < 2 points.
    """
    if not weights:
        return None

    if ref_date is None:
        ref_date = max(weights)

    cutoff = ref_date - timedelta(days=window_days)
    points = sorted(
        ((d - ref_date).days, v) for d, v in weights.items() if d > cutoff and d <= ref_date
    )
    if len(points) < 2:
        return None

    # Exponential weights: λ^(days_ago), where days_ago = -t (t is negative)
    ts = np.array([t for t, _ in points], dtype=float)
    ws_vals = np.array([v for _, v in points], dtype=float)
    omegas = np.array([decay ** (-t) for t in ts])

    total_w = omegas.sum()
    mean_t = (omegas * ts).sum() / total_w
    mean_y = (omegas * ws_vals).sum() / total_w

    num = (omegas * (ts - mean_t) * (ws_vals - mean_y)).sum()
    den = (omegas * (ts - mean_t) ** 2).sum()
    if den == 0:
        return None

    return float(num / den)


def forbes_rho(
    body_fat_fraction: float | None,
    weight_kg: float | None,
) -> float:
    """Energy density of weight change via Forbes partition model.

    Args:
        body_fat_fraction: body fat as fraction 0-1, or None.
        weight_kg: body weight in kg, or None.

    Returns:
        ρ in kcal/kg.
    """
    if body_fat_fraction is None or weight_kg is None:
        return DEFAULT_RHO

    fat_mass = body_fat_fraction * weight_kg
    p = fat_mass / (fat_mass + FORBES_CONSTANT)
    return p * FAT_TISSUE_ENERGY + (1.0 - p) * LEAN_TISSUE_ENERGY


def confidence(
    n_points: int,
    span_days: int,
    min_points: int,
    window_days: int = REGRESSION_WINDOW_DAYS,
) -> float:
    """Confidence score: density × span.

    Args:
        n_points: number of data points in window.
        span_days: span from first to last point (days).
        min_points: minimum points for full density confidence.
        window_days: window size for full span confidence.

    Returns:
        Confidence in [0, 1].
    """
    density = min(1.0, n_points / min_points) if min_points > 0 else 0.0
    span = min(1.0, span_days / window_days) if window_days > 0 else 0.0
    return density * span


# =============================================================================
# Data helpers
# =============================================================================


def data_stats(
    series: dict[date, float],
    ref_date: date,
    window_days: int = REGRESSION_WINDOW_DAYS,
) -> tuple[int, int]:
    """Count and span of data points within window.

    Returns:
        (n_points, span_days)
    """
    cutoff = ref_date - timedelta(days=window_days)
    dates = sorted(d for d in series if d > cutoff and d <= ref_date)
    if not dates:
        return 0, 0
    return len(dates), (dates[-1] - dates[0]).days


# =============================================================================
# Full maintenance model
# =============================================================================


@dataclass
class MaintenanceResult:
    """Output of the maintenance model."""

    maintenance: float
    raw_slope_per_week: float  # kg/week, before clamping
    clamped_slope_per_week: float  # kg/week, after clamping
    blended_slope_per_week: float  # after confidence scaling
    rho: float  # kcal/kg
    smoothed_intake: float
    blended_intake: float
    weight_confidence: float
    calorie_confidence: float
    fallback_used: float
    is_valid: bool

    # Flags
    is_slope_clamped: bool = False
    is_rho_estimated: bool = False
    is_maintenance_suspect: bool = False


def compute_maintenance(
    weights: dict[date, float],
    calories: dict[date, float],
    body_fat: dict[date, float] | None = None,
    ref_date: date | None = None,
    window_days: int = REGRESSION_WINDOW_DAYS,
    fallback: float = BASELINE_MAINTENANCE,
) -> MaintenanceResult:
    """Full maintenance model matching MaintenanceService.

    Args:
        weights: date → weight in kg.
        calories: date → calorie intake in kcal.
        body_fat: date → body fat fraction (0-1), or None.
        ref_date: reference date (default: today).
        window_days: regression window.
        fallback: fallback maintenance when confidence is low.

    Returns:
        MaintenanceResult with all intermediate values.
    """
    if ref_date is None:
        ref_date = date.today()
    if body_fat is None:
        body_fat = {}

    # --- Weight slope ---
    raw_slope_day = wls_slope(weights, ref_date, window_days)
    raw_slope_week = (raw_slope_day or 0.0) * 7.0
    clamped_slope = max(-MAX_WEIGHT_LOSS_PER_WEEK, min(MAX_WEIGHT_GAIN_PER_WEEK, raw_slope_week))
    is_slope_clamped = raw_slope_week != clamped_slope and raw_slope_day is not None

    # --- Weight confidence ---
    w_n, w_span = data_stats(weights, ref_date, window_days)
    q_w = confidence(w_n, w_span, MIN_WEIGHT_DATA_POINTS, window_days)
    blended_slope = clamped_slope * q_w

    # --- Intake smoothing ---
    smoothed = ewma(calories, MAINTENANCE_ALPHA, ref_date, window_days)
    smoothed_intake = smoothed if smoothed is not None else 0.0

    # --- Calorie confidence ---
    c_n, c_span = data_stats(calories, ref_date, window_days)
    q_c = confidence(c_n, c_span, MIN_CALORIE_DATA_POINTS, window_days)
    blended_intake = smoothed_intake * q_c + fallback * (1.0 - q_c)

    # --- Forbes ρ ---
    latest_bf = None
    latest_weight = None
    if body_fat:
        bf_dates = sorted(d for d in body_fat if d <= ref_date)
        if bf_dates:
            latest_bf = body_fat[bf_dates[-1]]
    if weights:
        w_dates = sorted(d for d in weights if d <= ref_date)
        if w_dates:
            latest_weight = weights[w_dates[-1]]

    rho = forbes_rho(latest_bf, latest_weight)
    is_rho_estimated = latest_bf is None

    # --- Maintenance ---
    maintenance = blended_intake - (blended_slope * rho / 7.0)
    is_maintenance_suspect = maintenance < MIN_DAILY_BUDGET

    # --- Validity ---
    w_valid = w_n >= MIN_WEIGHT_DATA_POINTS and w_span >= window_days / 2
    c_valid = c_n >= MIN_CALORIE_DATA_POINTS and c_span >= window_days / 2
    is_valid = w_valid or c_valid

    return MaintenanceResult(
        maintenance=maintenance,
        raw_slope_per_week=raw_slope_week,
        clamped_slope_per_week=clamped_slope,
        blended_slope_per_week=blended_slope,
        rho=rho,
        smoothed_intake=smoothed_intake,
        blended_intake=blended_intake,
        weight_confidence=q_w,
        calorie_confidence=q_c,
        fallback_used=fallback,
        is_valid=is_valid,
        is_slope_clamped=is_slope_clamped,
        is_rho_estimated=is_rho_estimated,
        is_maintenance_suspect=is_maintenance_suspect,
    )


# =============================================================================
# Budget model
# =============================================================================


@dataclass
class BudgetResult:
    """Output of the budget model."""

    base_budget: float
    credit: float
    daily_adjustment: float
    budget: float
    days_left: int
    is_adjustment_clamped: bool = False
    is_budget_clamped: bool = False


def compute_budget(
    maintenance: float,
    adjustment: float,
    week_intakes: dict[date, float],
    days_left: int,
) -> BudgetResult:
    """Daily budget matching BudgetService.

    Args:
        maintenance: estimated TDEE (kcal/day).
        adjustment: user goal offset (kcal/day).
        week_intakes: this week's logged intakes (date → kcal).
        days_left: days remaining in the week (≥1).

    Returns:
        BudgetResult with all intermediate values.
    """
    days_left = max(1, days_left)
    base = maintenance + adjustment
    logged_days = len(week_intakes)
    credit = base * logged_days - sum(week_intakes.values())

    raw_adj = credit / days_left
    clamped_adj = max(-MAX_DAILY_ADJUSTMENT, min(MAX_DAILY_ADJUSTMENT, raw_adj))
    is_adj_clamped = abs(raw_adj) > MAX_DAILY_ADJUSTMENT

    raw_budget = base + clamped_adj
    budget = max(MIN_DAILY_BUDGET, min(MAX_DAILY_BUDGET, raw_budget))
    is_budget_clamped = budget != raw_budget

    return BudgetResult(
        base_budget=base,
        credit=credit,
        daily_adjustment=clamped_adj,
        budget=budget,
        days_left=days_left,
        is_adjustment_clamped=is_adj_clamped,
        is_budget_clamped=is_budget_clamped,
    )


# =============================================================================
# Data generators
# =============================================================================


def constant_weights(value: float, days: int, ref: date | None = None) -> dict[date, float]:
    """Generate constant weight data for `days` days ending at ref_date."""
    ref = ref or date.today()
    return {ref - timedelta(days=d): value for d in range(days)}


def constant_calories(value: float, days: int, ref: date | None = None) -> dict[date, float]:
    """Generate constant calorie data for `days` days ending at ref_date."""
    ref = ref or date.today()
    return {ref - timedelta(days=d): value for d in range(days)}


def linear_weight_trend(
    latest: float, slope_per_week: float, days: int, ref: date | None = None
) -> dict[date, float]:
    """Generate a linear weight trend.

    Weight on ref_date = `latest`. Goes backward by `slope_per_week`.
    """
    ref = ref or date.today()
    return {
        ref - timedelta(days=d): latest - (slope_per_week / 7.0) * d for d in range(days)
    }


def sparse_weights(
    value: float, total_days: int, stride: int, ref: date | None = None
) -> dict[date, float]:
    """Generate sparse weight data at regular intervals."""
    ref = ref or date.today()
    return {ref - timedelta(days=d): value for d in range(0, total_days, stride)}
