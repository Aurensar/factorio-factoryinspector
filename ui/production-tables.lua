local results = require "script.results"
local logger = require "script.logger"

productionTables = {}

function productionTables.create(player)
    local ui_state = ui.ui_state(player)

    ui_state.right_column.add{type="label", caption={"ui.production-stats"}, style="caption_label", ignored_by_interaction=true}

    local prod_table_frame = ui_state.right_column.add{type="frame", direction="vertical", style="inside_deep_frame"}
    prod_table_frame.style.vertically_stretchable = true

    ui_state.prod_table_holder = prod_table_frame.add{type="scroll-pane", direction="vertical"}
    ui_state.prod_table_holder.style.horizontally_stretchable = true
    ui_state.prod_table_holder.style.vertically_stretchable = true
    ui_state.prod_table_holder.style.padding = { 10,10 }

    ui_state.prod_table = ui_state.prod_table_holder.add { type = "table", column_count = 10, vertical_centering=false, style="fi_table_production", draw_vertical_lines=true, draw_horizontal_lines=true }
    ui_state.prod_table.style.horizontal_spacing = 16

    ui_state.right_column.add{type="label", caption={"ui.consumption-stats"}, style="caption_label", ignored_by_interaction=true}

    local cons_table_frame = ui_state.right_column.add{type="frame", direction="vertical", style="inside_deep_frame"}
    cons_table_frame.style.vertically_stretchable = true

    ui_state.cons_table_holder = cons_table_frame.add{type="scroll-pane", direction="vertical"}
    ui_state.cons_table_holder.style.horizontally_stretchable = true
    ui_state.cons_table_holder.style.vertically_stretchable = true
    ui_state.cons_table_holder.style.padding = { 10,10 }

    ui_state.cons_table = ui_state.cons_table_holder.add { type = "table", column_count = 10, vertical_centering=false, style="fi_table_production", draw_vertical_lines=true, draw_horizontal_lines=true }
    ui_state.cons_table.style.horizontal_spacing = 16

    productionTables.refreshConsumption(player)
    productionTables.refreshProduction(player)
end

function productionTables.refresh(player)
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

function productionTables.refreshConsumption(player)
    local ui_state = ui.ui_state(player)
    local table = ui_state.cons_table
    local selected_item = ui_state.selected_item
    table.clear()

    if not selected_item then
        return
    end

    table.add { type = "label", caption = "", style="fi_table_sprite_heading" } -- for the sprite
    table.add { type = "label", caption = {"ui.recipe-name"}, style="fi_table_text_heading" }
    table.add { type = "label", caption = {"ui.recipe-name-internal"}, style="fi_table_text_heading" }
    table.add { type = "label", caption = {"ui.surface"}, style="fi_table_surface_heading" }
    table.add { type = "label", caption = {"ui.quality"}, style="fi_table_quality_heading" }
    table.add { type = "label", caption = {"ui.times-consumed"}, style="fi_table_number_heading" }
    table.add { type = "label", caption = {"ui.amount-consumed"}, style="fi_table_number_heading" }
    table.add { type = "label", caption = {"ui.per-sec"}, style="fi_table_number_heading" }
    table.add { type = "label", caption = {"ui.per-min"}, style="fi_table_number_heading" }
    table.add { type = "label", caption = {"ui.percent"}, style="fi_table_number_heading" }

    local agg = results.getAggregateConsumption(selected_item, 120)
    if not agg then return end

    for _, entry in ipairs(agg.entries) do
        if entry.times > 0 then
            local name, sprite = getDisplayNameAndSpriteForDynamicRecipe(entry.recipe)
            local surface_name = getSurfaceDisplayName(entry.surface_index)
            local quality_name = getQualityDisplayName(entry.quality or "normal")
            if entry.quality and entry.quality ~= "normal" then
                sprite = "quality/" .. entry.quality
            end
            table.add { type = "sprite", sprite = sprite }
            table.add { type = "label", caption = name, style="fi_table_text" }
            table.add { type = "label", caption = entry.recipe, style="fi_table_text" }
            table.add { type = "label", caption = surface_name, style="fi_table_surface" }
            table.add { type = "label", caption = quality_name, style="fi_table_quality" }
            table.add { type = "label", caption = string.format("%d", entry.times), style="fi_table_number" }
            table.add { type = "label", caption = string.format("%d", entry.amount), style="fi_table_number" }
            table.add { type = "label", caption = string.format("%.1f", entry.per_sec), style="fi_table_number" }
            table.add { type = "label", caption = string.format("%d", entry.per_min), style="fi_table_number" }
            table.add { type = "label", caption = string.format("%d", (entry.amount / agg.total.amount * 100)), style="fi_table_number" }
        end
    end

    table.add { type = "sprite", sprite = ""}
    table.add { type = "label", caption = {"ui.total"}, style="fi_table_text_heading" }
    table.add { type = "label", caption = {"ui.total"}, style="fi_table_text_heading" }
    table.add { type = "label", caption = "", style="fi_table_surface_heading" }
    table.add { type = "label", caption = "", style="fi_table_quality_heading" }
    table.add { type = "label", caption = string.format("%d", agg.total.times), style="fi_table_number_heading" }
    table.add { type = "label", caption = string.format("%d", agg.total.amount), style="fi_table_number_heading"}
    table.add { type = "label", caption = string.format("%.1f", agg.total.per_sec), style="fi_table_number_heading" }
    table.add { type = "label", caption = string.format("%d", agg.total.per_min), style="fi_table_number_heading" }
    table.add { type = "label", caption = string.format("%d", 100), style="fi_table_number_heading" }
end

function productionTables.refreshProduction(player)
    local ui_state = ui.ui_state(player)
    local table = ui_state.prod_table
    local selected_item = ui_state.selected_item
    table.clear()

    if not selected_item then
        return
    end

    table.add { type = "label", caption = "", style="fi_table_sprite_heading" } -- for the sprite
    table.add { type = "label", caption = {"ui.recipe-name"}, style="fi_table_text_heading" }
    table.add { type = "label", caption = {"ui.recipe-name-internal"}, style="fi_table_text_heading" }
    table.add { type = "label", caption = {"ui.surface"}, style="fi_table_surface_heading" }
    table.add { type = "label", caption = {"ui.quality"}, style="fi_table_quality_heading" }
    table.add { type = "label", caption = {"ui.times-produced"}, style="fi_table_number_heading" }
    table.add { type = "label", caption = {"ui.amount-produced"}, style="fi_table_number_heading" }
    table.add { type = "label", caption = {"ui.per-sec"}, style="fi_table_number_heading" }
    table.add { type = "label", caption = {"ui.per-min"}, style="fi_table_number_heading" }
    table.add { type = "label", caption = {"ui.percent"}, style="fi_table_number_heading" }

    local agg = results.getAggregateProduction(selected_item, 120)
    if not agg then return end

    for _, entry in ipairs(agg.entries) do
        if entry.times > 0 then
            local name, sprite = getDisplayNameAndSpriteForDynamicRecipe(entry.recipe)
            local surface_name = getSurfaceDisplayName(entry.surface_index)
            local quality_name = getQualityDisplayName(entry.quality or "normal")
            if entry.quality and entry.quality ~= "normal" then
                sprite = "quality/" .. entry.quality
            end
            table.add { type = "sprite", sprite = sprite }
            table.add { type = "label", caption = name, style="fi_table_text" }
            table.add { type = "label", caption = entry.recipe, style="fi_table_text" }
            table.add { type = "label", caption = surface_name, style="fi_table_surface" }
            table.add { type = "label", caption = quality_name, style="fi_table_quality" }
            table.add { type = "label", caption = string.format("%d", entry.times), style="fi_table_number" }
            table.add { type = "label", caption = string.format("%d", entry.amount), style="fi_table_number" }
            table.add { type = "label", caption = string.format("%.1f", entry.per_sec), style="fi_table_number" }
            table.add { type = "label", caption = string.format("%d", entry.per_min), style="fi_table_number" }
            table.add { type = "label", caption = string.format("%d", (entry.amount / agg.total.amount * 100)), style="fi_table_number" }
        end
    end

    table.add { type = "sprite", sprite = ""}
    table.add { type = "label", caption = {"ui.total"}, style="fi_table_text_heading" }
    table.add { type = "label", caption = {"ui.total"}, style="fi_table_text_heading" }
    table.add { type = "label", caption = "", style="fi_table_surface_heading" }
    table.add { type = "label", caption = "", style="fi_table_quality_heading" }
    table.add { type = "label", caption = string.format("%d", agg.total.times), style="fi_table_number_heading" }
    table.add { type = "label", caption = string.format("%d", agg.total.amount), style="fi_table_number_heading"}
    table.add { type = "label", caption = string.format("%.1f", agg.total.per_sec), style="fi_table_number_heading" }
    table.add { type = "label", caption = string.format("%d", agg.total.per_min), style="fi_table_number_heading" }
    table.add { type = "label", caption = string.format("%d", 100), style="fi_table_number_heading" }
end
