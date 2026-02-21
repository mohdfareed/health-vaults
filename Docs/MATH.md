# Mathematical Models

Source of truth for all analytics math. Code implements exactly this.

---

## 1. Maintenance Model

**Goal:** Estimate daily energy expenditure $M$ (kcal/day) from raw user data.

### Inputs

Three time series (all may be empty/sparse):

$$W = \{(t_i, w_i)\}, \quad C = \{(t_j, c_j)\}, \quad B = \{(t_k, b_k)\}$$

Weight (kg), calories (kcal), body fat (fraction 0–1).

### Output

$M$ (kcal/day), $q$ (confidence, 0–1).

### Core Equation

$$M = \hat{C}_b - \frac{\dot{w}_b \cdot \rho}{7}$$

- $\hat{C}_b$ = blended intake estimate
- $\dot{w}_b$ = blended weight slope (kg/week)
- $\rho$ = energy density of weight change (kcal/kg)

### Sub-models

**Intake smoothing** — gap-aware EWMA ($\alpha = 0.1$, ~7-day half-life):

$$S_1 = c_1, \quad \alpha_k = 1-(1-\alpha)^{\Delta_k}, \quad S_k = \alpha_k c_k + (1-\alpha_k) S_{k-1}$$

$\hat{C} = S_n$. Gap $\Delta_k = \max(1, t_k - t_{k-1})$ in days.

**Weight trend** — WLS regression over window $W_d = 28$ days:

$$\omega_i = 0.9^{d_i}, \quad \beta = \frac{\sum \omega_i(t_i-\bar{t})(w_i-\bar{w})}{\sum \omega_i(t_i-\bar{t})^2}$$

$$\dot{w} = \text{clamp}(7\beta,\ -1.0,\ +0.75) \quad \text{kg/week}$$

**Energy density** — Forbes partition model:

$$p = \frac{b \cdot w}{b \cdot w + 10.4}, \quad \rho = 9440p + 1816(1-p)$$

No body fat data → $\rho = 7350$ (population average at ~34% BF).

### Confidence & Blending

$$q_w = \min\!\left(1,\tfrac{n}{7}\right) \cdot \min\!\left(1,\tfrac{s}{W_d}\right), \quad q_c = \min\!\left(1,\tfrac{n_c}{14}\right) \cdot \min\!\left(1,\tfrac{s_c}{W_d}\right)$$

$$\hat{C}_b = \hat{C} \cdot q_c + F(1-q_c), \quad \dot{w}_b = \dot{w} \cdot q_w$$

Intake blends toward fallback $F$. Slope fades to 0 (assume stable weight).

### Fallback $F$

Computed internally, in order:

1. **Historical:** Re-run model at wider windows (180, 365, 730, 1825, 3650 days). Use first with ≥7 weight + ≥14 calorie days.
2. **Weight-anchored:** $F = 30w$ if any weight exists.
3. **Population:** $F = 2200$.

### Validity

Valid when weight ($n \geq 7$, $s \geq W_d/2$) **or** calories ($n_c \geq 14$, $s_c \geq W_d/2$).

---

## 2. Budget Model

**Goal:** Today's calorie target from maintenance estimate.

### Inputs

$M$, $q$ from §1. User adjustment $A$ (kcal/day). Week's logged intakes $I_w$ (day → kcal). First weekday $d_1$.

### Equations

$$B_0 = M + A$$
$$\text{credit} = B_0 \cdot |I_w| - \textstyle\sum I_w$$
$$\delta = \text{clamp}\!\left(\tfrac{\text{credit}}{d_{\text{left}}},\ -500,\ +500\right)$$
$$B = \text{clamp}(B_0 + \delta,\ 1000,\ 6000)$$

---

## 3. Flags

| Flag | Condition |
|------|-----------|
| valid | §1 validity check |
| slope clamped | $7\beta \notin [-1.0, +0.75]$ |
| $\rho$ estimated | no body fat data |
| $M$ suspect | $M < 1000$ |
| $B$ clamped | $B_0+\delta \notin [1000, 6000]$ |
| $\delta$ clamped | $|\text{credit}/d_{\text{left}}| > 500$ |

---

## Constants

| Symbol | Value | Meaning |
|--------|-------|---------|
| $\alpha$ | 0.1 | EWMA half-life ~7 days |
| $\lambda$ | 0.9 | WLS decay/day |
| $W_d$ | 28 | Primary window (days) |
| Slope bounds | −1.0 / +0.75 | kg/week |
| $\rho_0$ | 7350 | Default kcal/kg |
| Forbes $C$ | 10.4 | Partition constant (kg) |
| Fat / Lean | 9440 / 1816 | Tissue energy (kcal/kg) |
| Min $n$ / $n_c$ | 7 / 14 | Confidence density thresholds |
| $F_0$ | 2200 | Population baseline (kcal/day) |
| Weight mult | 30 | kcal/kg/day fallback |
| Stages | 180…3650 | Historical windows (days) |
| $\delta$ cap | ±500 | Credit spread (kcal/day) |
| $B$ bounds | 1000–6000 | Budget clamp (kcal/day) |
