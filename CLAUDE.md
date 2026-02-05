# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Factory Inspector is a Factorio mod (Lua) that measures per-recipe consumption and production for all items. It tracks assembling machines, furnaces, and mining drills, aggregating statistics over rolling time windows. Targets complex modded games where items have many producers/consumers.

**Factorio version**: 2.0+ | **Dependencies**: base >= 2.0.0, flib >= 0.15.0

## Development Setup

- Open in VSCode with the Factorio mod debugger extension
- Three launch configurations in `.vscode/launch.json`: basic debug, settings/data phase debug, and profiling
- No build system — the mod directory structure is deployed as-is into Factorio's mod folder
- Version is tracked in `info.json` and `changelog.txt` (keep both in sync)
- **Every change** must have a corresponding line added to `changelog.txt`
- **Every commit** must bump the patch version (e.g. 2.0.1 → 2.0.2) in both `info.json` and `changelog.txt`

## Architecture

### Entry Points (Factorio mod lifecycle)

- **`data.lua`** — Prototype phase: loads `prototypes/` (hotkeys, shortcuts, GUI styles)
- **`control.lua`** — Runtime phase: registers all event handlers, requires `script/` and `ui/` modules
- **`settings.lua`** — Not present; no mod settings currently

### Core Modules (`script/`)

| Module | Role |
|---|---|
| `init.lua` | `on_init`/`on_configuration_changed` — sets up all `storage` tables |
| `event-handlers.lua` | All event callbacks; orchestrates tick-based processing |
| `entity-tracker.lua` | Manages entity collections with partition-based batching |
| `production-tracker.lua` | Per-tick stat collection (products_finished, mining_progress) |
| `input-output-calculator.lua` | Enrolls consumer/producer records when entities are added/changed |
| `results.lua` | Stores and aggregates time-windowed production/consumption data |
| `recipe.lua` | Recipe resolution helpers |
| `ui.lua` | Per-player UI state management |
| `logger.lua` | Debug logging (log/log2/error) |

### UI Modules (`ui/`)

| Module | Role |
|---|---|
| `main.lua` | Main window frame, two-column layout |
| `item-list.lua` | Searchable item/fluid selection sidebar |
| `production-tables.lua` | Production and consumption stats tables |
| `production-diagnostics.lua` | Debug: type a unit number in search to dump entity info |

### Key Data Flow

1. **Entity registration**: Entity built → `onBuiltEntity()` → `entity-tracker.enrolNewEntity()` → `input-output-calculator` creates consumer/producer records
2. **Stat collection**: Every tick (partitioned) → `production-tracker` reads entity counters → writes to buffer
3. **Buffer flush**: Every 300 ticks → `results.flushBuffers()` consolidates buffer into persistent `storage.results`
4. **Cleanup**: Every 3600 ticks → removes results older than 5 minutes
5. **UI display**: Every 60 ticks → `results.getAggregateProduction/Consumption()` over 120-second window → render tables

### Partitioning System

Entities are distributed across partitions to spread processing load. Each tick processes one partition batch:
- Global entity checks: batch 5
- Assembling machines: batch 10
- Mining drills: batch 20
- Furnaces: batch 10

Separate collections exist per entity type (`storage.entities`, `storage.entities_am`, `storage.entities_md`, `storage.entities_furnace`) with corresponding partition lookup tables.

### Persistent State (`storage` table)

All persistent state lives in Factorio's `storage` table (survives save/load):
- `storage.players[playerIndex].ui` — per-player UI state
- `storage.entities[partition]` / `storage.entities_am[partition]` / etc. — partitioned entity lists
- `storage.consumers[unitNumber]` / `storage.producers[unitNumber]` — per-entity tracking records
- `storage.results[item].produced[recipe]` / `.consumed[recipe]` — timestamped stat records
- `storage.fakeRecipeLookup[recipe]` — display metadata for synthetic recipes (mining, fuel consumption)

### Fake Recipes

Mining outputs and fuel consumption don't have real Factorio recipes. The mod creates synthetic recipe names (e.g., "Mine iron-ore") with display info stored in `storage.fakeRecipeLookup` so the UI can show them uniformly alongside real recipes.

## Coding Conventions

- Modules use `require` with dot-separated paths (e.g., `require "script.logger"`) and return a table of public functions
- Always check `entity.valid` before using cached entity references
- Entity types tracked: `mining-drill`, `assembling-machine`, `furnace`
- Localized strings are in `locale/en/config.cfg`
- GUI styles reference `flib` styles defined in `prototypes/styles.lua`
