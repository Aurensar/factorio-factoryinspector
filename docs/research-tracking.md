# Research Tracking — Design Notes

Added in **2.2.0**. Explains how Factory Inspector tracks science pack consumption from research laboratories.

---

## The Core Problem

Assembling machines and furnaces expose `products_finished` — a running counter that increments each time a craft completes. This makes per-entity tracking straightforward: read the counter each tick, diff against the previous value, multiply by the recipe's ingredient amounts.

Labs have no equivalent. `products_finished` is absent. The Factorio 2.0 Lua API exposes no per-lab research progress counter at all. The only signal available is `force.research_progress` — a 0–1 float representing progress through the current technology, shared across the entire force.

This means lab tracking is fundamentally **force-level**, not entity-level.

---

## Approach: Force-Level Progress Delta

Every tick, `updateResearchConsumption()` (in `production-tracker.lua`) does the following for each force that has active research:

```
delta = force.research_progress - state.previous_progress
```

If `delta > 0`, science packs were consumed. The total packs consumed across all labs is:

```
packs_consumed = delta * tech.research_unit_count * ingredient.amount
```

`research_unit_count` is the total number of "research units" (pack sets) required to complete the technology. A delta of 1.0 (full completion) would consume exactly `research_unit_count * ingredient.amount` packs.

To account for productivity modules, this raw amount is divided by `(1 + productivity_bonus)`, which is computed per-lab and applied when distributing (see below).

---

## Per-Lab Attribution via the Speed Cache

The force-level delta tells us *how much* was consumed in total, but not *which lab consumed what* or *on which surface*. To distribute correctly — especially for multi-surface Space Age play — the mod maintains a per-force lab cache.

### `storage.force_lab_cache[force_index]`

```lua
{
    total_speed = <sum of effective speeds>,
    labs = {
        { unit_number, surface_index, speed, speed_fraction, productivity_bonus },
        ...
    }
}
```

**Effective speed** for a lab is `1 + entity.speed_bonus`. This captures speed modules and beacons. Note: `LuaEntityPrototype` does not expose `researching_speed` in Factorio 2.0, so the base prototype speed is not directly accessible. For vanilla Factorio (all labs are the same type with the same base speed), the base speed cancels out in the ratio and this is exact. For mods with multiple lab types of different base speeds, the distribution is approximate but directionally correct.

**`speed_fraction`** = `lab.speed / total_speed` — the fraction of all research work this lab contributes.

### Distribution formula (per lab, per ingredient)

```lua
fractional_units = delta * unit_count * lab_info.speed_fraction
amount = fractional_units * ingredient.amount / (1 + lab_info.productivity_bonus)
```

`fractional_units` is passed as the `times` argument to `addConsumptionData`. `amount` is the actual item quantity consumed by that lab. Dividing by `(1 + productivity_bonus)` correctly accounts for productivity modules: a lab with +40% productivity consumes 28.6% fewer packs to produce the same research output.

---

## Cache Lifecycle

The lab cache must be kept in sync with the actual set of labs and their module configurations.

| Trigger | Action |
|---|---|
| `on_research_started` | Rebuild cache for the research force |
| Lab placed (`on_built_entity` etc.) | Rebuild cache for the lab's force |
| Lab removed (`on_player_mined_entity` etc.) | Capture force reference *before* removal, rebuild after |
| `checkMissingEntities` (every 3600 ticks) | Rebuild cache if a lab was missing from tracking |

The cache is **not** rebuilt per-tick. Rebuilding on placement/removal events and on research transitions covers all meaningful state changes without per-tick cost.

**Important**: In `onRemovedEntity`, the force reference must be captured from the entity *before* calling `removeEntityByNumber`, because the entity object may become invalid after removal.

---

## Tech Change Detection

When research transitions to a new technology:

1. `on_research_started` fires with `event.research` = the new `LuaTechnology`.
2. `onResearchStarted` calls `addResearchFakeRecipeLookup(tech)` to register the fake recipe and initialise results storage for each ingredient.
3. `storage.force_research_state[force.index]` is reset: `{ tech_name = tech.name, previous_progress = 0 }`.
4. The lab cache is rebuilt for the force.

In `updateResearchConsumption`, the guard `state.tech_name == tech.name` ensures that stale state from a previous technology is never applied to the current one. If the names don't match (e.g., in the brief window between a tech completing and `on_research_started` firing for the next), the tick is skipped silently.

---

## Fake Recipe System

Labs have no Factorio recipe. The mod uses the same fake recipe mechanism used for mining. Each technology gets a key:

```
"research-{tech.name}"
```

Registered in `storage.fakeRecipeLookup` with:

| Field | Value |
|---|---|
| `prototype` | `tech.name` (e.g. `"automation"`) |
| `prototypeType` | `"technology"` |
| `formatString` | `"recipe-display.research"` |

In `getDisplayNameAndSpriteForDynamicRecipe` (UI), the `"technology"` case looks up `prototypes.technology[lookup.prototype]` for the localised name and uses `"technology/{name}"` as the sprite path. This renders the technology icon alongside the localised tech name in the consumption table.

`addFakeRecipeLookup` is idempotent (guarded by `if storage.fakeRecipeLookup[fakeRecipe] then return end`), so re-registering on repeated research starts is safe.

`initResults` is also idempotent, so calling `addResearchFakeRecipeLookup` on every `on_research_started` for the same tech (e.g., if research is cancelled and restarted) does not corrupt results storage.

---

## Entity Tracking

Labs are registered in a dedicated partition table (`storage.entities_lab`) separate from assembling machines, furnaces, and mining drills. This follows the same pattern as those entity types.

```lua
storage.entities_lab[partition][unit_number] = { entity = entity }
storage.entities_lab_partition_lookup[unit_number] = partition
```

Labs are included in:
- The global entity batch (`storage.entities`) for validity/recipe-name-change checks
- `find_entities_filtered` calls in `checkEntityBatchForRecipeChanges` (full re-scan) and `checkMissingEntities`
- All six built/removed event filter lists in `control.lua`

`getRecipe()` and `getRecipeName()` handle `entity.type == "lab"` explicitly before reaching `entity.get_recipe()`, which would error or return irrelevant data for labs.

`updateConsumersAndProducers()` is called for labs like any other entity, but since `getRecipe()` returns `nil` for labs, no consumer/producer records are created. The empty `storage.consumers[unit_number]` and `storage.producers[unit_number]` tables are harmless.

---

## Known Limitations

- **`LuaEntityPrototype.researching_speed` unavailable**: In Factorio 2.0, this property is not accessible via `entity.prototype`. The effective speed falls back to `1 + entity.speed_bonus`. Correct for vanilla; approximate for multi-type lab mods.
- **No per-lab mid-tick precision**: `force.research_progress` is read once per tick. Very fast labs completing multiple cycles per tick (unlikely in practice) would still be captured correctly since the delta accumulates.
- **Productivity module changes between ticks**: If a player adds/removes modules from a lab mid-research, the cache reflects the old state until a lab built/removed event or the next `checkMissingEntities`. The practical impact is negligible (one cache update cycle = one minute worst case).
- **Research pause/cancel**: If research is paused (no `on_research_started` fires), `force.current_research` returns nil and `updateResearchConsumption` skips cleanly.

---

## Files Involved

| File | Role |
|---|---|
| `script/init.lua` | Initialises `entities_lab`, `lab_partition_data`, `force_research_state`, `force_lab_cache` |
| `script/recipe.lua` | `getRecipe`/`getRecipeName` lab short-circuits |
| `script/input-output-calculator.lua` | `buildForceLabCache`, `addResearchFakeRecipeLookup` |
| `script/entity-tracker.lua` | Lab partition enrol/remove, type filters |
| `script/production-tracker.lua` | `updateResearchConsumption` — the per-tick delta loop |
| `script/event-handlers.lua` | `onResearchStarted`, lab cache rebuild in built/removed handlers |
| `control.lua` | Event registrations including `on_research_started` |
| `ui/production-tables.lua` | `"technology"` case in `getDisplayNameAndSpriteForDynamicRecipe` |
| `locale/en/config.cfg` | `recipe-display.research` localisation string |
