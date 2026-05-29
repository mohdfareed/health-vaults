"""
Scenario simulation for testing the maintenance pipeline.

Defines scenarios as simple parameter bundles, generates synthetic
weight/calorie/body-fat data, and provides a plotting harness that
visualizes every stage of compute_maintenance over time.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, timedelta
from typing import Callable

import matplotlib.dates as mdates
import matplotlib.pyplot as plt
import numpy as np
from constants import *
from model import (
    MaintenanceResult,
    compute_maintenance,
    data_stats,
)

# ── Scenario definition ─────────────────────────────────────────────


@dataclass
class Scenario:
    """A synthetic dataset for pipeline testing.

    All rates are per-week. Noise is Gaussian std-dev.
    ``intake`` can be a constant or a callable(day_index) → kcal
    for time-varying intake patterns.
    """

    name: str
    true_tdee: float = 2200.0
    intake: float | Callable[[int], float] = 1800.0
    weight_start: float = 80.0
    weight_slope: float = -0.5  # kg/week (negative = losing)
    days: int = 42
    body_fat: float | None = None  # fraction 0–1, or None
    noise_weight: float = 0.3
    noise_calories: float = 100.0
    weight_freq: int = 1  # weigh every N days (1 = daily)
    missing_weight_days: list[range] = field(default_factory=list)
    missing_calorie_days: list[range] = field(default_factory=list)


def generate(
    sc: Scenario,
    ref_date: date,
    seed: int = 0,
) -> tuple[dict[date, float], dict[date, float], dict[date, float]]:
    """Generate (weights, calories, body_fat) dicts from a scenario."""
    rng = np.random.default_rng(seed)
    weights: dict[date, float] = {}
    calories: dict[date, float] = {}
    body_fat: dict[date, float] = {}

    skip_w = set()
    for r in sc.missing_weight_days:
        skip_w.update(r)
    skip_c = set()
    for r in sc.missing_calorie_days:
        skip_c.update(r)

    for d in range(sc.days):
        dt = ref_date - timedelta(days=sc.days - 1 - d)

        # Weight: linear trend + noise, respecting frequency and gaps
        if d not in skip_w and d % sc.weight_freq == 0:
            true_w = sc.weight_start + (sc.weight_slope / 7) * d
            weights[dt] = true_w + rng.normal(0, sc.noise_weight)

        # Calories: constant or callable + noise, respecting gaps
        if d not in skip_c:
            base_cal = sc.intake(d) if callable(sc.intake) else sc.intake
            calories[dt] = base_cal + rng.normal(0, sc.noise_calories)

        # Body fat: constant if provided
        if sc.body_fat is not None and dt not in body_fat:
            body_fat[dt] = sc.body_fat

    return weights, calories, body_fat


# ── Predefined scenarios ─────────────────────────────────────────────


SCENARIOS = {
    "steady": Scenario(
        name="Steady State",
        true_tdee=2200,
        intake=2200,
        weight_slope=0.0,
        noise_weight=0.4,
        noise_calories=150,
    ),
    "deficit": Scenario(
        name="500 kcal Deficit",
        true_tdee=2200,
        intake=1700,
        weight_slope=-0.5,
        body_fat=0.25,
    ),
    "surplus": Scenario(
        name="300 kcal Surplus",
        true_tdee=2200,
        intake=2500,
        weight_slope=0.3,
        body_fat=0.20,
    ),
    "new_user": Scenario(
        name="New User (data ramp-up)",
        true_tdee=2200,
        intake=1800,
        weight_slope=-0.5,
        days=28,
        weight_freq=2,  # weighs every other day
        noise_weight=0.5,
        noise_calories=200,
    ),
    "gap": Scenario(
        name="Week-long gap mid-window",
        true_tdee=2200,
        intake=1800,
        weight_slope=-0.5,
        missing_weight_days=[range(14, 21)],
        missing_calorie_days=[range(14, 21)],
    ),
    "regime_shift": Scenario(
        name="Diet break → resume",
        true_tdee=2200,
        intake=lambda d: 2200 if 14 <= d < 24 else 1700,
        weight_start=80.0,
        weight_slope=-0.5,  # approximate
        days=42,
    ),
    "sparse": Scenario(
        name="Sparse weigher (weekly)",
        true_tdee=2200,
        intake=1800,
        weight_slope=-0.5,
        weight_freq=7,
        days=42,
    ),
    "noisy": Scenario(
        name="Very noisy data",
        true_tdee=2200,
        intake=1800,
        weight_slope=-0.5,
        noise_weight=1.0,
        noise_calories=400,
    ),
}


# ── Pipeline visualisation ───────────────────────────────────────────


def rolling_pipeline(
    weights: dict[date, float],
    calories: dict[date, float],
    body_fat: dict[date, float],
    ref_end: date,
    n_days: int,
) -> tuple[list[date], list[MaintenanceResult]]:
    """Run compute_maintenance with a sliding ref_date, one per day."""
    dates = []
    results = []
    for i in range(n_days):
        ref = ref_end - timedelta(days=n_days - 1 - i)
        w_sub = {d: v for d, v in weights.items() if d <= ref}
        c_sub = {d: v for d, v in calories.items() if d <= ref}
        bf_sub = {d: v for d, v in body_fat.items() if d <= ref}
        r = compute_maintenance(w_sub, c_sub, bf_sub, ref_date=ref)
        dates.append(ref)
        results.append(r)
    return dates, results


def plot_pipeline(
    sc: Scenario,
    ref_date: date,
    seed: int = 0,
    figsize: tuple[float, float] = (14, 10),
) -> plt.Figure:
    """Plot the full maintenance pipeline for one scenario.

    6 panels:
      1. Raw weight + WLS fit line
      2. Raw calories + EWMA
      3. Confidence (weight & calorie) over time
      4. Blending: smoothed vs blended intake, raw vs blended slope
      5. ρ (energy density) and maintenance over time
      6. Validity flag + maintenance vs true TDEE
    """
    weights, calories, body_fat = generate(sc, ref_date, seed)
    dates, results = rolling_pipeline(weights, calories, body_fat, ref_date, sc.days)

    fig, axes = plt.subplots(3, 2, figsize=figsize, sharex=True)
    fig.suptitle(f"Pipeline: {sc.name}", fontsize=13, fontweight="bold")
    date_fmt = mdates.DateFormatter("%b %d")

    for row in axes:
        for ax in row:
            ax.xaxis.set_major_formatter(date_fmt)
            ax.xaxis.set_major_locator(mdates.AutoDateLocator())
            plt.setp(
                ax.xaxis.get_majorticklabels(), rotation=30, ha="right", fontsize=7
            )

    # ── Panel 1: Weight + WLS ──
    ax = axes[0, 0]
    w_dates = sorted(weights)
    ax.scatter(
        w_dates,
        [weights[d] for d in w_dates],
        s=12,
        alpha=0.5,
        color="C0",
        label="Weight",
    )
    ax.set(ylabel="kg", title="Weight + Slope")
    ax_slope = ax.twinx()
    ax_slope.plot(
        dates,
        [r.raw_slope_per_week for r in results],
        "C3-",
        lw=1,
        alpha=0.5,
        label="Raw slope",
    )
    ax_slope.plot(
        dates,
        [r.blended_slope_per_week for r in results],
        "C1-",
        lw=1.5,
        label="Blended slope",
    )
    ax_slope.axhline(
        sc.weight_slope,
        color="gray",
        ls="--",
        alpha=0.4,
        label=f"True: {sc.weight_slope:+.1f}",
    )
    ax_slope.set(ylabel="kg/wk")
    h1, l1 = ax.get_legend_handles_labels()
    h2, l2 = ax_slope.get_legend_handles_labels()
    ax.legend(h1 + h2, l1 + l2, fontsize=6, loc="upper right")

    # ── Panel 2: Calories + EWMA ──
    ax = axes[0, 1]
    c_dates = sorted(calories)
    ax.bar(c_dates, [calories[d] for d in c_dates], alpha=0.2, color="C0", width=0.8)
    ax.plot(
        dates,
        [r.smoothed_intake for r in results],
        "C1-",
        lw=1.5,
        label="EWMA (smoothed)",
    )
    ax.plot(
        dates,
        [r.blended_intake for r in results],
        "C3--",
        lw=1.5,
        label="Blended intake",
    )
    true_intake = (
        sc.intake
        if not callable(sc.intake)
        else np.mean([sc.intake(d) for d in range(sc.days)])
    )
    ax.axhline(true_intake, color="gray", ls="--", alpha=0.4, label="Avg intake")
    ax.axhline(
        BASELINE_MAINTENANCE,
        color="C4",
        ls=":",
        alpha=0.3,
        label=f"Fallback={BASELINE_MAINTENANCE:.0f}",
    )
    ax.set(ylabel="kcal", title="Calories + EWMA + Blending")
    ax.legend(fontsize=6, loc="upper right")

    # ── Panel 3: Confidence ──
    ax = axes[1, 0]
    ax.plot(
        dates, [r.weight_confidence for r in results], "C1-", lw=2, label="Weight q"
    )
    ax.plot(
        dates, [r.calorie_confidence for r in results], "C2-", lw=2, label="Calorie q"
    )
    ax.axhline(1.0, color="gray", ls="--", alpha=0.3)
    # Mark min-point thresholds
    ax.axvline(
        dates[min(MIN_WEIGHT_DATA_POINTS - 1, len(dates) - 1)],
        color="C1",
        ls=":",
        alpha=0.4,
        label=f"W min pts ({MIN_WEIGHT_DATA_POINTS})",
    )
    ax.axvline(
        dates[min(MIN_CALORIE_DATA_POINTS - 1, len(dates) - 1)],
        color="C2",
        ls=":",
        alpha=0.4,
        label=f"C min pts ({MIN_CALORIE_DATA_POINTS})",
    )
    ax.set(ylabel="Confidence", title="Confidence (density × span)", ylim=(-0.05, 1.1))
    ax.legend(fontsize=6)

    # ── Panel 4: Blending detail ──
    ax = axes[1, 1]
    smoothed = [r.smoothed_intake for r in results]
    blended = [r.blended_intake for r in results]
    fallback_frac = [1.0 - r.calorie_confidence for r in results]
    ax.fill_between(
        dates,
        0,
        fallback_frac,
        alpha=0.2,
        color="C3",
        label="Fallback fraction (1−q_c)",
    )
    ax.plot(dates, fallback_frac, "C3-", lw=1.5)
    ax2 = ax.twinx()
    ax2.plot(dates, smoothed, "C0-", lw=1, alpha=0.6, label="Smoothed intake")
    ax2.plot(dates, blended, "C1-", lw=1.5, label="Blended intake")
    ax2.axhline(BASELINE_MAINTENANCE, color="C4", ls=":", alpha=0.3)
    ax.set(ylabel="Fallback fraction", title="Intake Blending", ylim=(-0.05, 1.1))
    ax2.set(ylabel="kcal")
    # Combined legend
    h1, l1 = ax.get_legend_handles_labels()
    h2, l2 = ax2.get_legend_handles_labels()
    ax.legend(h1 + h2, l1 + l2, fontsize=6, loc="upper right")

    # ── Panel 5: ρ + Maintenance ──
    ax = axes[2, 0]
    ax.plot(dates, [r.maintenance for r in results], "C0-", lw=2, label="Estimated M")
    ax.axhline(
        sc.true_tdee,
        color="gray",
        ls="--",
        alpha=0.5,
        label=f"True TDEE = {sc.true_tdee}",
    )
    ax.axhline(
        BASELINE_MAINTENANCE,
        color="C4",
        ls=":",
        alpha=0.3,
        label=f"Fallback = {BASELINE_MAINTENANCE:.0f}",
    )
    rho_vals = [r.rho for r in results]
    if len(set(rho_vals)) > 1:  # only show if ρ varies
        ax_rho = ax.twinx()
        ax_rho.plot(dates, rho_vals, "C2--", lw=1, alpha=0.6, label="ρ")
        ax_rho.set(ylabel="ρ (kcal/kg)")
    ax.set(ylabel="kcal/day", title="Maintenance Estimate")
    ax.legend(fontsize=6)

    # ── Panel 6: Validity + flags ──
    ax = axes[2, 1]
    valid = [1 if r.is_valid else 0 for r in results]
    suspect = [1 if r.is_maintenance_suspect else 0 for r in results]
    clamped = [1 if r.is_slope_clamped else 0 for r in results]
    ax.fill_between(dates, 0, valid, alpha=0.3, color="C2", label="Valid", step="mid")
    ax.fill_between(
        dates,
        0,
        suspect,
        alpha=0.3,
        color="C3",
        label="Suspect (M < min budget)",
        step="mid",
    )
    ax.fill_between(
        dates, 0, clamped, alpha=0.2, color="C1", label="Slope clamped", step="mid"
    )
    # Show data point counts
    w_counts = []
    c_counts = []
    for i, ref in enumerate(dates):
        w_sub = {d: v for d, v in weights.items() if d <= ref}
        c_sub = {d: v for d, v in calories.items() if d <= ref}
        wn, _ = data_stats(w_sub, ref)
        cn, _ = data_stats(c_sub, ref)
        w_counts.append(wn)
        c_counts.append(cn)
    ax_n = ax.twinx()
    ax_n.plot(
        dates,
        w_counts,
        "C1:",
        lw=1,
        alpha=0.6,
        label=f"W pts (need {MIN_WEIGHT_DATA_POINTS})",
    )
    ax_n.plot(
        dates,
        c_counts,
        "C2:",
        lw=1,
        alpha=0.6,
        label=f"C pts (need {MIN_CALORIE_DATA_POINTS})",
    )
    ax_n.axhline(MIN_WEIGHT_DATA_POINTS, color="C1", ls="--", alpha=0.2)
    ax_n.axhline(MIN_CALORIE_DATA_POINTS, color="C2", ls="--", alpha=0.2)
    ax_n.set(ylabel="# data points")
    ax.set(ylabel="Flag", title="Validity & Flags", ylim=(-0.1, 1.5))
    h1, l1 = ax.get_legend_handles_labels()
    h2, l2 = ax_n.get_legend_handles_labels()
    ax.legend(h1 + h2, l1 + l2, fontsize=6, loc="upper right")

    plt.tight_layout()
    return fig


def plot_scenarios(
    scenarios: list[Scenario],
    ref_date: date,
    seed: int = 0,
) -> list[plt.Figure]:
    """Plot pipeline for multiple scenarios."""
    figs = []
    for sc in scenarios:
        figs.append(plot_pipeline(sc, ref_date, seed))
    return figs
