local results = require "script.results"

local SETTING_NAME = "factory-inspector-enable-verification"
local CHECK_INTERVAL = 10800 -- 3 minutes in ticks
local DIVERGENCE_THRESHOLD_PCT = 0.20 -- 20%
local DIVERGENCE_THRESHOLD_ABS = 50
local MAX_DIVERGED_SHOWN = 10

local function isEnabled()
    return settings.global[SETTING_NAME].value
end

-- Collect cumulative production stats across all surfaces for a force.
-- Returns { items = { input_counts = {}, output_counts = {} }, fluids = { ... } }
local function collectStats(force)
    local stats = {
        items = { input_counts = {}, output_counts = {} },
        fluids = { input_counts = {}, output_counts = {} }
    }

    for _, surface in pairs(game.surfaces) do
        local item_stats = force.get_item_production_statistics(surface)
        for name, count in pairs(item_stats.input_counts) do
            stats.items.input_counts[name] = (stats.items.input_counts[name] or 0) + count
        end
        for name, count in pairs(item_stats.output_counts) do
            stats.items.output_counts[name] = (stats.items.output_counts[name] or 0) + count
        end

        local fluid_stats = force.get_fluid_production_statistics(surface)
        for name, count in pairs(fluid_stats.input_counts) do
            stats.fluids.input_counts[name] = (stats.fluids.input_counts[name] or 0) + count
        end
        for name, count in pairs(fluid_stats.output_counts) do
            stats.fluids.output_counts[name] = (stats.fluids.output_counts[name] or 0) + count
        end
    end

    return stats
end

-- Compute deltas between current stats and a snapshot, compare against mod's results,
-- and return a report table. Used by both background checks and on-demand reports.
local function computeReport(snapshot, force)
    local elapsed_ticks = game.tick - snapshot.tick
    local elapsed_seconds = elapsed_ticks / 60

    results.flushBuffers()

    -- Take current Factorio stats and compute deltas from snapshot
    local game_deltas = {}
    local cur = collectStats(force)

    for item, count in pairs(cur.items.input_counts) do
        local prev = snapshot.items.input_counts[item] or 0
        local delta = count - prev
        if delta > 0 then
            if not game_deltas[item] then game_deltas[item] = { produced = 0, consumed = 0 } end
            game_deltas[item].produced = delta
        end
    end
    for item, count in pairs(cur.items.output_counts) do
        local prev = snapshot.items.output_counts[item] or 0
        local delta = count - prev
        if delta > 0 then
            if not game_deltas[item] then game_deltas[item] = { produced = 0, consumed = 0 } end
            game_deltas[item].consumed = delta
        end
    end

    for item, count in pairs(cur.fluids.input_counts) do
        local prev = snapshot.fluids.input_counts[item] or 0
        local delta = count - prev
        if delta > 0 then
            if not game_deltas[item] then game_deltas[item] = { produced = 0, consumed = 0 } end
            game_deltas[item].produced = game_deltas[item].produced + delta
        end
    end
    for item, count in pairs(cur.fluids.output_counts) do
        local prev = snapshot.fluids.output_counts[item] or 0
        local delta = count - prev
        if delta > 0 then
            if not game_deltas[item] then game_deltas[item] = { produced = 0, consumed = 0 } end
            game_deltas[item].consumed = game_deltas[item].consumed + delta
        end
    end

    -- Compute mod deltas from storage.results
    local mod_deltas = {}
    local snapshot_tick = snapshot.tick

    for item, itemDB in pairs(storage.results) do
        local prod_total = 0
        local cons_total = 0

        if itemDB.produced then
            for recipe, recipeDB in pairs(itemDB.produced) do
                if recipe ~= "total" then
                    for _, record in ipairs(recipeDB) do
                        if record.tick >= snapshot_tick then
                            prod_total = prod_total + record.amount
                        end
                    end
                end
            end
        end

        if itemDB.consumed then
            for recipe, recipeDB in pairs(itemDB.consumed) do
                if recipe ~= "total" then
                    for _, record in ipairs(recipeDB) do
                        if record.tick >= snapshot_tick then
                            cons_total = cons_total + record.amount
                        end
                    end
                end
            end
        end

        if prod_total > 0 or cons_total > 0 then
            mod_deltas[item] = { produced = prod_total, consumed = cons_total }
        end
    end

    -- Classify items
    local matched = {}
    local diverged = {}
    local untracked = {}

    local all_items = {}
    for item, _ in pairs(game_deltas) do all_items[item] = true end
    for item, _ in pairs(mod_deltas) do all_items[item] = true end

    for item, _ in pairs(all_items) do
        local gd = game_deltas[item] or { produced = 0, consumed = 0 }
        local md = mod_deltas[item] or { produced = 0, consumed = 0 }

        local has_mod_data = md.produced > 0 or md.consumed > 0
        local has_game_data = gd.produced > 0 or gd.consumed > 0

        if not has_mod_data and has_game_data then
            table.insert(untracked, { item = item, game = gd, mod = md })
        elseif has_mod_data then
            local prod_ok = true
            local cons_ok = true

            if gd.produced > 0 then
                local diff = math.abs(gd.produced - md.produced)
                if diff / gd.produced > 0.05 then prod_ok = false end
            elseif md.produced > 0 then
                prod_ok = false
            end

            if gd.consumed > 0 then
                local diff = math.abs(gd.consumed - md.consumed)
                if diff / gd.consumed > 0.05 then cons_ok = false end
            elseif md.consumed > 0 then
                cons_ok = false
            end

            if prod_ok and cons_ok then
                table.insert(matched, item)
            else
                table.insert(diverged, { item = item, game = gd, mod = md })
            end
        end
    end

    -- Compute severity and sort
    for _, d in ipairs(diverged) do
        local prod_diff = math.abs(d.game.produced - d.mod.produced)
        local cons_diff = math.abs(d.game.consumed - d.mod.consumed)
        d.max_diff = math.max(prod_diff, cons_diff)
    end
    table.sort(diverged, function(a, b) return a.max_diff > b.max_diff end)

    return {
        elapsed_seconds = elapsed_seconds,
        tick = game.tick,
        matched = matched,
        diverged = diverged,
        untracked = untracked,
        current_stats = cur
    }
end

-- Count items with significant divergence (for background alerting)
local function countSignificantDivergences(report)
    local count = 0
    for _, d in ipairs(report.diverged) do
        local prod_diff = math.abs(d.game.produced - d.mod.produced)
        local cons_diff = math.abs(d.game.consumed - d.mod.consumed)
        local prod_pct = d.game.produced > 0 and (prod_diff / d.game.produced) or 0
        local cons_pct = d.game.consumed > 0 and (cons_diff / d.game.consumed) or 0

        if (prod_diff > DIVERGENCE_THRESHOLD_ABS and prod_pct > DIVERGENCE_THRESHOLD_PCT)
            or (cons_diff > DIVERGENCE_THRESHOLD_ABS and cons_pct > DIVERGENCE_THRESHOLD_PCT) then
            count = count + 1
        end
    end
    return count
end

-- Run one background verification cycle. Called from onGameTick every CHECK_INTERVAL ticks.
local function runBackgroundCheck()
    if not isEnabled() then return end

    -- Use the first player's force (typically "player" force in single-player)
    local force = game.forces["player"]
    if not force then return end

    local snapshot = storage.verification_snapshot

    if not snapshot then
        -- First cycle: just take the initial snapshot
        results.flushBuffers()
        local stats = collectStats(force)
        storage.verification_snapshot = {
            tick = game.tick,
            items = stats.items,
            fluids = stats.fluids
        }
        return
    end

    -- Subsequent cycles: compare and store report, then take new snapshot
    local report = computeReport(snapshot, force)

    storage.verification_last_report = {
        elapsed_seconds = report.elapsed_seconds,
        tick = report.tick,
        matched_count = #report.matched,
        diverged = report.diverged,
        untracked_count = #report.untracked
    }

    -- Alert if significant divergences found
    local significant = countSignificantDivergences(report)
    if significant > 0 then
        game.print(string.format("[FI Verify] Tracking drift detected: %d item(s) diverged >%d%%. Use /fi-verify-report for details.",
            significant, DIVERGENCE_THRESHOLD_PCT * 100))
    end

    -- Take new snapshot for next cycle
    storage.verification_snapshot = {
        tick = game.tick,
        items = report.current_stats.items,
        fluids = report.current_stats.fluids
    }
end

-- Print the stored report to a player. Called by /fi-verify-report.
local function formatReport(player)
    if not isEnabled() then
        player.print("[FI Verify] Verification is disabled. Enable it in mod settings.")
        return
    end

    local report = storage.verification_last_report
    if not report then
        player.print("[FI Verify] No report available yet. Background checks run every 3 minutes.")
        return
    end

    local total_active = report.matched_count + #report.diverged + report.untracked_count

    player.print(string.format("[FI Verify] Report from %.0f seconds ago (%.0f second window):",
        (game.tick - report.tick) / 60, report.elapsed_seconds))
    player.print(string.format("[FI Verify] %d items active, %d matched (<5%%), %d diverged, %d untracked",
        total_active, report.matched_count, #report.diverged, report.untracked_count))

    if #report.diverged > 0 then
        local showing = math.min(#report.diverged, MAX_DIVERGED_SHOWN)
        if showing < #report.diverged then
            player.print(string.format("[FI Verify] Top %d diverged (of %d):", showing, #report.diverged))
        else
            player.print("[FI Verify] Diverged (possible bugs):")
        end
        for i = 1, showing do
            local d = report.diverged[i]
            local parts = {}
            local prod_diff = math.abs(d.game.produced - d.mod.produced)
            local prod_pct = d.game.produced > 0 and string.format("%.0f%%", prod_diff / d.game.produced * 100) or "N/A"
            table.insert(parts, string.format("PROD game=%.0f mod=%.0f diff=%.0f (%s)", d.game.produced, d.mod.produced, prod_diff, prod_pct))

            local cons_diff = math.abs(d.game.consumed - d.mod.consumed)
            local cons_pct = d.game.consumed > 0 and string.format("%.0f%%", cons_diff / d.game.consumed * 100) or "N/A"
            table.insert(parts, string.format("CONS game=%.0f mod=%.0f diff=%.0f (%s)", d.game.consumed, d.mod.consumed, cons_diff, cons_pct))

            player.print("  " .. d.item .. ": " .. table.concat(parts, " | "))
        end
        if showing < #report.diverged then
            player.print(string.format("  ... and %d more minor divergences omitted", #report.diverged - showing))
        end
    end

    if report.untracked_count > 0 then
        player.print(string.format("[FI Verify] %d untracked items (not tracked by mod, expected for hand-crafting, logistics, etc.)", report.untracked_count))
    end
end

-- Handle the mod setting being toggled. When enabled, take an initial snapshot immediately.
local function onSettingChanged(event)
    if event.setting ~= SETTING_NAME then return end

    if isEnabled() then
        local force = game.forces["player"]
        if not force then return end

        results.flushBuffers()
        local stats = collectStats(force)
        storage.verification_snapshot = {
            tick = game.tick,
            items = stats.items,
            fluids = stats.fluids
        }
        storage.verification_last_report = nil
        game.print("[FI Verify] Verification enabled. First report will be available in 3 minutes.")
    else
        storage.verification_snapshot = nil
        storage.verification_last_report = nil
        game.print("[FI Verify] Verification disabled.")
    end
end

return {
    CHECK_INTERVAL = CHECK_INTERVAL,
    runBackgroundCheck = runBackgroundCheck,
    formatReport = formatReport,
    onSettingChanged = onSettingChanged
}
