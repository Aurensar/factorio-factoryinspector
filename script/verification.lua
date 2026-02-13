local results = require "script.results"

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

local function takeSnapshot(player)
    results.flushBuffers()

    local stats = collectStats(player.force)
    local snapshot = {
        tick = game.tick,
        items = stats.items,
        fluids = stats.fluids
    }

    storage.verification_snapshot = snapshot
    player.print("[FI Verify] Snapshot taken at tick " .. game.tick)
end

local function compareAndReport(player)
    local snapshot = storage.verification_snapshot
    if not snapshot then
        player.print("[FI Verify] No snapshot exists. Run /fi-verify-start first.")
        return
    end

    local elapsed_ticks = game.tick - snapshot.tick
    local elapsed_seconds = elapsed_ticks / 60

    if elapsed_seconds > 300 then
        player.print("[FI Verify] Warning: snapshot is " .. string.format("%.0f", elapsed_seconds) .. " seconds old. Results older than 5 minutes are cleaned up and may be missing.")
    end

    results.flushBuffers()

    -- Take current Factorio stats and compute deltas from snapshot
    local game_deltas = {} -- game_deltas[item] = { produced = N, consumed = N }
    local cur = collectStats(player.force)

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
    local mod_deltas = {} -- mod_deltas[item] = { produced = N, consumed = N }
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

    -- Collect all items that have any activity
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
            -- Check if within 5% tolerance
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

    -- Compute severity score for diverged items (max absolute difference)
    for _, d in ipairs(diverged) do
        local prod_diff = math.abs(d.game.produced - d.mod.produced)
        local cons_diff = math.abs(d.game.consumed - d.mod.consumed)
        d.max_diff = math.max(prod_diff, cons_diff)
    end

    -- Sort diverged by severity (largest difference first)
    table.sort(diverged, function(a, b) return a.max_diff > b.max_diff end)

    local total_active = #matched + #diverged + #untracked
    local max_diverged_shown = 10

    -- Print report
    player.print(string.format("[FI Verify] Report after %.0f seconds:", elapsed_seconds))
    player.print(string.format("[FI Verify] %d items active, %d matched (<5%%), %d diverged, %d untracked",
        total_active, #matched, #diverged, #untracked))

    if #diverged > 0 then
        local showing = math.min(#diverged, max_diverged_shown)
        if showing < #diverged then
            player.print(string.format("[FI Verify] Top %d diverged (of %d):", showing, #diverged))
        else
            player.print("[FI Verify] Diverged (possible bugs):")
        end
        for i = 1, showing do
            local d = diverged[i]
            local parts = {}
            local prod_diff = math.abs(d.game.produced - d.mod.produced)
            local prod_pct = d.game.produced > 0 and string.format("%.0f%%", prod_diff / d.game.produced * 100) or "N/A"
            table.insert(parts, string.format("PROD game=%.0f mod=%.0f diff=%.0f (%s)", d.game.produced, d.mod.produced, prod_diff, prod_pct))

            local cons_diff = math.abs(d.game.consumed - d.mod.consumed)
            local cons_pct = d.game.consumed > 0 and string.format("%.0f%%", cons_diff / d.game.consumed * 100) or "N/A"
            table.insert(parts, string.format("CONS game=%.0f mod=%.0f diff=%.0f (%s)", d.game.consumed, d.mod.consumed, cons_diff, cons_pct))

            player.print("  " .. d.item .. ": " .. table.concat(parts, " | "))
        end
        if showing < #diverged then
            player.print(string.format("  ... and %d more minor divergences omitted", #diverged - showing))
        end
    end

    if #untracked > 0 then
        player.print(string.format("[FI Verify] %d untracked items (not tracked by mod, expected for hand-crafting, logistics, etc.)", #untracked))
    end

    storage.verification_snapshot = nil
end

local function reportStatus(player)
    local snapshot = storage.verification_snapshot
    if not snapshot then
        player.print("[FI Verify] No active snapshot.")
        return
    end

    local elapsed_ticks = game.tick - snapshot.tick
    local elapsed_seconds = elapsed_ticks / 60
    player.print(string.format("[FI Verify] Active snapshot from tick %d (%.0f seconds ago).", snapshot.tick, elapsed_seconds))
end

return {
    takeSnapshot = takeSnapshot,
    compareAndReport = compareAndReport,
    reportStatus = reportStatus
}
