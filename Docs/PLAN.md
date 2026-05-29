# Model Development Plan

Python workbench for investigating and tuning the maintenance/budget model.

---

## Workbench

**Status:** Ready

- `ModelLab/model.py` — Python re-implementation of the analytics math
- `ModelLab/constants.py` — mirrors `Shared/Config.swift`
- `ModelLab/lab.ipynb` — scratchpad notebook (add cells as needed)
- `Scripts/lab.sh` — launches Jupyter (`venv` + `pip`)

---

## Open Questions

Investigate as needed — not pre-built phases.

1. **Weight-anchored fallback gap.** MATH.md specifies F = 30w as a fallback, but `BudgetDataService.computeHistoricalMaintenance()` skips it. Reconcile.
2. **Cascade → blend.** First sufficient historical stage wins. Blending by confidence would be smoother.
3. **Confidence ramp.** Density×span jumps from 0. Consider easing so first few data points don't swing the estimate.
4. **Demographic estimates.** biologicalSex/dateOfBirth/height could enable Mifflin-St Jeor as a better fallback. Deferred.
5. **Constants organization.** Split Config.swift into Literature vs Tunable sections (constants.py already does this).
