"""
Model constants — mirrors Shared/Config.swift exactly.

Keep in sync with Config.swift. When tuning, change here first,
validate in notebooks, then port to Swift.

Constants are split into two categories:
  LITERATURE — from published research, not tunable without scientific justification
  TUNABLE   — developer-adjustable knobs that control model behavior
"""

# =============================================================================
# TUNABLE — Developer Knobs
# =============================================================================

# Regression window for maintenance estimation (days).
REGRESSION_WINDOW_DAYS = 28

# Weighted regression decay factor (per day).
# 0.9 → last 7 days ≈ 52% of total weight in regression.
REGRESSION_DECAY = 0.9

# EWMA alpha for maintenance (long-term intake).
# 0.1 → ~7-day half-life.
MAINTENANCE_ALPHA = 0.1

# Minimum data points for full confidence.
MIN_WEIGHT_DATA_POINTS = 7
MIN_CALORIE_DATA_POINTS = 14

# Maximum physiological weight change rate (kg/week).
MAX_WEIGHT_LOSS_PER_WEEK = 1.0
MAX_WEIGHT_GAIN_PER_WEEK = 0.75

# Budget safety bounds (kcal/day).
MIN_DAILY_BUDGET = 1000.0
MAX_DAILY_BUDGET = 6000.0
MAX_DAILY_ADJUSTMENT = 500.0

# Fallback estimates.
WEIGHT_BASED_BASELINE_MULTIPLIER = 30.0  # kcal/kg/day
BASELINE_MAINTENANCE = 2200.0  # population average TDEE

# Historical fallback stages (days).
HISTORICAL_FETCH_STAGES = [180, 365, 730, 1825, 3650]

# =============================================================================
# LITERATURE — Published Research Values
# =============================================================================

# Forbes partition model (Forbes 2000, Hall 2008).
FAT_TISSUE_ENERGY = 9_440.0   # kcal/kg
LEAN_TISSUE_ENERGY = 1_816.0  # kcal/kg
FORBES_CONSTANT = 10.4        # kg
DEFAULT_RHO = 7_350.0         # kcal/kg at ~34% BF
