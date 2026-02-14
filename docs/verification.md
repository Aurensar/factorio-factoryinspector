# Verification System

## Purpose

The verification system compares Factory Inspector's own per-recipe tracking against Factorio's built-in cumulative production statistics. This detects tracking bugs — items being missed, double-counted, or misattributed. It's a developer/debug tool, not user-facing by default.

## How It Works

### Background Cycle

When enabled via the mod setting **"Enable verification checks"** (`factory-inspector-enable-verification`), the system runs a comparison cycle every **3 minutes (10,800 ticks)**:

1. **First cycle after enabling**: Takes a snapshot of Factorio's cumulative production stats (via `force.get_item_production_statistics(surface)` and `force.get_fluid_production_statistics(surface)` across all surfaces) and stores it in `storage.verification_snapshot`. No comparison is possible yet.

2. **Subsequent cycles**: Collects current Factorio stats, computes deltas from the stored snapshot, then compares those deltas against the mod's own `storage.results` records accumulated since the snapshot tick. Prints the full report to the console via `game.print()` and replaces the snapshot with current stats for the next cycle.

### What Gets Compared

- **Game deltas**: `current_factorio_stats - snapshot_factorio_stats` for each item/fluid, split into produced (input_counts) and consumed (output_counts).
- **Mod deltas**: Sum of all `storage.results[item][produced|consumed][recipe]` records with `tick >= snapshot_tick`.
- Items and fluids are merged into a single namespace for comparison.

### Classification

Each item is classified into one of three categories:

| Category | Criteria |
|---|---|
| **Matched** | Mod tracks the item and values are within 5% of game stats |
| **Diverged** | Mod tracks the item but values differ by >5% |
| **Untracked** | Game shows activity but mod has no data (expected for hand-crafting, logistics, inserter movements, etc.) |

### Report Output

Every cycle, the full report is printed automatically to the console via `game.print()`:
- Summary line: total active items, matched count, diverged count, untracked count
- Top 10 diverged items sorted by severity (largest absolute difference first), showing per-item PROD and CONS breakdowns with game vs mod values and percentage differences
- Remaining diverged items collapsed into "... and N more"
- Untracked items shown as a count only

## Console Commands

| Command | Description |
|---|---|
| `/fi-verify-now` | Force an immediate verification cycle and print results |

## Mod Setting

- **Name**: `factory-inspector-enable-verification`
- **Type**: `runtime-global` bool
- **Default**: `false`
- When toggled **on**: Takes an initial snapshot immediately, first report prints after 3 minutes
- When toggled **off**: Clears snapshot

## Data Stored in `storage`

| Key | Contents |
|---|---|
| `storage.verification_snapshot` | `{ tick, items = { input_counts, output_counts }, fluids = { input_counts, output_counts } }` |

Reset on `on_init` and `on_configuration_changed`.

## Key Files

| File | Role |
|---|---|
| `script/verification.lua` | All verification logic: `collectStats()`, `computeReport()`, `printReport()`, `runBackgroundCheck()`, `onSettingChanged()` |
| `script/event-handlers.lua` | Calls `runBackgroundCheck()` every 10,800 ticks; delegates `on_runtime_mod_setting_changed` |
| `control.lua` | Registers `/fi-verify-now` command |
| `settings.lua` | Defines the `factory-inspector-enable-verification` setting |

## Known Limitations

- Only checks the `"player"` force — won't work correctly in PvP scenarios with multiple forces
- The 3-minute window means very short-lived production spikes might be missed or split across cycles
- Untracked items (hand-crafting, inserter movements, rocket launches, etc.) will always appear — this is expected, not a bug
- If the snapshot is older than 5 minutes (e.g., game was paused), mod results may have been cleaned up, causing false divergences

## Threshold Constants (in `verification.lua`)

```lua
CHECK_INTERVAL = 10800      -- 3 minutes in ticks
MAX_DIVERGED_SHOWN = 10     -- cap on detailed report output
```
