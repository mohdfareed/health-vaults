# HealthVaults Project Review

## Current State (Jan 11, 2026)

### Architecture Overview

**Data Flow:**
- **HealthKit** → Source of truth for health metrics
- **SwiftData** → Local store for app-created entries, synced to HealthKit
- **AppStorage** → User preferences (units, theme, goals)
- **DataQuery** → Property wrapper for paginated HealthKit queries
- **HealthDataNotifications** → Observable service for data change events

### Key Components

| Component | Purpose |
|-----------|---------|
| `DataQuery` | Paginated HealthKit query with `reload()`, `loadNextPage()`, `removeItem()` |
| `HealthDataNotifications` | Notifies views when HealthKit data changes |
| `.refreshOnHealthDataChange` | View modifier that triggers action on data change |
| `RecordList` | Uses `DataQuery` + `refreshOnHealthDataChange` for reactive updates |
| `BudgetDataService` | Calculates daily budget from maintenance + goal + credit |

### Budget System

**Core Formula:**
```
Today's Budget = Maintenance + Goal + Credit Adjustment
```

**Key Concepts:**
- **Maintenance**: Calories you burn per day (learned from weight trends)
- **Credit**: Over/under from past 7 days, spread to next week reset
- **Credit Adjustment**: `credit / daysLeft`, capped at ±500 kcal/day

### Widget Updates
- `AppHealthKitObserver` - listens to HealthKit changes, reloads widgets
- `AppLocale` bindings - reload on unit/firstDayOfWeek change
- `GoalsView` - reload on goals save

---

## Bug Fixes Summary (Jan 11, 2026)

Most bugs resolved. Remaining:
- **Widget reset**: Monitoring - added fallback logic in `WidgetsSettings.getGoals()`
- **Keyboard toolbar**: Known SwiftUI limitation with multiple competing toolbars

Key pattern changes:
- Use `.task` with `hasLoaded` guard for one-time loads
- Use `.refreshOnHealthDataChange` for reactive data updates
- Use `DataQuery.removeItem()` for optimistic deletes
- Use `hasAppeared` state to control animations on initial load

---

## Version
- App version: 1.2.1 (in progress)

**🔴 CRITICAL BUG: `@AppStorage` in struct is not reactive**

The `BudgetTimelineProvider` and `MacrosTimelineProvider` use:
```swift
@AppStorage(.userGoals, store: SharedDefaults) private var goalsID: UUID
```

**Problem**: `@AppStorage` in a non-View struct doesn't provide property observation. Each time WidgetKit requests a timeline, a new provider instance is created. The `goalsID` will be read fresh, but if the default UUID value doesn't match an existing `UserGoals` record, `WidgetsSettings.getGoals()` returns `nil`.

**When this happens**:
1. Widget timeline expires (after 1 hour)
2. WidgetKit creates new `BudgetTimelineProvider` instance
3. `@AppStorage` initializes with default UUID value
4. `WidgetsSettings.getGoals(for: goalsID)` returns `nil`
5. `BudgetDataService` created with `adjustment: nil`
6. If HealthKit query fails or returns empty → `budgetService` is `nil`
7. Widget shows "Loading..." fallback

**🔴 SECONDARY: No fallback when HealthKit returns empty data**

Even with correct `goalsID`, `BudgetDataService.refresh()` can result in `budgetService` being populated with zero/empty data if:
- HealthKit authorization expires or is limited
- No calorie/weight data exists for the date range
- HealthKit queries fail silently (return `[:]`)

**When `budgetService` is created with empty data**:
- `isValid` may return false
- UI shows computed values based on empty inputs (zeros)

### Affected Code Locations

1. [BudgetWidget.swift#L59](Widgets/BudgetWidget.swift#L59) - `@AppStorage` declaration
2. [MacrosWidget.swift#L62](Widgets/MacrosWidget.swift#L62) - Same issue
3. [WidgetsBundle.swift#L13](Widgets/WidgetsBundle.swift#L13) - `WidgetsSettings.getGoals()` returns `nil` on ID mismatch
4. [BudgetWidget.swift#L41-L50](Widgets/BudgetWidget.swift#L41-L50) - Fallback "Loading..." UI

### Recommended Fixes

1. **Remove `@AppStorage` from timeline providers** - Read directly from SharedDefaults in `generateEntry()`
2. **Add error handling for nil goals** - Use sensible defaults instead of propagating nil
3. **Cache last successful widget data** - Store in SharedDefaults, use as fallback
4. **Add logging to diagnose** - Track when goalsID mismatch or HealthKit fails
