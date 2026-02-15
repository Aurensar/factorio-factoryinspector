local results = require "script.results"
local logger = require "script.logger"

productionTables = {}

local function addPercentBar(parent, fraction)
    local pct_flow = parent.add { type = "flow", direction = "horizontal", style = "fi_table_percent_flow" }
    pct_flow.add { type = "progressbar", value = fraction, style = "fi_table_percent_bar" }
    pct_flow.add { type = "label", caption = string.format("%d%%", fraction * 100), style = "fi_table_percent_label" }
end

function productionTables.create(player)
    local ui_state = ui.ui_state(player)

    ui_state.prod_label = ui_state.right_column.add{type="label", caption={"ui.production-stats", "120"}, style="caption_label", ignored_by_interaction=true}

    local prod_table_frame = ui_state.right_column.add{type="frame", direction="vertical", style="inside_deep_frame"}
    prod_table_frame.style.vertically_stretchable = true

    ui_state.prod_table_holder = prod_table_frame.add{type="scroll-pane", direction="vertical"}
    ui_state.prod_table_holder.style.horizontally_stretchable = true
    ui_state.prod_table_holder.style.vertically_stretchable = true
    ui_state.prod_table_holder.style.padding = { 10,10 }

    ui_state.prod_table = ui_state.prod_table_holder.add { type = "table", column_count = 9, vertical_centering=false, style="fi_table_production", draw_vertical_lines=true, draw_horizontal_lines=true }
    ui_state.prod_table.style.horizontal_spacing = 16

    ui_state.cons_label = ui_state.right_column.add{type="label", caption={"ui.consumption-stats", "120"}, style="caption_label", ignored_by_interaction=true}

    local cons_table_frame = ui_state.right_column.add{type="frame", direction="vertical", style="inside_deep_frame"}
    cons_table_frame.style.vertically_stretchable = true

    ui_state.cons_table_holder = cons_table_frame.add{type="scroll-pane", direction="vertical"}
    ui_state.cons_table_holder.style.horizontally_stretchable = true
    ui_state.cons_table_holder.style.vertically_stretchable = true
    ui_state.cons_table_holder.style.padding = { 10,10 }

    ui_state.cons_table = ui_state.cons_table_holder.add { type = "table", column_count = 9, vertical_centering=false, style="fi_table_production", draw_vertical_lines=true, draw_horizontal_lines=true }
    ui_state.cons_table.style.horizontal_spacing = 16

    productionTables.refreshConsumption(player)
    productionTables.refreshProduction(player)
end

function productionTables.refresh(player)
    local ui_state = ui.ui_state(player)
    local windowSeconds = settings.global["factory-inspector-display-window-seconds"].value
    if ui_state.prod_label and ui_state.prod_label.valid then
        ui_state.prod_label.caption = {"ui.production-stats", tostring(windowSeconds)}
    end
    if ui_state.cons_label and ui_state.cons_label.valid then
        ui_state.cons_label.caption = {"ui.consumption-stats", tostring(windowSeconds)}
    end
    productionTables.refreshConsumption(player)
    productionTables.refreshProduction(player)
end

local function getSurfaceDisplayName(surface_index)
    local surface = game.surfaces[surface_index]
    if not surface then return "Unknown" end
    if surface.platform then return surface.platform.name end
    if surface.planet then return surface.planet.prototype.localised_name end
    return surface.name
end

local function getQualityDisplayName(quality_name)
    local quality_proto = prototypes.quality[quality_name]
    if quality_proto then return quality_proto.localised_name end
    return quality_name
end

local function addSpriteWithQuality(table, sprite, quality)
    if quality and quality ~= "normal" then
        local icon_flow = table.add { type = "flow", direction = "horizontal" }
        icon_flow.style.width = 30
        icon_flow.style.height = 30
        local rs = icon_flow.add { type = "sprite", sprite = sprite }
        rs.style.size = {28, 28}
        local qs = icon_flow.add { type = "sprite", sprite = "quality/" .. quality }
        qs.style.size = {14, 14}
        qs.style.margin = {14, 0, 0, -14}
    else
        table.add { type = "sprite", sprite = sprite }
    end
end

local function getDisplayNameAndSpriteForDynamicRecipe(dynamicRecipe)
    if not storage.fakeRecipeLookup[dynamicRecipe] then
        logger.error("Lookup system can't find a match for dynamic recipe "..dynamicRecipe..", please report a bug")
        return "Unknown", "item/iron-plate"
    end

    local lookup = storage.fakeRecipeLookup[dynamicRecipe]
    local prototypeName
    local sprite = "item/iron-plate"
    if lookup.prototypeType == "recipe" then
        prototypeName = prototypes.recipe[lookup.prototype].localised_name
        sprite = "recipe/"..lookup.prototype
    end
    if lookup.prototypeType == "resource" then
        prototypeName = prototypes.entity[lookup.prototype].localised_name
        sprite = "entity/"..lookup.prototype
    end
    return {lookup.formatString, prototypeName}, sprite
end

local function showEmptyLabel(ui_state, key, holder, caption)
    if ui_state[key] and ui_state[key].valid then
        ui_state[key].destroy()
    end
    local label = holder.add { type = "label", caption = caption }
    label.style.font = "default-large-semibold"
    label.style.font_color = {0.5, 0.5, 0.5}
    label.style.horizontally_stretchable = true
    label.style.vertically_stretchable = true
    label.style.horizontal_align = "center"
    label.style.vertical_align = "center"
    ui_state[key] = label
end

local function clearEmptyLabel(ui_state, key)
    if ui_state[key] and ui_state[key].valid then
        ui_state[key].destroy()
    end
    ui_state[key] = nil
end

local function hasRows(agg)
    if not agg then return false end
    for _, entry in ipairs(agg.entries) do
        if entry.times > 0 then return true end
    end
    return false
end

function productionTables.refreshConsumption(player)
    local ui_state = ui.ui_state(player)
    local table = ui_state.cons_table
    local selected_item = ui_state.selected_item
    table.clear()
    clearEmptyLabel(ui_state, "cons_empty_label")

    if not selected_item then
        return
    end

    local windowSeconds = settings.global["factory-inspector-display-window-seconds"].value
    local agg = results.getAggregateConsumption(selected_item, windowSeconds)

    if not hasRows(agg) then
        table.visible = false
        showEmptyLabel(ui_state, "cons_empty_label", ui_state.cons_table_holder, {"ui.no-consumption", tostring(windowSeconds)})
        return
    end

    table.visible = true
    table.add { type = "label", caption = "", style="fi_table_sprite_heading" } -- for the sprite
    table.add { type = "label", caption = {"ui.recipe-name"}, style="fi_table_text_heading" }
    table.add { type = "label", caption = {"ui.surface"}, style="fi_table_surface_heading" }
    table.add { type = "label", caption = {"ui.quality"}, style="fi_table_quality_heading" }
    table.add { type = "label", caption = {"ui.times-consumed"}, style="fi_table_number_heading" }
    table.add { type = "label", caption = {"ui.amount-consumed"}, style="fi_table_number_heading" }
    table.add { type = "label", caption = {"ui.per-sec"}, style="fi_table_number_heading" }
    table.add { type = "label", caption = {"ui.per-min"}, style="fi_table_number_heading" }
    table.add { type = "label", caption = {"ui.percent"}, style="fi_table_number_heading" }

    for _, entry in ipairs(agg.entries) do
        if entry.times > 0 then
            local name, sprite = getDisplayNameAndSpriteForDynamicRecipe(entry.recipe)
            local combined_name = {"", name, " (", entry.recipe, ")"}
            local surface_name = getSurfaceDisplayName(entry.surface_index)
            local quality_name = getQualityDisplayName(entry.quality or "normal")
            addSpriteWithQuality(table, sprite, entry.quality)
            table.add { type = "label", caption = combined_name, style="fi_table_text" }
            table.add { type = "label", caption = surface_name, style="fi_table_surface" }
            table.add { type = "label", caption = quality_name, style="fi_table_quality" }
            table.add { type = "label", caption = string.format("%d", entry.times), style="fi_table_number" }
            table.add { type = "label", caption = string.format("%d", entry.amount), style="fi_table_number" }
            table.add { type = "label", caption = string.format("%.1f", entry.per_sec), style="fi_table_number" }
            table.add { type = "label", caption = string.format("%d", entry.per_min), style="fi_table_number" }
            addPercentBar(table, entry.amount / agg.total.amount)
        end
    end

    table.add { type = "sprite", sprite = ""}
    table.add { type = "label", caption = {"ui.total"}, style="fi_table_text_heading" }
    table.add { type = "label", caption = "", style="fi_table_surface_heading" }
    table.add { type = "label", caption = "", style="fi_table_quality_heading" }
    table.add { type = "label", caption = string.format("%d", agg.total.times), style="fi_table_number_heading" }
    table.add { type = "label", caption = string.format("%d", agg.total.amount), style="fi_table_number_heading"}
    table.add { type = "label", caption = string.format("%.1f", agg.total.per_sec), style="fi_table_number_heading" }
    table.add { type = "label", caption = string.format("%d", agg.total.per_min), style="fi_table_number_heading" }
    addPercentBar(table, 1.0)
end

function productionTables.refreshProduction(player)
    local ui_state = ui.ui_state(player)
    local table = ui_state.prod_table
    local selected_item = ui_state.selected_item
    table.clear()
    clearEmptyLabel(ui_state, "prod_empty_label")

    if not selected_item then
        return
    end

    local windowSeconds = settings.global["factory-inspector-display-window-seconds"].value
    local agg = results.getAggregateProduction(selected_item, windowSeconds)

    if not hasRows(agg) then
        table.visible = false
        showEmptyLabel(ui_state, "prod_empty_label", ui_state.prod_table_holder, {"ui.no-production", tostring(windowSeconds)})
        return
    end

    table.visible = true
    table.add { type = "label", caption = "", style="fi_table_sprite_heading" } -- for the sprite
    table.add { type = "label", caption = {"ui.recipe-name"}, style="fi_table_text_heading" }
    table.add { type = "label", caption = {"ui.surface"}, style="fi_table_surface_heading" }
    table.add { type = "label", caption = {"ui.quality"}, style="fi_table_quality_heading" }
    table.add { type = "label", caption = {"ui.times-produced"}, style="fi_table_number_heading" }
    table.add { type = "label", caption = {"ui.amount-produced"}, style="fi_table_number_heading" }
    table.add { type = "label", caption = {"ui.per-sec"}, style="fi_table_number_heading" }
    table.add { type = "label", caption = {"ui.per-min"}, style="fi_table_number_heading" }
    table.add { type = "label", caption = {"ui.percent"}, style="fi_table_number_heading" }

    for _, entry in ipairs(agg.entries) do
        if entry.times > 0 then
            local name, sprite = getDisplayNameAndSpriteForDynamicRecipe(entry.recipe)
            local combined_name = {"", name, " (", entry.recipe, ")"}
            local surface_name = getSurfaceDisplayName(entry.surface_index)
            local quality_name = getQualityDisplayName(entry.quality or "normal")
            addSpriteWithQuality(table, sprite, entry.quality)
            table.add { type = "label", caption = combined_name, style="fi_table_text" }
            table.add { type = "label", caption = surface_name, style="fi_table_surface" }
            table.add { type = "label", caption = quality_name, style="fi_table_quality" }
            table.add { type = "label", caption = string.format("%d", entry.times), style="fi_table_number" }
            table.add { type = "label", caption = string.format("%d", entry.amount), style="fi_table_number" }
            table.add { type = "label", caption = string.format("%.1f", entry.per_sec), style="fi_table_number" }
            table.add { type = "label", caption = string.format("%d", entry.per_min), style="fi_table_number" }
            addPercentBar(table, entry.amount / agg.total.amount)
        end
    end

    table.add { type = "sprite", sprite = ""}
    table.add { type = "label", caption = {"ui.total"}, style="fi_table_text_heading" }
    table.add { type = "label", caption = "", style="fi_table_surface_heading" }
    table.add { type = "label", caption = "", style="fi_table_quality_heading" }
    table.add { type = "label", caption = string.format("%d", agg.total.times), style="fi_table_number_heading" }
    table.add { type = "label", caption = string.format("%d", agg.total.amount), style="fi_table_number_heading"}
    table.add { type = "label", caption = string.format("%.1f", agg.total.per_sec), style="fi_table_number_heading" }
    table.add { type = "label", caption = string.format("%d", agg.total.per_min), style="fi_table_number_heading" }
    addPercentBar(table, 1.0)
end
